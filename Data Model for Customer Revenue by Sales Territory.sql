-- Drop and Create Database
DROP DATABASE IF EXISTS data_model;
CREATE DATABASE data_model;
USE data_model;

-- Create Date Dimension Table
CREATE TABLE dim_date (
    date_key INT PRIMARY KEY,  -- YYYYMMDD format for easy date lookup
    date_value DATE NOT NULL,
    year INT NOT NULL,
    quarter INT NOT NULL,
    month INT NOT NULL,
    day INT NOT NULL,
    day_of_week INT NOT NULL,
    week_of_year INT NOT NULL,
    is_weekend BOOLEAN NOT NULL
);

-- Create Territory Dimension Table
CREATE TABLE dim_territory (
    territory_key INT PRIMARY KEY AUTO_INCREMENT,
    territory_id INT NOT NULL,  -- Unique identifier for each territory instance
    territory_name VARCHAR(100) NOT NULL,
    region VARCHAR(100),
    create_dt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,  -- Default to current timestamp
    effective_start_key INT NOT NULL,  -- Foreign key to dim_date for start date
    effective_end_key INT DEFAULT NULL,  -- Foreign key to dim_date for end date
    CONSTRAINT unique_territory_period UNIQUE (territory_id, effective_start_key)
);

-- Create Customer Dimension Table
CREATE TABLE dim_customer (
    customer_key INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,  -- Unique identifier for each customer instance
    customer_name VARCHAR(100) NOT NULL,
    territory_key INT NOT NULL,
    create_date_key INT NOT NULL,  -- Default to current timestamp
    effective_start_key INT NOT NULL,  -- Foreign key to dim_date for start date
    effective_end_key INT DEFAULT NULL,  -- Foreign key to dim_date for end date
    CONSTRAINT unique_customer_period UNIQUE (customer_id, effective_start_key),
    CONSTRAINT fk_customer_territory_key FOREIGN KEY (territory_key) REFERENCES dim_territory(territory_key),
    CONSTRAINT fk_customer_create_date_key FOREIGN KEY (create_date_key) REFERENCES dim_date(date_key)
);

-- Create Fact Revenue Table
CREATE TABLE fact_revenue (
    revenue_key INT PRIMARY KEY AUTO_INCREMENT,
    revenue_id INT NOT NULL,
    customer_key INT NOT NULL,  -- Foreign key to dim_customer
    actual_revenue_amount DECIMAL(15, 2) NOT NULL,
    forecasted_revenue_amount DECIMAL(15, 2) NOT NULL,
    revenue_date_key INT NOT NULL,  -- Foreign key to dim_date
    CONSTRAINT fk_fact_customer_key FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    CONSTRAINT fk_fact_revenue_date_key FOREIGN KEY (revenue_date_key) REFERENCES dim_date(date_key)
);

-- Optional indexes for optimized lookups
CREATE INDEX idx_year_month ON dim_date (year, month);
CREATE INDEX idx_effective_start_key ON dim_customer (effective_start_key);
CREATE INDEX idx_territory_start_key ON dim_territory (effective_start_key);
CREATE INDEX idx_revenue_date_key ON fact_revenue (revenue_date_key);

-- Stored Procedure to Populate Date Dimension
DELIMITER //

CREATE PROCEDURE populate_dim_date(IN start_date DATE, IN end_date DATE)
BEGIN
    DECLARE cdate DATE;

    SET cdate = start_date;

    WHILE cdate <= end_date DO
        INSERT INTO dim_date (
            date_key,
            date_value,
            year,
            quarter,
            month,
            day,
            day_of_week,
            week_of_year,
            is_weekend
        ) VALUES (
            DATE_FORMAT(cdate, '%Y%m%d'),
            cdate,
            YEAR(cdate),
            QUARTER(cdate),
            MONTH(cdate),
            DAY(cdate),
            DAYOFWEEK(cdate),
            WEEK(cdate, 3),
            IF(DAYOFWEEK(cdate) IN (1, 7), TRUE, FALSE)
        );

        SET cdate = DATE_ADD(cdate, INTERVAL 1 DAY);
    END WHILE;
END //

DELIMITER ;

-- Call the procedure to populate dates from 2022-01-01 to 2025-01-01
CALL populate_dim_date('2022-01-01', '2025-01-01');

INSERT INTO dim_territory (territory_id, territory_name, region, effective_start_key, effective_end_key) VALUES
(1, 'Northeast', 'East Coast', 20220101, NULL),
(2, 'Mid-Market', 'West Coast', 20220101, NULL);


INSERT INTO dim_customer (customer_id, customer_name, territory_key, create_date_key, effective_start_key, effective_end_key) VALUES
(101, 'ACME',    1, 20240701, 20240701, 20240928),
(102, 'ACME #2', 2, 20220301, 20220301, NULL),
(103, 'ACME #3', 1, 20230401, 20230401, NULL),
(101, 'ACME',    2, 20240701, 20241001, NULL);


INSERT INTO fact_revenue (revenue_id, customer_key, actual_revenue_amount, forecasted_revenue_amount, revenue_date_key) VALUES
(1001, 1, 500.00, 490.00, 20240701),
(1002, 2, 750.50, 1000.00, 20220301),
(1003, 4, 1200.00, 1201.00, 20241001),
(1004, 3, 300.25, 300.50, 20230401);


-- SCRIPT #1

SELECT
    c.customer_name,
    d.year,
    d.quarter,
    t.territory_name,
    SUM(f.actual_revenue_amount) AS total_actual_revenue,
    SUM(f.forecasted_revenue_amount) AS total_forecasted_revenue
FROM fact_revenue f
    JOIN dim_date d ON f.revenue_date_key = d.date_key
    JOIN dim_customer c ON f.customer_key = c.customer_key
    JOIN dim_territory t ON c.territory_key = t.territory_key
GROUP BY c.customer_name, d.year, d.quarter, t.territory_name
ORDER BY c.customer_name, d.year, d.quarter;

-- Script to Calculate Total Actual Revenue by Sales Territory, Quarter, and Year
SELECT
    t.territory_name AS SalesTerritory,
    d.quarter AS Quarter,
    d.year AS Year,
    SUM(f.actual_revenue_amount) AS total_actual_revenue,
    SUM(f.forecasted_revenue_amount) AS total_forecasted_revenue
FROM
    fact_revenue f
    JOIN dim_customer c ON f.customer_key = c.customer_key
    JOIN dim_territory t ON c.territory_key = t.territory_key
    JOIN dim_date d ON f.revenue_date_key = d.date_key
GROUP BY t.territory_name, d.year, d.quarter
ORDER BY d.year, d.quarter, t.territory_name;

-- At the end of Day 2, ACME has two records in the dim_customer table
SELECT
    customer_id,
    customer_name,
    t.territory_name,
    c.create_date_key,
    c.effective_start_key,
    c.effective_end_key
FROM dim_customer c
JOIN dim_territory t ON c.territory_key = t.territory_key
WHERE c.customer_id = 101
ORDER BY c.effective_start_key;


SELECT COUNT(DISTINCT c.customer_id) AS customers_with_high_revenue
FROM fact_revenue f
    JOIN dim_customer c ON f.customer_key = c.customer_key
WHERE f.actual_revenue_amount > 10000;



SELECT territory_name
FROM dim_territory
WHERE effective_end_key IS NOT NULL AND effective_end_key < DATE_FORMAT(CURRENT_DATE, '%Y%m%d');