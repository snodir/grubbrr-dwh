import re

BACKUP = 'C:/Users/user/Work/Grubbrr/grubbrr-dwh/ClaudeCode/gas_db_backup_20260530.sql'
ALTER  = 'C:/Users/user/Work/Grubbrr/grubbrr-dwh/ClaudeCode/alter_table_add_alter_columns.sql'
OUTPUT = 'C:/Users/user/Work/Grubbrr/grubbrr-dwh/ClaudeCode/gas_db_merged_20260530.sql'

with open(BACKUP, 'r', encoding='utf-8') as f:
    backup = f.read()

with open(ALTER, 'r', encoding='utf-8') as f:
    alter = f.read()

print(f"Backup: {len(backup)} chars, {backup.count(chr(10))} lines")
print(f"Alter: {len(alter)} chars, {alter.count(chr(10))} lines")

def extract_alter_blocks(text):
    """
    Parse alter file. Returns:
      dict: {
        'schema.table': [stmt_str, ...],
        '_indexes': [stmt_str, ...],
        '_sequences': [stmt_str, ...],
        '_drop_views': [stmt_str, ...],
      }
    Table names are lower-cased for matching.
    """
    result = {}

    def add(key, stmt):
        result.setdefault(key, []).append(stmt)

    tlines = text.split('\n')
    n = len(tlines)
    i = 0

    while i < n:
        raw = tlines[i]
        line = raw.strip()

        # Skip blank or comment-only
        if not line or line.startswith('--'):
            i += 1
            continue

        # DROP VIEW
        if re.match(r'DROP VIEW', line, re.I):
            add('_drop_views', raw.rstrip())
            i += 1
            continue

        # ALTER TABLE ... (with or without IF EXISTS)
        m = re.match(r'ALTER TABLE(?:\s+IF\s+EXISTS)?\s+([\w.]+)', line, re.I)
        if m:
            tname = m.group(1).lower()
            # Collect lines until semicolon at end of a line
            stmt_lines = [raw]
            i += 1
            while i < n:
                stmt_lines.append(tlines[i])
                stripped = tlines[i].rstrip()
                if stripped.endswith(';'):
                    i += 1
                    break
                i += 1
            add(tname, '\n'.join(stmt_lines))
            continue

        # CREATE INDEX IF NOT EXISTS
        if re.match(r'CREATE INDEX IF NOT EXISTS', line, re.I):
            stmt_lines = [raw]
            i += 1
            while i < n:
                stmt_lines.append(tlines[i])
                if tlines[i].rstrip().endswith(';'):
                    i += 1
                    break
                i += 1
            add('_indexes', '\n'.join(stmt_lines))
            continue

        # CREATE SEQUENCE IF NOT EXISTS
        if re.match(r'CREATE SEQUENCE IF NOT EXISTS', line, re.I):
            stmt_lines = [raw]
            i += 1
            while i < n:
                stmt_lines.append(tlines[i])
                if tlines[i].rstrip().endswith(';'):
                    i += 1
                    break
                i += 1
            add('_sequences', '\n'.join(stmt_lines))
            continue

        # SELECT setval(
        if re.match(r'SELECT setval\(', line, re.I):
            stmt_lines = [raw]
            i += 1
            while i < n:
                stmt_lines.append(tlines[i])
                if tlines[i].rstrip().endswith(');') or tlines[i].rstrip().endswith(';'):
                    i += 1
                    break
                i += 1
            add('_sequences', '\n'.join(stmt_lines))
            continue

        # CREATE TABLE IF NOT EXISTS - skip (already in backup)
        if re.match(r'CREATE TABLE IF NOT EXISTS', line, re.I):
            depth = line.count('(') - line.count(')')
            i += 1
            while i < n:
                l2 = tlines[i]
                depth += l2.count('(') - l2.count(')')
                i += 1
                if depth <= 0 and l2.rstrip().endswith(';'):
                    break
            continue

        # CREATE OR REPLACE FUNCTION / PROCEDURE / VIEW - skip (backup has final version)
        if re.match(r'CREATE OR REPLACE\s+(FUNCTION|PROCEDURE|VIEW)', line, re.I):
            # need to skip until end of dollar-quoted body + ;
            i += 1
            in_dollar = False
            dollar_tag = None
            while i < n:
                l2 = tlines[i]
                i += 1
                if not in_dollar:
                    dm = re.findall(r'\$(\w*)\$', l2)
                    if dm:
                        in_dollar = True
                        dollar_tag = '$' + dm[0] + '$'
                else:
                    if dollar_tag in l2:
                        in_dollar = False
                        # After the closing tag, the next line should be ;
                        # or it might be on same line
                        if l2.rstrip().endswith(';'):
                            break
                        # else keep going until ;
            # Now skip until ;
            while i < n and not tlines[i-1].rstrip().endswith(';'):
                if tlines[i].rstrip().endswith(';'):
                    i += 1
                    break
                i += 1
            continue

        # ALTER PROCEDURE/FUNCTION/VIEW OWNER TO - skip
        if re.match(r'ALTER\s+(PROCEDURE|FUNCTION|VIEW|SCHEMA)\s', line, re.I):
            i += 1
            continue

        # GRANT/REVOKE - skip
        if re.match(r'(GRANT|REVOKE)\s', line, re.I):
            i += 1
            continue

        # Skip single-line comments in blocks
        if line.startswith('/*'):
            while i < n and '*/' not in tlines[i]:
                i += 1
            i += 1
            continue

        # Everything else - skip
        i += 1

    return result


blocks = extract_alter_blocks(alter)

