## Healthcare Dataset Cleaning Project

#### Author: Dike Chinonso

### Business Problem

Healthcare data needs to be checked for errors and inconsistencies before it can be used for reliable analysis or reporting. Issues such as inconsistent formatting, invalid values, and duplicate records can affect data quality and lead to misleading results.

In this project, I used SQL to clean and validate a synthetic healthcare dataset covering patient demographics, hospital admissions, billing, and treatment outcomes. I worked on a separate copy of the original dataset and verified each cleaning step before applying changes, keeping the process traceable and the results consistent with the intended changes.

### Dataset and Tools

#### Dataset

- Name: Healthcare Dataset
- Source: [Kaggle](https://www.kaggle.com/datasets/prasad22/healthcare-dataset)
- Description: Synthetic hospital encounter records including patient names, demographics, medical conditions, admission and discharge dates, billing amounts, and treatment outcomes.

#### Tools

- MySQL 8.0: Data cleaning and validation
- MySQL Workbench: Writing and executing SQL queries

### Methodology

1. Working Copy: Created a separate copy of the dataset (`healthcare_dataset_clean`) to preserve the original data and verify changes against the source.
2. Missing Data: Checked every column for NULL values using a single summary query before proceeding with other cleaning steps.
3. Name Standardization: Checked for inconsistent titles (Dr., Mr., Mrs., MD, PhD, etc.) and capitalization in the `Name` column. Used regex-based cleaning to remove titles without affecting names that share similar prefixes, such as “Drew”. I also created a custom `Propercase()` stored function to standardize capitalization while preserving uppercase Roman numeral suffixes.
4. Categorical Validation: Checked Gender, Blood Type, Medical Condition, Insurance Provider, Admission Type, and Test Results for unexpected categories and inconsistent labels.
5. Date Conversion: Confirmed the original date format before converting `Date of Admission` and `Discharge Date` from text to the DATE data type.
6. Billing Validation: Identified negative billing amounts and flagged them for review rather than changing values whose cause could not be confirmed. Rounded billing amounts to two decimal places.
7. Duplicate Detection: Used window functions to identify exact duplicate rows across all columns. Removed duplicate copies while retaining one record from each group, then compared row counts before and after to verify the result.

### Key SQL Techniques Used

- String functions: `REGEXP_REPLACE`, `SUBSTRING_INDEX`, `TRIM`, `UPPER`, and `LOWER` for name cleaning and standardization.
- Stored functions: Created a custom `Propercase()` function using a `WHILE` loop to apply capitalization word by word.
- Window functions: Used `COUNT() OVER (PARTITION BY ...)` to detect duplicates and `ROW_NUMBER() OVER (PARTITION BY ...)` to identify which copy to retain.
- CASE statements: Flagged billing values that failed validation checks.
- Date functions: Used `STR_TO_DATE` to convert text-based dates, followed by `ALTER TABLE ... MODIFY` to enforce the correct column type.

### Scope of Analysis

This project focuses on data cleaning and validation rather than exploratory analysis or statistical findings. The aim was to produce a cleaned dataset that could be used for further analysis.

Throughout the process, I followed an identify, verify, apply, and validate approach. I checked the expected effect of each cleaning step before applying it and confirmed the outcome afterward, including verifying that duplicate removal produced the expected change in row count.

### Data Quality Summary

- Names: Standardized inconsistent titles and capitalization after checking the cleaned values against the original names.
- Billing Amounts: Identified negative billing values and flagged them for review rather than assuming they were errors.
- Duplicates: Removed exact duplicate rows and verified the number of records removed using before-and-after row counts.
- Categorical Columns: Found no invalid or unexpected categories in Gender, Blood Type, Medical Condition, Insurance Provider, Admission Type, or Test Results.
- Missing Data: Found no NULL values in any column of the original dataset.

### Limitations

- Billing Flags: Negative billing values were flagged rather than corrected. Without additional information, such as a transaction type or refund indicator, I could not determine whether they were data entry errors or legitimate adjustments.
- Synthetic Data: The dataset was generated for practice purposes and does not represent real clinical records. The cleaning process should not be treated as a direct reflection of data quality issues in actual healthcare settings.
- Duplicate Definition: Duplicates were defined as rows identical across every column. This approach does not identify near-duplicates, such as records for the same patient with a minor difference in one field.
