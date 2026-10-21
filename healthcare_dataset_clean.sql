

-- ------------------------------------------------------------
--  INITIAL LOOK AT THE DATA
-- ------------------------------------------------------------
SELECT *
FROM healthcare_dataset
LIMIT 50;

-- ------------------------------------------------------------
-- 1. CREATE A WORKING COPY
--    (keeps the original table untouched)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS healthcare_dataset_clean;

CREATE TABLE healthcare_dataset_clean
LIKE healthcare_dataset;

INSERT INTO healthcare_dataset_clean
SELECT *
FROM healthcare_dataset;

SELECT COUNT(*) AS number_of_rows
FROM healthcare_dataset_clean;

SELECT *
FROM healthcare_dataset_clean
LIMIT 50;

-- ============================================================
-- 2. DATA QUALITY ASSESSMENT & CLEANING
-- ============================================================

-- ------------------------------------------------------------
-- 2.1 Checking for missing values
-- ------------------------------------------------------------
SELECT
    SUM(`Name` IS NULL) AS missing_name,
    SUM(Age IS NULL) AS missing_age,
    SUM(Gender IS NULL) AS missing_gender,
    SUM(`Blood Type` IS NULL) AS missing_blood_type,
    SUM(`Medical Condition` IS NULL) AS missing_condition,
    SUM(`Date of Admission`  IS NULL) AS missing_doa,
    SUM(Doctor IS NULL) AS missing_doctor,
    SUM(Hospital IS NULL) AS missing_hospital,
    SUM(`Insurance Provider` IS NULL) AS missing_insurance_provider,
    SUM(`Billing Amount` IS NULL) AS missing_billing,
    SUM(`Room Number` IS NULL) AS missing_room_number,
    SUM(`Admission Type` IS NULL) AS missing_admission_type,
    SUM(`Discharge Date` IS NULL) AS missing_dod,
    SUM(Medication IS NULL) AS missing_medication,
    SUM(`Test Results` IS NULL) AS missing_test_results
FROM healthcare_dataset;

-- ------------------------------------------------------------
-- 2.2 Cleaning the Name column
--     Issues found: leading/trailing titles, inconsistent casing
-- ------------------------------------------------------------

-- Identify leading titles
SELECT
    SUBSTRING_INDEX(TRIM(`Name`), ' ', 1) AS potential_leading_title,
    COUNT(*) AS frequency
FROM healthcare_dataset
WHERE LENGTH(SUBSTRING_INDEX(TRIM(`Name`), ' ', 1)) <= 4
   OR SUBSTRING_INDEX(TRIM(`Name`), ' ', 1) LIKE '%.%'
GROUP BY potential_leading_title
ORDER BY frequency DESC;

-- Identify trailing titles
SELECT
    SUBSTRING_INDEX(TRIM(`Name`), ' ', -1) AS potential_trailing_title,
    COUNT(*) AS frequency
FROM healthcare_dataset
WHERE LENGTH(SUBSTRING_INDEX(TRIM(`Name`), ' ', -1)) <= 4
   OR SUBSTRING_INDEX(TRIM(`Name`), ' ', -1) LIKE '%.%'
GROUP BY potential_trailing_title
ORDER BY frequency DESC;

-- Add a column to hold the cleaned name
ALTER TABLE healthcare_dataset_clean
    ADD COLUMN Clean_Name VARCHAR(255) AFTER `Name`;

-- Preview the title-stripping logic before applying it
SELECT
    REGEXP_REPLACE(
        REGEXP_REPLACE(
            TRIM(`Name`),
            '^(mrs|miss|dr|mr|ms)(\\.\\s*|\\s+)', '', 1, 1, 'i'
        ),
        '\\s+(m\\.?d|dds|dvm|phd)\\.?$', '', 1, 1, 'i'
    ) AS clean_name_preview
FROM healthcare_dataset_clean
LIMIT 30;

-- Apply it
UPDATE healthcare_dataset_clean
SET Clean_Name = REGEXP_REPLACE(
    REGEXP_REPLACE(
        TRIM(`Name`),
        '^(mrs|miss|dr|mr|ms)(\\.\\s*|\\s+)', '', 1, 1, 'i'
    ),
    '\\s+(m\\.?d|dds|dvm|phd)\\.?$', '', 1, 1, 'i'
);

