use redflag;
SELECT COUNT(*)
FROM transactions;
SELECT *
FROM transactions
LIMIT 10;
SELECT MIN(amount),
       MAX(amount),
       AVG(amount)
FROM transactions;
SELECT status,
       COUNT(*)
FROM transactions
GROUP BY status;
SELECT MIN(txn_time),
       MAX(txn_time)
FROM transactions;
SELECT
    user_id,
    DATE(txn_time) AS attack_date,
    COUNT(*) AS daily_transaction_count
FROM transactions
GROUP BY user_id, DATE(txn_time)
HAVING COUNT(*) >= 30
ORDER BY daily_transaction_count DESC;


SELECT
    user_id,
    COUNT(*) AS round_amount_transactions
FROM transactions
WHERE amount IN (100,200,500,1000,2000,5000,10000)
GROUP BY user_id
HAVING COUNT(*) >= 15
ORDER BY round_amount_transactions DESC;



SELECT
    user_id,
    DATE(txn_time) AS transaction_date,
    COUNT(*) AS small_transactions
FROM transactions
WHERE amount < 10
GROUP BY user_id, DATE(txn_time)
HAVING COUNT(*) >= 30
ORDER BY small_transactions DESC;



SELECT user_id,COUNT(*) AS failed_transactions
FROM transactions
WHERE status = 'FAILED'
GROUP BY user_id
HAVING COUNT(*) >= 20
ORDER BY failed_transactions DESC;


SELECT user_id,COUNT(*) AS total_transactions,
    SUM(CASE WHEN HOUR(txn_time) BETWEEN 2 AND 4 THEN 1
            ELSE 0
        END
    ) AS odd_hour_transactions
FROM transactions
GROUP BY user_id
HAVING COUNT(*) >= 30
AND SUM(CASE
            WHEN HOUR(txn_time) BETWEEN 2 AND 4 THEN 1
            ELSE 0
        END
    ) / COUNT(*) >= 0.80
ORDER BY odd_hour_transactions DESC;



SELECT
    user_id,
    COUNT(*) AS transactions_9999
FROM transactions
WHERE amount = 9999.00
GROUP BY user_id
HAVING COUNT(*) >= 10
ORDER BY transactions_9999 DESC;


WITH user_volume AS (
    SELECT
        merchant_id,
        user_id,
        SUM(amount) AS total_amount
    FROM transactions
    GROUP BY merchant_id, user_id
),
ranked_users AS (
    SELECT
        merchant_id,
        user_id,
        total_amount,
        ROW_NUMBER() OVER (
            PARTITION BY merchant_id
            ORDER BY total_amount DESC
        ) AS rn
    FROM user_volume
),
top5 AS (
    SELECT
        merchant_id,
        SUM(total_amount) AS top5_amount
    FROM ranked_users
    WHERE rn <= 5
    GROUP BY merchant_id
),
merchant_total AS (
    SELECT
        merchant_id,
        SUM(amount) AS merchant_amount
    FROM transactions
    GROUP BY merchant_id
)
SELECT
    m.merchant_id,
    top5.top5_amount,
    m.merchant_amount,
    ROUND((top5.top5_amount / m.merchant_amount) * 100, 2) AS percentage
FROM merchant_total m
JOIN top5
ON m.merchant_id = top5.merchant_id
WHERE (top5.top5_amount / m.merchant_amount) > 0.60
ORDER BY percentage DESC;


WITH activity AS (
    SELECT
        user_id,
        txn_time,
        LAG(txn_time) OVER (
            PARTITION BY user_id
            ORDER BY txn_time
        ) AS previous_txn
    FROM transactions
)
SELECT
    user_id,
    COUNT(*) AS transactions_after_gap
FROM activity
WHERE previous_txn IS NOT NULL
  AND DATEDIFF(txn_time, previous_txn) >= 90
GROUP BY user_id
HAVING COUNT(*) >= 15
ORDER BY transactions_after_gap DESC;
WITH monthly_txns AS (
    SELECT
        user_id,
        DATE_FORMAT(txn_time,'%Y-%m') AS month,
        COUNT(*) AS monthly_count
    FROM transactions
    GROUP BY user_id, DATE_FORMAT(txn_time,'%Y-%m')
),
user_stats AS (
    SELECT
        user_id,
        AVG(monthly_count) AS avg_monthly,
        MAX(monthly_count) AS peak_monthly
    FROM monthly_txns
    GROUP BY user_id
)
SELECT
    user_id,
    ROUND(avg_monthly,2) AS average_transactions,
    peak_monthly
FROM user_stats
WHERE peak_monthly >=20
AND peak_monthly>=5*avg_monthly
ORDER BY peak_monthly DESC;


WITH travel AS (
SELECT
user_id,
city,
txn_time,
LAG(city) OVER(
PARTITION BY user_id
ORDER BY txn_time
) AS previous_city,
LAG(txn_time) OVER(
PARTITION BY user_id
ORDER BY txn_time
) AS previous_time
FROM transactions
)

SELECT
user_id,
previous_city,
city,
previous_time,
txn_time
FROM travel
WHERE previous_city IS NOT NULL
AND previous_city<>city
AND TIMESTAMPDIFF(MINUTE,previous_time,txn_time)<=60
ORDER BY user_id;
