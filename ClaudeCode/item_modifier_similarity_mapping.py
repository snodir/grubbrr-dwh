"""
Side job: item-modifier matching.

Filters modifiers from the modifier-mapping parquet to those that likely
represent standalone menu items, then fuzzy-matches them against the org's
unique menu item names (from menu_df).

Returns:
    modifier_id_to_name   : Dict[str, str]        — modifierid -> modifiername
    modifier_name_to_items: Dict[str, List[str]]  — modifiername -> [matched item names]
"""

import logging
import re
from typing import Dict, List, Tuple

import pandas as pd
from rapidfuzz import fuzz, process

from recommendation_models.xgboost.models import DataLoaderResult

logger = logging.getLogger(__name__)

_GROUP_SKIP_KEYWORDS = ["level", "change", "sauce choice"]
_MOD_SKIP_KEYWORDS = ["no "]
_MATCH_THRESHOLD = 70


def _normalize(text: str) -> str:
    text = str(text).lower()
    text = re.sub(r'[^\w\s]', ' ', text)
    text = re.sub(r'\b(\d+)pc\b', r'\1 piece', text)
    text = re.sub(r'\boz\b', 'ounce', text)
    text = text.replace('slaw', 'coleslaw')
    text = text.replace("n'", ' and ')
    return re.sub(r'\s+', ' ', text).strip()


def _filter_modifiers(modifier_df: pd.DataFrame) -> List[str]:
    mods = []
    for group, modifiers in modifier_df.groupby('modifiergroupname')['modifiername']:
        if any(kw in str(group).lower() for kw in _GROUP_SKIP_KEYWORDS):
            continue
        for modifier in modifiers.dropna().unique():
            if any(kw in str(modifier).lower() for kw in _MOD_SKIP_KEYWORDS):
                continue
            mods.append(modifier)
    return mods


def _build_modifier_name_to_items(
    filtered_mods: List[str],
    master_items: List[str],
) -> Dict[str, List[str]]:
    normalized_master = [_normalize(item) for item in master_items]
    result: Dict[str, List[str]] = {}
    for mod in filtered_mods:
        match_result = process.extractOne(
            _normalize(mod), normalized_master, scorer=fuzz.token_sort_ratio
        )
        if match_result is None:
            continue
        _match, score, idx = match_result
        if score >= _MATCH_THRESHOLD:
            result.setdefault(mod, []).append(master_items[idx])
    return result


def run_item_modifier_matching(
    organization_id: str,
    data: DataLoaderResult,
) -> Tuple[Dict[str, str], Dict[str, List[str]]]:
    """Build modifier_id_to_name and modifier_name_to_items artifacts.

    Called from the training pipeline after data loading.
    Returns empty dicts if modifier_df is unavailable.
    """
    modifier_df = data.modifier_df
    if modifier_df.empty:
        logger.warning("ItemModifierMatching[%s]: modifier_df is empty, skipping", organization_id)
        return {}, {}

    modifier_id_to_name: Dict[str, str] = (
        modifier_df[["modifierid", "modifiername"]]
        .drop_duplicates()
        .set_index("modifierid")["modifiername"]
        .to_dict()
    )
    logger.warning(
        "ItemModifierMatching[%s]: modifier_id_to_name — %d entries",
        organization_id, len(modifier_id_to_name),
    )

    filtered_mods = _filter_modifiers(modifier_df)
    logger.warning(
        "ItemModifierMatching[%s]: %d modifiers after group/keyword filtering",
        organization_id, len(filtered_mods),
    )

    menu_df = data.menu_df
    master_items: List[str] = (
        menu_df["menuitemname"].dropna().unique().tolist()
        if not menu_df.empty and "menuitemname" in menu_df.columns
        else []
    )
    logger.warning(
        "ItemModifierMatching[%s]: %d master items from menu_df",
        organization_id, len(master_items),
    )

    modifier_name_to_items = _build_modifier_name_to_items(filtered_mods, master_items)
    logger.warning(
        "ItemModifierMatching[%s]: %d modifiers matched to menu items (threshold=%d%%)",
        organization_id, len(modifier_name_to_items), _MATCH_THRESHOLD,
    )

    return modifier_id_to_name, modifier_name_to_items