-- Spot-check rows that changed
SELECT `Name`, Clean_Name
FROM healthcare_dataset_clean
WHERE `Name` <> Clean_Name
LIMIT 50;

-- Standardize capitalization with a helper function
DROP FUNCTION IF EXISTS Propercase;

DELIMITER $$

CREATE FUNCTION Propercase(p_input VARCHAR(255))
RETURNS VARCHAR(255)
DETERMINISTIC
BEGIN
    DECLARE word_num   INT DEFAULT 1;
    DECLARE word_count INT;
    DECLARE word  VARCHAR(255);
    DECLARE result VARCHAR(255) DEFAULT '';

    SET p_input = TRIM(p_input);
    SET word_count = LENGTH(p_input) - LENGTH(REPLACE(p_input, ' ', '')) + 1;

    WHILE word_num <= word_count DO
        SET word = SUBSTRING_INDEX(SUBSTRING_INDEX(p_input, ' ', word_num), ' ', -1);

        SET result = CONCAT(
            result,
            CASE
                WHEN UPPER(word) IN ('II','III','IV','V','VI','VII','VIII','IX','X')
                    THEN UPPER(word)
                ELSE CONCAT(UPPER(LEFT(word, 1)), LOWER(SUBSTRING(word, 2)))
            END,
            ' '
        );

        SET word_num = word_num + 1;
    END WHILE;

    RETURN TRIM(result);
END $$

DELIMITER ;

-- Preview before applying
SELECT Clean_Name, Propercase(Clean_Name) AS proper_name
FROM healthcare_dataset_clean
LIMIT 30;

-- Apply
UPDATE healthcare_dataset_clean
SET Clean_Name = Propercase(Clean_Name);

-- Quick check: no blanks introduced
SELECT COUNT(*) AS blank_names
FROM healthcare_dataset_clean
WHERE Clean_Name IS NULL OR TRIM(Clean_Name) = '';

-- Now update name coloumn with cleaned names
UPDATE healthcare_dataset_clean
SET `Name` = Clean_Name;

-- Then drop the now-redundant column
ALTER TABLE healthcare_dataset_clean
DROP COLUMN Clean_Name;
-- ------------------------------------------------------------
-- 2.3 Age column — check for extreme / erroneous values
-- ------------------------------------------------------------
SELECT
    MIN(Age) AS min_age,
    MAX(Age) AS max_age
FROM healthcare_dataset_clean;

-- ------------------------------------------------------------
-- 2.4 Gender — category check
-- ------------------------------------------------------------
SELECT
    Gender,
    COUNT(*) AS frequency
FROM healthcare_dataset_clean
GROUP BY Gender;

-- ------------------------------------------------------------
-- 2.5 Blood Type — category check
-- ------------------------------------------------------------
SELECT
    `Blood Type`,
    COUNT(*) AS frequency
FROM healthcare_dataset_clean
GROUP BY `Blood Type`;

-- ------------------------------------------------------------
-- 2.6 Medical Condition — category check
-- ------------------------------------------------------------
SELECT
    `Medical Condition`,
    COUNT(*) AS frequency
FROM healthcare_dataset_clean
GROUP BY `Medical Condition`;

-- ------------------------------------------------------------
-- 2.7 Date columns — stored as text, convert to DATE
-- ------------------------------------------------------------
SELECT
    STR_TO_DATE(`Date of Admission`, '%Y-%m-%d') AS admission_date_preview,
    STR_TO_DATE(`Discharge Date`,   '%Y-%m-%d') AS discharge_date_preview
FROM healthcare_dataset_clean
LIMIT 30;

UPDATE healthcare_dataset_clean
SET
    `Date of Admission` = STR_TO_DATE(`Date of Admission`, '%Y-%m-%d'),
    `Discharge Date`    = STR_TO_DATE(`Discharge Date`,   '%Y-%m-%d');

ALTER TABLE healthcare_dataset_clean
    MODIFY `Date of Admission` DATE,
    MODIFY `Discharge Date`    DATE;

