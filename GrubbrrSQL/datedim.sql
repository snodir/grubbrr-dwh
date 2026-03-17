DO $$
DECLARE
  d1 date := '20230101';
  d2 date := '20261231';
  h integer;
  wk integer := 0;
  d INTEGER;
  y TEXT := '2023';
  y2 TEXT;
BEGIN
    TRUNCATE TABLE dim.datedim;
    d := extract('dow' FROM d1);
    
    WHILE d1 <= d2 LOOP
    
        IF d = 0 THEN 
            wk := wk+1;
        END IF;
    
        IF wk > 52 THEN
            wk := 1;
        END IF;

        FOR h IN 0..23 LOOP         
            INSERT INTO dim.datedim 
            VALUES (
                (TO_CHAR(d1,'YYYYMMDD')||LPAD(h::TEXT,2,'0'))::integer,
                (TO_CHAR(d1,'YYYYMMDD')||' '||LPAD(h::text,2,'0')||':00:00')::timestamp,
                LPAD(h::text,2,'0')||':00:00',
                CAST(TO_CHAR(d1,'YYYYMMDD') AS DATE),
                extract('dow' FROM d1),
                TO_CHAR(d1,'Day'), 
                wk, 
                extract('month' FROM d1), 
                TO_CHAR(d1,'Month'), 
                extract('quarter' FROM d1),
                extract('year' FROM d1),
                CASE WHEN h BETWEEN 3 AND 11 THEN 'Breakfast'
                     WHEN h BETWEEN 12 and 16 THEN 'Lunch'
                     ELSE 'Dinner' END,
                date_part('doy', d1)
            );  
        END LOOP;

        d1 := d1 + INTERVAL '1 day';

        d := extract('dow' FROM d1);
        y2 := TO_CHAR(d1,'YYYY');

        -- RAISE NOTICE '% % % %', y, y2, d, wk;       
    END LOOP;    
END; $$;

select * 
from dim.datedim order by dateid desc limit 10;



