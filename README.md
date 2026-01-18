# 📊 E-commerce Traffic & Behavior Analysis using Google Analytics Data | SQL (BigQuery)

**Business Question:**  
How do user traffic, engagement, and purchasing behavior evolve over time, and how can businesses optimize marketing and conversion performance?

**Domain:** E-commerce / Digital Marketing Analytics  
**Tools Used:** SQL (Google BigQuery)  

Author: Tran Thuy Quynh  
Date: 2025-07

---

## 📑 Table of Contents

1. 📌 [Background & Overview](#background-overview)
2. 📂 [Dataset Description & Data Structure](#dataset-description--data-structure)
3. 📊 [Final Conclusion & Recommendations](#final-conclusion--recommendations)

---

<a id="background-overview"></a>
## 📌 Background & Overview

### 📖 Project Objective  

This project analyzes **e-commerce website traffic and user behavior** using the Google Analytics Sample Dataset available on BigQuery. The goal is to understand how users interact with the website across different time periods, traffic sources, and purchase stages, and to extract actionable insights that help improve **conversion performance and revenue generation**.

Specifically, this project aims to:

✔️ Measure traffic volume and engagement trends over time  
✔️ Analyze bounce rate across different traffic sources  
✔️ Understand revenue contribution by channel and by time  
✔️ Compare behavior between purchasers and non-purchasers  
✔️ Evaluate the conversion funnel from product view → add to cart → purchase  
✔️ Identify cross-sell opportunities from product co-purchase behavior  

---

### 👤 Who is this project for?

This project is designed for:

✔️ Marketing Analysts  
✔️ Growth & Performance teams  
✔️ E-commerce stakeholders  
✔️ Hiring managers reviewing analytics portfolios  

---

<a id="dataset-description--data-structure"></a>
## 📂 Dataset Description & Data Structure

### 📌 Data Source  

- **Source:** Google Analytics Sample Dataset (BigQuery Public Dataset)  
- **Dataset name:** `bigquery-public-data.google_analytics_sample`  
- **Format:** BigQuery tables  
- **Time period analyzed:** January – July 2017  

---

## 📊 Data Structure & Relationships  

### 1️⃣ Tables Used  

This project uses **one primary table** from the dataset:

- `ga_sessions_2017*`

This table contains session-level Google Analytics data with nested structures that capture user behavior, traffic source information, and ecommerce interactions.

---

### 2️⃣ Table Schema & Data Snapshot  

### 📊 Key Fields Used (Schema Overview)

| Field Name | Data Type | Description |
|-----------|-----------|-------------|
| fullVisitorId | STRING | Unique identifier for each visitor. |
| date | STRING | Session date in `YYYYMMDD` format. |
| totals | RECORD | Aggregated metrics at the session level. |
| totals.bounces | INTEGER | Indicates a bounced session (1 = bounce, null otherwise). |
| totals.hits | INTEGER | Total number of hits within the session. |
| totals.pageviews | INTEGER | Total number of pageviews within the session. |
| totals.visits | INTEGER | Number of sessions (1 if interaction exists, otherwise null). |
| totals.transactions | INTEGER | Total number of ecommerce transactions in the session. |
| trafficSource.source | STRING | Traffic acquisition source (e.g. search engine, referral, UTM source). |
| hits | RECORD | Nested hit-level data containing user interactions. |
| hits.eCommerceAction | RECORD | Contains ecommerce actions performed during the session. |
| hits.eCommerceAction.action_type | STRING | Type of ecommerce action (view, add to cart, purchase, etc.). |
| hits.product | RECORD | Nested product-level information. |
| hits.product.productQuantity | INTEGER | Quantity of the product purchased. |
| hits.product.productRevenue | INTEGER | Product revenue in micro-units (must be divided by 1,000,000). |
| hits.product.productSKU | STRING | Unique product SKU identifier. |
| hits.product.v2ProductName | STRING | Product name. |
| device.deviceCategory | STRING | Device category (Desktop, Mobile, Tablet). |


---

### Key Columns Used

| Column Name | Description |
|------------|-------------|
| fullVisitorId | Unique identifier for each user |
| date | Session date (YYYYMMDD) |
| totals.visits | Number of visits |
| totals.pageviews | Number of page views |
| totals.transactions | Number of transactions |
| totals.bounces | Bounce indicator |
| trafficSource.source | Traffic acquisition source |
| hits | Nested hit-level records |
| hits.eCommerceAction.action_type | User action type (view, add-to-cart, purchase) |
| product.productRevenue | Revenue per product (stored in micros) |
| product.productQuantity | Quantity purchased |
| product.v2ProductName | Product name |

---


## ⚒️ Main Process

### 1️⃣ Data Cleaning & Preprocessing  

Before performing any analysis, the raw Google Analytics data must be cleaned and transformed to ensure accuracy and consistency. Since the dataset contains nested structures and raw event-level records, preprocessing is required before meaningful aggregation.

The following data preparation steps were applied:

- Parsed `date` from string format (`YYYYMMDD`) into a usable date format
- Flattened nested fields (`hits`, `hits.product`) using `UNNEST()`
- Removed records with null revenue when analyzing purchase behavior
- Converted revenue values from micro-units to standard currency
- Aggregated data at appropriate levels (user, session, month, week)
- Ensured no double counting when working with nested records

These steps ensure that all metrics used in later analysis are reliable, consistent, and correctly aggregated.

---

## 🔍 Exploratory Data Analysis (EDA)

EDA is used to understand traffic behavior, engagement patterns, and purchasing activities before drawing business conclusions. This section explores how users interact with the website from different perspectives such as time, traffic source, and purchase behavior.

---

### ✅ Task 1: Monthly Traffic Overview (Jan–Mar 2017)

**Purpose & Business Meaning**

This task analyzes overall website activity over time by measuring visits, pageviews, and transactions on a monthly basis. Understanding traffic trends helps stakeholders evaluate seasonality, campaign performance, and general user engagement.

A stable or growing trend may indicate healthy acquisition performance, while fluctuations may suggest campaign effects or external influences.

**Metrics analyzed:**
- Total visits  
- Total pageviews  
- Total transactions

```SELECT
  FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d', date)) AS month,
  COUNT(DISTINCT fullVisitorId) AS visits,
  SUM(totals.pageviews) AS pageviews,
  SUM(totals.transactions) AS transactions
FROM`bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
WHERE _TABLE_SUFFIX BETWEEN '0101' AND '0331' 
GROUP BY month
ORDER BY month;
```


📌 <img width="786" height="142" alt="image" src="https://github.com/user-attachments/assets/aad5e558-dd09-4570-ad92-8dc984067080" />


**Key observations:**
- Traffic and engagement fluctuate across months.
- Helps identify seasonal or campaign-driven patterns.
- Provides baseline KPIs for deeper funnel analysis.

---

### ✅ Task 2: Bounce Rate by Traffic Source (July 2017)

**Purpose & Business Meaning**

Bounce rate represents the percentage of sessions in which users leave the website after viewing only one page. A high bounce rate may indicate poor traffic quality, irrelevant landing pages, or unmet user expectations.

Analyzing bounce rate by traffic source helps identify which acquisition channels bring high-quality users versus low-engagement traffic.

**Metric definition:**
Bounce Rate = (Total Bounces / Total Visits) × 100
```WITH source_s AS (
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
```

📌 <img width="795" height="202" alt="image" src="https://github.com/user-attachments/assets/a2f30931-197c-4736-8d63-330676f15105" />


**Key observations:**
- Bounce rates vary significantly across traffic sources.
- Some channels generate high traffic but low engagement.
- Results help prioritize marketing optimization efforts.

---

### ✅ Task 3: Revenue by Traffic Source (Weekly & Monthly – June 2017)

**Purpose & Business Meaning**

This task evaluates how much revenue each traffic source contributes over time. Unlike traffic volume, revenue reflects real business value and helps distinguish high-quality acquisition channels.

Revenue is analyzed at both monthly and weekly levels to capture long-term trends and short-term campaign effects.
```WITH monthly_revenue AS (
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
```

📌 <img width="988" height="201" alt="image" src="https://github.com/user-attachments/assets/f4c01c8f-0d11-4ff2-8881-8cd94fc1351a" />


**Key observations:**
- Certain traffic sources consistently outperform others in revenue.
- Weekly analysis reveals short-term spikes linked to promotions or campaigns.
- Enables comparison between volume-driven vs value-driven channels.

---

### ✅ Task 4: Average Pageviews — Purchasers vs Non-Purchasers (Jun–Jul 2017)

**Purpose & Business Meaning**

This analysis compares engagement behavior between users who completed a purchase and those who did not. Pageviews serve as a proxy for user interest and exploration depth.

Higher pageviews often indicate stronger purchase intent.

**Metric:**
Average pageviews = Total pageviews / Number of users
```WITH raw_data AS (
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
```

📌 <img width="776" height="102" alt="image" src="https://github.com/user-attachments/assets/94d88b77-6904-4b4d-9a82-60a9ab592180" />


**Key observations:**
- Purchasers tend to view significantly more pages than non-purchasers.
- Deeper engagement strongly correlates with conversion likelihood.
- Improving navigation and product discovery may increase conversions.

---

### ✅ Task 5: Average Number of Transactions per Purchasing User (July 2017)

**Purpose & Business Meaning**

This task measures how frequently users who made at least one purchase complete transactions within the period.

It helps distinguish between one-time buyers and repeat customers.

**Metric:**
Average transactions per user = Total transactions / Number of purchasing users
```WITH purchasers AS (
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
```

📌 <img width="431" height="61" alt="image" src="https://github.com/user-attachments/assets/a72fef1b-a8da-4569-94d7-a0140cb8f251" />


**Key observations:**
- Identifies repeat-purchase behavior.
- Useful for customer retention and loyalty analysis.
- Indicates whether revenue growth is driven by frequency or customer volume.

---

### ✅ Task 6: Average Revenue per Visit (Purchasers Only – July 2017)

**Purpose & Business Meaning**

This analysis evaluates monetization efficiency by measuring how much revenue is generated per visit among purchasing users.

**Metric:**
Average revenue per visit = Total revenue / Total visits
```WITH sessions AS (
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
```

📌 <img width="424" height="68" alt="image" src="https://github.com/user-attachments/assets/31b848ef-50e7-4dce-82af-905bb9a0659f" />

**Key observations:**
- Reflects overall monetization effectiveness.
- Useful KPI for evaluating marketing ROI.
- Can guide pricing, promotion, and upselling strategies.

---

### ✅ Task 7: Cross-Sell Analysis  
**Other products purchased together with “YouTube Men's Vintage Henley”**

**Purpose & Business Meaning**

This analysis identifies products frequently purchased together with a specific product. Such insights are commonly used for recommendation systems and bundle creation.
```WITH buyers AS (
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

```

📌 <img width="606" height="202" alt="image" src="https://github.com/user-attachments/assets/9474fe0f-52d5-4c57-ad5b-9c8e3c970d0d" />


**Key observations:**
- Reveals product affinity patterns.
- Supports “Frequently Bought Together” recommendations.
- Useful for bundle and cross-selling strategies.

---

### ✅ Task 8: Conversion Funnel Analysis (Jan–Mar 2017)

**Purpose & Business Meaning**

This task evaluates how users progress through the e-commerce funnel:

1. Product View  
2. Add to Cart  
3. Purchase  

The goal is to identify where users drop off and where optimization is most needed.

**Metrics calculated:**
- Add-to-cart rate  
- Purchase rate  
```WITH raw_data AS (
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

```
📌 <img width="946" height="134" alt="image" src="https://github.com/user-attachments/assets/e92230f4-247c-41eb-a962-1364d8d74421" />


**Key observations:**
- Significant drop-offs occur between funnel stages.
- Indicates friction in product pages or checkout flow.
- Helps prioritize UX and conversion optimization efforts.



<a id="final-conclusion--recommendations"></a>
## 📊 Final Conclusion & Recommendations 

### 📍 Key Insights  

✔️ High traffic volume alone does not guarantee high revenue — engagement quality plays a critical role.  

✔️ Bounce rate varies significantly across traffic sources, reflecting differences in traffic quality and landing page relevance.  

✔️ Purchasers consistently show higher engagement (pageviews) than non-purchasers.  

✔️ Revenue contribution differs substantially across acquisition channels and time periods.  

✔️ Conversion funnel analysis reveals clear drop-offs between product view, add-to-cart, and purchase stages.  

✔️ Product co-purchase behavior uncovers strong opportunities for cross-selling and bundling strategies.  

---




### ✅ Business Recommendations  

1. **Optimize low-quality traffic sources**  
   Improve targeting, messaging, and landing page relevance for channels with high bounce rates.

2. **Prioritize high-performing acquisition channels**  
   Allocate marketing budget toward sources that consistently generate higher revenue rather than high traffic volume alone.

3. **Improve on-site engagement and navigation**  
   Enhance internal search, category structure, and product discovery to increase page depth.

4. **Reduce funnel friction**  
   Optimize product detail pages, add-to-cart flow, and checkout experience to minimize drop-offs.

5. **Apply cross-selling and bundling strategies**  
   Use product co-purchase insights to recommend related items and increase average order value.

---