-- ------------------------------------------------------------
-- 2.8 Insurance Provider — category check
-- ------------------------------------------------------------
SELECT
    `Insurance Provider`,
    COUNT(*) AS frequency
FROM healthcare_dataset_clean
GROUP BY `Insurance Provider`;

-- ------------------------------------------------------------
-- 2.9 Billing Amount — range check, flagging, rounding
-- ------------------------------------------------------------
SELECT
    MIN(`Billing Amount`) AS min_billing,
    MAX(`Billing Amount`) AS max_billing
FROM healthcare_dataset_clean;

-- Negative values found — inspect them
SELECT COUNT(*)
FROM healthcare_dataset_clean
WHERE `Billing Amount` < 0;

-- Preview the flag logic
SELECT
    `Billing Amount`,
    CASE
        WHEN `Billing Amount` < 0 THEN 'Flag'
        ELSE 'OK'
    END AS data_flag_preview
FROM healthcare_dataset_clean
LIMIT 30;

-- Add and populate the flag column
ALTER TABLE healthcare_dataset_clean
    ADD COLUMN `Data Flag` VARCHAR(10) AFTER `Billing Amount`;

UPDATE healthcare_dataset_clean
SET `Data Flag` = CASE
    WHEN `Billing Amount` < 0 THEN 'Flag'
    ELSE 'OK'
END;

-- Round billing amounts to standard currency precision (2 dp)
SELECT
    `Billing Amount`,
    ROUND(`Billing Amount`, 2) AS rounded_preview
FROM healthcare_dataset_clean
LIMIT 30;

UPDATE healthcare_dataset_clean
SET `Billing Amount` = ROUND(`Billing Amount`, 2);

-- ------------------------------------------------------------
-- 2.10 Admission Type — category check
-- ------------------------------------------------------------
SELECT
    `Admission Type`,
    COUNT(*) AS frequency
FROM healthcare_dataset_clean
GROUP BY `Admission Type`;

-- ------------------------------------------------------------
-- 2.11 Test Results — category check
-- ------------------------------------------------------------
SELECT
    `Test Results`,
    COUNT(*) AS frequency
FROM healthcare_dataset_clean
GROUP BY `Test Results`;

-- ------------------------------------------------------------
-- 2.12 Check for Duplicates
-- ------------------------------------------------------------
SELECT *
FROM (
    SELECT *,
           COUNT(*) OVER (
               PARTITION BY `Name`, Age, Gender, `Blood Type`,
                            `Medical Condition`, `Date of Admission`,
                            Doctor, Hospital, `Insurance Provider`,
                            `Billing Amount`, `Data Flag`, `Room Number`,
                            `Admission Type`, `Discharge Date`, Medication,
                            `Test Results`
           ) AS occurrences
    FROM healthcare_dataset_clean
) AS sub
WHERE occurrences > 1;

-- Removing duplicates
CREATE TABLE healthcare_dataset_dedup AS
SELECT Name, Age, Gender, `Blood Type`, `Medical Condition`,
       `Date of Admission`, Doctor, Hospital, `Insurance Provider`,
       `Billing Amount`, `Data Flag`, `Room Number`, `Admission Type`,
       `Discharge Date`, Medication, `Test Results`
FROM (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY `Name`, Age, Gender, `Blood Type`,
                            `Medical Condition`, `Date of Admission`,
                            Doctor, Hospital, `Insurance Provider`,
                            `Billing Amount`, `Data Flag`, `Room Number`,
                            `Admission Type`, `Discharge Date`, Medication,
                            `Test Results`
							ORDER BY `Date of Admission`
           ) AS Row_Num
    FROM healthcare_dataset_clean
) AS dup WHERE Row_Num = 1;

-- Verify the counts make sense
SELECT 
    (SELECT COUNT(*) FROM healthcare_dataset_clean) AS before_count,
    (SELECT COUNT(*) FROM healthcare_dataset_dedup) AS after_count;
    
    -- Swap the deduplicated table into place
DROP TABLE healthcare_dataset_clean;
ALTER TABLE healthcare_dataset_dedup RENAME TO healthcare_dataset_clean;

SELECT *
FROM healthcare_dataset_clean
LIMIT 50;
	