/*
CREATE TABLE dim.holidays(
    holiday_name CHARACTER VARYING(50) COLLATE pg_catalog."default",
    celebrated_date TIMESTAMP,
    month INTEGER,
    day INTEGER,
    holiday_type CHARACTER VARYING(20) COLLATE pg_catalog."default",
    religion CHARACTER VARYING(20) COLLATE pg_catalog."default",
    is_public BOOLEAN,
    is_dynamic BOOLEAN

)
TABLESPACE pg_default;

ALTER TABLE dim.holidays
OWNER to citus;


INSERT INTO dim.holidays --(name, date, month, day, type, religion, is_public, is_dynamic) 
VALUES
  -- Federal Holidays
  ('New Year''s Day', '2025-01-01', 1, 1, 'Federal', 'None', TRUE, FALSE),
  ('Martin Luther King Jr. Day', '2025-01-20', 1, 20, 'Federal', 'None', TRUE, TRUE),
  ('Presidents'' Day', '2025-02-17', 2, 17, 'Federal', 'None', TRUE, TRUE),
  ('Memorial Day', '2025-05-26', 5, 26, 'Federal', 'None', TRUE, TRUE),
  ('Independence Day', '2025-07-04', 7, 4, 'Federal', 'None', TRUE, FALSE),
  ('Labor Day', '2025-09-01', 9, 1, 'Federal', 'None', TRUE, TRUE),
  ('Columbus Day', '2025-10-13', 10, 13, 'Federal', 'None', TRUE, TRUE),
  ('Veterans Day', '2025-11-11', 11, 11, 'Federal', 'None', TRUE, FALSE),
  ('Thanksgiving Day', '2025-11-27', 11, 27, 'Federal', 'None', TRUE, TRUE),
  ('Christmas Day', '2025-12-25', 12, 25, 'Federal', 'Christianity', TRUE, FALSE),

  -- Christian Holidays
  ('Epiphany', '2025-01-06', 1, 6, 'Religious', 'Christianity', FALSE, FALSE),
  ('Ash Wednesday', '2025-03-05', 3, 5, 'Religious', 'Christianity', FALSE, TRUE),
  ('Palm Sunday', '2025-04-13', 4, 13, 'Religious', 'Christianity', FALSE, TRUE),
  ('Good Friday', '2025-04-18', 4, 18, 'Religious', 'Christianity', FALSE, TRUE),
  ('Easter Sunday', '2025-04-20', 4, 20, 'Religious', 'Christianity', FALSE, TRUE),
  ('Ascension Day', '2025-05-29', 5, 29, 'Religious', 'Christianity', FALSE, TRUE),
  ('Pentecost', '2025-06-08', 6, 8, 'Religious', 'Christianity', FALSE, TRUE),
  ('All Saints'' Day', '2025-11-01', 11, 1, 'Religious', 'Christianity', FALSE, FALSE),
  ('Advent Begins', '2025-11-30', 11, 30, 'Religious', 'Christianity', FALSE, TRUE),

  -- Orthodox Christian Holidays
  ('Orthodox Christmas Day', '2025-01-07', 1, 7, 'Religious', 'Christianity', FALSE, FALSE),
  ('Orthodox New Year', '2025-01-14', 1, 14, 'Religious', 'Christianity', FALSE, FALSE),
  ('Orthodox Easter Sunday', '2025-04-20', 4, 20, 'Religious', 'Christianity', FALSE, TRUE),

  -- Jewish Holidays
  ('Tu B''Shevat', '2025-02-13', 2, 13, 'Religious', 'Judaism', FALSE, TRUE),
  ('Purim', '2025-03-14', 3, 14, 'Religious', 'Judaism', FALSE, TRUE),
  ('Passover Begins', '2025-04-12', 4, 12, 'Religious', 'Judaism', FALSE, TRUE),
  ('Yom HaShoah', '2025-04-22', 4, 22, 'Religious', 'Judaism', FALSE, TRUE),
  ('Shavuot', '2025-06-01', 6, 1, 'Religious', 'Judaism', FALSE, TRUE),
  ('Rosh Hashanah', '2025-09-23', 9, 23, 'Religious', 'Judaism', FALSE, TRUE),
  ('Yom Kippur', '2025-10-02', 10, 2, 'Religious', 'Judaism', FALSE, TRUE),
  ('Sukkot Begins', '2025-10-07', 10, 7, 'Religious', 'Judaism', FALSE, TRUE),
  ('Hanukkah Begins', '2025-12-25', 12, 25, 'Religious', 'Judaism', FALSE, TRUE),

  -- Muslim Holidays
  ('Isra and Mi''raj', '2025-01-27', 1, 27, 'Religious', 'Islam', FALSE, TRUE),
  ('Laylat al Bara''at', '2025-02-14', 2, 14, 'Religious', 'Islam', FALSE, TRUE),
  ('Ramadan Begins', '2025-02-28', 2, 28, 'Religious', 'Islam', FALSE, TRUE),
  ('Eid al-Fitr', '2025-03-30', 3, 30, 'Religious', 'Islam', FALSE, TRUE),
  ('Eid al-Adha', '2025-06-07', 6, 7, 'Religious', 'Islam', FALSE, TRUE),
  ('Islamic New Year', '2025-06-27', 6, 27, 'Religious', 'Islam', FALSE, TRUE),
  ('Ashura', '2025-07-06', 7, 6, 'Religious', 'Islam', FALSE, TRUE),
  ('Mawlid al-Nabi', '2025-09-04', 9, 4, 'Religious', 'Islam', FALSE, TRUE),

  -- Hindu Holidays
  ('Makar Sankranti', '2025-01-14', 1, 14, 'Religious', 'Hinduism', FALSE, FALSE),
  ('Maha Shivaratri', '2025-02-26', 2, 26, 'Religious', 'Hinduism', FALSE, TRUE),
  ('Holi', '2025-03-14', 3, 14, 'Religious', 'Hinduism', FALSE, TRUE),
  ('Raksha Bandhan', '2025-08-09', 8, 9, 'Religious', 'Hinduism', FALSE, TRUE),
  ('Krishna Janmashtami', '2025-08-16', 8, 16, 'Religious', 'Hinduism', FALSE, TRUE),
  ('Navaratri Begins', '2025-09-22', 9, 22, 'Religious', 'Hinduism', FALSE, TRUE),
  ('Diwali', '2025-10-21', 10, 21, 'Religious', 'Hinduism', FALSE, TRUE),

  -- Buddhist Holidays
  ('Magha Puja', '2025-02-11', 2, 11, 'Religious', 'Buddhism', FALSE, TRUE),
  ('Vesak (Buddha Day)', '2025-05-12', 5, 12, 'Religious', 'Buddhism', FALSE, TRUE),

  -- Secular and Cultural Observances
  ('Groundhog Day', '2025-02-02', 2, 2, 'Cultural', 'Secular', FALSE, FALSE),
  ('Valentine''s Day', '2025-02-14', 2, 14, 'Cultural', 'Secular', FALSE, FALSE),
  ('St. Patrick''s Day', '2025-03-17', 3, 17, 'Cultural', 'Secular', FALSE, FALSE),
  ('April Fool''s Day', '2025-04-01', 4, 1, 'Cultural', 'Secular', FALSE, FALSE),
  ('Earth Day', '2025-04-22', 4, 22, 'Cultural', 'Secular', FALSE, FALSE),
  ('Cinco de Mayo', '2025-05-05', 5, 5, 'Cultural', 'Secular', FALSE, FALSE),
  ('Juneteenth', '2025-06-19', 6, 19, 'Cultural', 'Secular', TRUE, FALSE),
  ('Halloween', '2025-10-31', 10, 31, 'Cultural', 'Secular', FALSE, FALSE),
  ('Black Friday', '2025-11-28', 11, 28, 'Cultural', 'Secular', FALSE, TRUE),
  ('New Year''s Eve', '2025-12-31', 12, 31, 'Cultural', 'Secular', FALSE, FALSE);*/