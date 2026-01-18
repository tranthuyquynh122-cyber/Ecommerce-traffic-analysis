-- Query 01: calculate total visit, pageview, transaction for Jan, Feb and March 2017 (order by month)
SELECT
  FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d', date)) AS month,
  COUNT(DISTINCT fullVisitorId) AS visits,
  SUM(totals.pageviews) AS pageviews,
  SUM(totals.transactions) AS transactions
FROM`bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
WHERE _TABLE_SUFFIX BETWEEN '0101' AND '0331' 
GROUP BY month
ORDER BY month;


-- Query 02: Bounce rate per traffic source in July 2017 (Bounce_rate = num_bounce/total_visit) (order by total_visit DESC)
WITH source_s AS (
  SELECT
    trafficSource.source AS source,
    COUNT(fullVisitorId) AS total_visits,
    SUM(CASE WHEN totals.bounces = 1 THEN 1 ELSE 0 END) AS total_no_of_bounces
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`
  GROUP BY source
)

SELECT
  source,
  total_visits,
  total_no_of_bounces,
  ROUND(SAFE_DIVIDE(total_no_of_bounces, total_visits) * 100, 2) AS bounce_rate
FROM source_s
ORDER BY total_visits DESC;

-- Query 3: Revenue by traffic source by week, by month in June 2017
WITH monthly_revenue AS (
  SELECT
    'Month' AS time_type,
    FORMAT_DATE('%Y-%m', PARSE_DATE('%Y%m%d', date)) AS time,
    trafficSource.source AS source,
    SAFE_DIVIDE(SUM(product.productRevenue), 1000000) AS revenue
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*`,
    UNNEST(hits) AS hits,
    UNNEST(hits.product) AS product
  WHERE product.productRevenue IS NOT NULL
  GROUP BY source, time
),

weekly_revenue AS (
  SELECT
    'Week' AS time_type,
    FORMAT_DATE('%Y-%W', PARSE_DATE('%Y%m%d', date)) AS time,
    trafficSource.source AS source,
    SAFE_DIVIDE(SUM(product.productRevenue), 1000000) AS revenue
  FROM`bigquery-public-data.google_analytics_sample.ga_sessions_201706*`,
    UNNEST(hits) AS hits,
    UNNEST(hits.product) AS product
  WHERE product.productRevenue IS NOT NULL
  GROUP BY source, time
)
SELECT * FROM monthly_revenue
UNION ALL
SELECT * FROM weekly_revenue
ORDER BY revenue DESC;

-- QUERY 4: Average number of pageviews by purchaser type (purchasers vs non-purchasers) in June, July 2017.
WITH raw_data AS (
  SELECT
    FORMAT_DATE('%Y-%m', PARSE_DATE('%Y%m%d', date)) AS month,
    fullVisitorId,
    totals.pageviews AS pageviews,
    CASE
      WHEN totals.transactions >= 1 AND product.productRevenue IS NOT NULL THEN 'purchaser'
      WHEN totals.transactions IS NULL AND product.productRevenue IS NULL THEN 'non_purchaser'
      ELSE NULL
    END AS purchaser_type
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,
    UNNEST(hits) AS hits,
    UNNEST(hits.product) AS product
  WHERE _TABLE_SUFFIX BETWEEN '0601' AND '0731'
    AND totals.pageviews IS NOT NULL
)
,aggregated AS (
  SELECT
    month,
    purchaser_type,
    COUNT(DISTINCT fullVisitorId) AS unique_users,
    SUM(pageviews) AS total_pageviews,
    SAFE_DIVIDE(SUM(pageviews), COUNT(DISTINCT fullVisitorId)) AS avg_pageviews
  FROM raw_data
  WHERE purchaser_type IS NOT NULL
  GROUP BY month, purchaser_type
)

SELECT month,
  ROUND(MAX(CASE WHEN purchaser_type = 'purchaser' THEN avg_pageviews END), 2) AS avg_pageviews_purchase,
  ROUND(MAX(CASE WHEN purchaser_type = 'non_purchaser' THEN avg_pageviews END), 2) AS avg_pageviews_non_purchase
FROM aggregated
GROUP BY month
ORDER BY month;

-- Query 05: Average number of transactions per user that made a purchase in July 2017
WITH purchasers AS (
  SELECT
    FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d', date)) AS month,
    fullVisitorId,
    totals.transactions
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,
    UNNEST(hits) AS hits,
    UNNEST(hits.product) AS product
  WHERE _TABLE_SUFFIX BETWEEN '0701' AND '0731'
    AND totals.transactions IS NOT NULL
    AND product.productRevenue IS NOT NULL
)

SELECT
  month,
  ROUND(SAFE_DIVIDE(SUM(transactions), COUNT(DISTINCT fullVisitorId)), 2) AS avg_total_transactions_per_user
FROM purchasers
GROUP BY month;

-- Query 06: Average amount of money spent per session. Only include purchaser data in July 2017
WITH sessions AS (
  SELECT
    PARSE_DATE('%Y%m%d', date) AS session_date,
    totals.visits AS visits,
    product.productRevenue AS productRevenue
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
    UNNEST(hits) AS hits,
    UNNEST(hits.product) AS product
  WHERE totals.transactions IS NOT NULL
    AND product.productRevenue IS NOT NULL
)

SELECT
  FORMAT_DATE('%Y%m', session_date) AS month,
  ROUND(SAFE_DIVIDE(SUM(productRevenue) / 1000000, SUM(visits)), 2) AS avg_revenue_by_user_per_visit
FROM sessions
GROUP BY month
ORDER BY month;

-- Query 07: Other products purchased by customers who purchased product "YouTube Men's Vintage Henley" in July 2017. Output should show product name and the quantity was ordered.
WITH buyers AS (
  SELECT fullVisitorId
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
    UNNEST(hits) AS hits,
    UNNEST(hits.product) AS product
  WHERE product.v2ProductName = "YouTube Men's Vintage Henley"
    AND product.productRevenue IS NOT NULL
    AND totals.transactions >= 1
)

SELECT
  product.v2ProductName AS product_name,
  SUM(product.productQuantity) AS total_quantity_ordered
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
  UNNEST(hits) AS hits,
  UNNEST(hits.product) AS product
WHERE fullVisitorId IN 
  (SELECT fullVisitorId 
  FROM buyers)
  AND product.productRevenue IS NOT NULL
  AND totals.transactions >= 1
  AND product.v2ProductName <> "YouTube Men's Vintage Henley"
GROUP BY product_name
ORDER BY total_quantity_ordered DESC;

-- Query 08: Calculate cohort map from product view to addtocart to purchase in Jan, Feb and March 2017. For example, 100% product view then 40% add_to_cart and 10% purchase.
-- Add_to_cart_rate = number product  add to cart/number product view. Purchase_rate = number product purchase/number product view. The output should be calculated in product level.
WITH raw_data AS (
  SELECT
    PARSE_DATE('%Y%m%d', date) AS full_date,
    FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d', date)) AS month,
    CAST(hits.eCommerceAction.action_type AS INT) AS action_type,
    product.productRevenue
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,
    UNNEST(hits) AS hits,
    UNNEST(hits.product) AS product
  WHERE _TABLE_SUFFIX BETWEEN '0101' AND '0331' 
    AND CAST(hits.eCommerceAction.action_type AS INT) IN (2, 3, 6)
)

SELECT
  month,
  SUM(CASE WHEN action_type = 2 THEN 1 ELSE 0 END) AS num_product_view,
  SUM(CASE WHEN action_type = 3 THEN 1 ELSE 0 END) AS num_addtocart,
  SUM(CASE WHEN action_type = 6 AND productRevenue IS NOT NULL THEN 1 ELSE 0 END) AS num_purchase,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN action_type = 3 THEN 1 ELSE 0 END) * 100, SUM(CASE WHEN action_type = 2 THEN 1 ELSE 0 END)), 2) AS add_to_cart_rate,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN action_type = 6 AND productRevenue IS NOT NULL THEN 1 ELSE 0 END) * 100, SUM(CASE WHEN action_type = 2 THEN 1 ELSE 0 END)), 2) AS purchase_rate
FROM raw_data
GROUP BY month
ORDER BY month;