print("\nALTER TABLE targets found in alter file:")
for k in sorted(blocks.keys()):
    if not k.startswith('_'):
        print(f"  {k}: {len(blocks[k])} statement(s)")

print(f"\nIndexes from alter file: {len(blocks.get('_indexes', []))}")
print(f"Sequences from alter file: {len(blocks.get('_sequences', []))}")
print(f"Drop views: {len(blocks.get('_drop_views', []))}")

# ----------------------------------------------------------------
# Now build the merged file
# Strategy:
# 1. The backup is the authoritative base
# 2. We insert alter file's ALTER TABLE statements for each table
#    right after "ALTER TABLE <schema>.<table> OWNER TO citus;" in the backup
# 3. We insert new indexes from alter file into the backup's index section
# 4. Sequences from alter file: insert after the relevant table's section
# 5. DROP VIEW goes at the top (before first CREATE)
# ----------------------------------------------------------------

output_lines = backup.split('\n')

# Find insertion points: after each "ALTER TABLE <schema>.<table> OWNER TO citus;"
# The backup has lines like:
#   ALTER TABLE dim.abtests OWNER TO citus;
# or with 'ONLY' keyword or without

def normalize_table_name(name_str):
    """Normalize a table name to schema.table lowercase"""
    name_str = name_str.strip().lower()
    # Remove 'only' keyword if present
    name_str = re.sub(r'^only\s+', '', name_str)
    return name_str

# Build a map of table_name -> line index in output for the OWNER TO line
# We'll process lines and insert alter blocks after the OWNER line

# Since we're modifying the list, build the result incrementally
result_parts = []

# First: add header comment
result_parts.append('-- ============================================================')
result_parts.append('-- Merged schema: gas_db_backup_20260530 + alter_table_add_alter_columns')
result_parts.append('-- Generated: 2026-05-30')
result_parts.append('-- ============================================================')
result_parts.append('')

# Add DROP VIEW statements from alter file first (before any CREATEs)
drop_views = blocks.get('_drop_views', [])
if drop_views:
    result_parts.append('-- DROP VIEW statements from schema evolution file')
    for dv in drop_views:
        result_parts.append(dv)
    result_parts.append('')

# Now process the backup line by line
# We need to detect OWNER TO citus; lines and inject alter statements after them

backup_lines = backup.split('\n')

# Track which tables we've already injected for (avoid double injection)
injected = set()

# Sequences from alter file that we need to inject
# These reference dim.frequentcustomer, dim.menuitem, dim.itemcategory
# The backup already has these sequences (frequentcustomer_customerkey_seq, menuitem_id_seq, itemcategory_id_seq)
# The setval calls are important for syncing sequences - we'll add them to the sequences section
alter_sequences = blocks.get('_sequences', [])
alter_indexes = blocks.get('_indexes', [])

# Track if we've added sequences/indexes yet
sequences_injected = False
# We'll inject sequences right before the index section in backup

i = 0
n = len(backup_lines)

while i < n:
    line = backup_lines[i]
    result_parts.append(line)

    # Check if this is an OWNER TO citus line (table ownership)
    # Pattern: ALTER TABLE [ONLY] schema.table OWNER TO citus;
    m = re.match(r'ALTER TABLE(?:\s+ONLY)?\s+([\w.]+)\s+OWNER TO', line.strip(), re.I)
    if m:
        tname = normalize_table_name(m.group(1))
        if tname not in injected:
            injected.add(tname)
            # Check if we have alter blocks for this table
            alter_stmts = blocks.get(tname, [])
            if alter_stmts:
                result_parts.append('')
                result_parts.append(f'-- Schema evolution: {tname}')
                for stmt in alter_stmts:
                    result_parts.append(stmt)

            # Also check for sequences tied to this table
            # (The backup already has the sequences defined; the alter file has setval calls)
            # We keep this for later

    # Check if we're at the index section and inject sequences before first index
    # The index section in the backup has lines like "-- Name: IX_...; Type: INDEX;"
    # We detect the first CREATE INDEX line and insert sequences before it
    if not sequences_injected and line.startswith('CREATE INDEX'):
        # Insert alter file sequences right before this CREATE INDEX
        if alter_sequences:
            seq_block = ['', '-- Sequence sync from schema evolution file']
            for seq in alter_sequences:
                seq_block.append(seq)
            seq_block.append('')
            # Pop the current line from result_parts, inject sequences, re-add line
            result_parts.pop()  # remove line we just appended
            result_parts.extend(seq_block)
            result_parts.append(line)  # re-add the CREATE INDEX line
        sequences_injected = True
        i += 1
        continue

    i += 1

# Inject new indexes from alter file after the last existing index
# Find the end of the index block (before FK constraints)
if alter_indexes:
    # Find position after last CREATE INDEX in result_parts
    last_idx_pos = -1
    for j, part in enumerate(result_parts):
        if part.strip().startswith('CREATE INDEX') or part.strip().startswith('CREATE UNIQUE INDEX'):
            last_idx_pos = j

    if last_idx_pos >= 0:
        new_idx_block = ['', '-- New indexes from schema evolution file']
        for idx in alter_indexes:
            new_idx_block.append(idx)
        new_idx_block.append('')
        # Insert after last_idx_pos
        result_parts = result_parts[:last_idx_pos+1] + new_idx_block + result_parts[last_idx_pos+1:]

# Write output
merged = '\n'.join(result_parts)
with open(OUTPUT, 'w', encoding='utf-8') as f:
    f.write(merged)

print(f"\nMerged file written: {OUTPUT}")
print(f"Output: {len(merged)} chars, {merged.count(chr(10))} lines")
print(f"Tables injected: {len(injected)}")
