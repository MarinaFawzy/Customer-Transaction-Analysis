/*
Customers are then divided into three groups based on their total spending, 
with Class A representing customers with the highest spending, 
Class B representing customers with moderate spending, and
 Class C representing customers with the lowest spending.
*/

WITH customer_partition AS (
    -- Subquery to calculate total price for each customer and assign them to groups
    SELECT
        customer_id,
        total_price,
        -- Divide customers into three groups based on total price
        ntile(3) OVER (ORDER BY total_price DESC) AS cust_group
    FROM (
        -- Subquery to calculate total price for each customer
        SELECT
            DISTINCT customer_id,
            -- Calculate total price for each customer
            SUM(price * quantity) OVER (PARTITION BY customer_id) AS total_price
        FROM
            tableRetail
    )
)
-- Select customer ID, total price, and their corresponding group labels
SELECT
    customer_id,
    total_price,
    -- Assign labels to each group
    CASE
        WHEN cust_group = 1 THEN 'Class A'
        WHEN cust_group = 2 THEN 'Class B'
        ELSE 'Class C'
    END AS customer_class
FROM
    customer_partition;


------------------------------------------------------------------


/*
This query retrieves data from a retail transactions table to determine the top-selling items based on the total quantity sold. 
 It calculates the sum of quantities for each unique stock code and ranks them in descending order based on their total quantity sold. 
 The resulting dataset provides insights into the most popular items in terms of sales volume.

*/

-- Select stock code, sum of quantity, and rank the stock codes based on total quantity sold
SELECT 
    stockcode,  
    SUM(quantity),  
    RANK() OVER (ORDER BY SUM(quantity) DESC) AS top_selling  -- Rank the stock codes based on total quantity sold in descending order
FROM 
    tableRetail  
GROUP BY 
    stockcode;  

-----------------------------------------------------

/*

 This query computes the total spending of each customer and determines their percentile rank based on total spending.
 It first calculates the total spending for each customer by summing the product of price and quantity for each transaction.
 Then, it computes the percentile rank of each customer's total spending within the dataset.
 The resulting dataset includes customers with a percentile rank of 90% or higher, providing insights into high-spending customers.

*/

WITH customer_rank AS (
    -- Subquery to calculate total price for each customer and their percentile rank
    SELECT 
        customer_id, 
        total_price,
        -- Calculate the percentile rank of each customer's total spending
        ROUND(PERCENT_RANK() OVER (ORDER BY total_price) * 100, 2) AS percentrank
    FROM (
        -- Subquery to calculate total price for each customer
        SELECT DISTINCT 
            customer_id, 
            SUM(price * quantity) OVER (PARTITION BY customer_id) AS total_price
        FROM 
            tableRetail 
    )
)
-- Select all columns from the customer_rank CTE
SELECT 
    * 
FROM 
    customer_rank  
WHERE 
    percentrank >= 90;  -- Filter the results to include only customers with a percentile rank of 90% or higher


----------------------------------------------------

/*
 This query retrieves all information about the most recent invoice for each stock code.
 It assigns ranks to rows within each stock code based on the invoice date, with rank 1 indicating the most recent invoice.
 The results include details of transactions from the tableRetail table, filtered to include only the rows with rank 1, representing the latest invoice date for each stock code.

*/

-- This query retrieves all information about the most recent invoice for each stock.
SELECT   CUSTOMER_ID,INVOICE,STOCKCODE,PRICE,INVOICEDATE
FROM (
    -- Subquery to assign ranks to rows within each stock code based on the invoice date
    SELECT  
        tableRetail.*, 
        RANK() OVER (PARTITION BY stockcode ORDER BY TO_DATE(INVOICEDATE, 'MM/DD/YYYY HH24:MI') DESC) AS rank  
    FROM 
        tableRetail  
)  new_tableRetail
WHERE 
    rank = 1;  -- Filter the results to include only rows with rank 1, indicating the latest invoice date for each stock code

-----------------------------------------------------

/*

 This query calculates the total sales for each month and ranks the months based on their total sales to identify the best purchase months.
 It begins by extracting the month from the InvoiceDate column and computing the total sales (quantity * price) for each month.
 The results are then ordered by total sales in descending order, and each month is assigned a rank based on its total sales, with the highest sales receiving rank 1.
 The final output includes the sales month and its corresponding total sales, along with their respective ranks, providing insights into the best-performing purchase months.

*/


-- Calculate the total sales for each month and then order the results by month in descending order to identify the best purchase months
WITH DETAILS AS (
    -- Subquery to calculate total sales for each month
    SELECT   
        EXTRACT(MONTH FROM TO_DATE(InvoiceDate, 'MM/DD/YYYY HH24:MI')) AS month,  
        SUM(Quantity * Price) AS totalsales  
    FROM  
        tableRetail  
    GROUP BY  
        EXTRACT(MONTH FROM TO_DATE(InvoiceDate, 'MM/DD/YYYY HH24:MI'))  
)
-- Select sales month and total sales along with their ranks
SELECT  
    month,  
    totalsales  
FROM  
(
    -- Subquery to assign ranks to each month based on total sales
    SELECT 
        month, 
        totalsales,  
        ROW_NUMBER() OVER (ORDER BY TotalSales DESC) AS rank -- Assign ranks to each month based on total sales, with the highest sales receiving rank 1 
    FROM  
        DETAILS  
    ORDER BY 
        totalsales DESC
) arrang;

-------------------------------------------------

/*
segments customers based on RFM (Recency, Frequency, Monetary) analysis. It calculates RFM metrics 
for each customer, assigns RFM scores, and then determines customer segments based on these scores. 
Segments include "Champions," "Loyal Customers," "At Risk," etc., reflecting different purchasing 
behaviors. This segmentation helps businesses understand and target customer groups more effectively 
for marketing and retention efforts 
*/


-- CTE to calculate Recency, Frequency, and Monetary value (RFM) metrics for each customer 
WITH customer_rfm_metrics AS ( 
    SELECT  
        Customer_ID,  
        ROUND(MAX((SELECT MAX(TO_DATE(INVOICEDATE, 'MM/DD/YYYY HH24:MI')) FROM tableretail)) - MAX(TO_DATE(INVOICEDATE, 'MM/DD/YYYY HH24:MI'))) AS Recency, 
        SUM(Quantity * Price) AS MonetaryValue,  
        COUNT(*) AS Frequency 
    FROM  
        tableretail 
    GROUP BY  
        Customer_ID  
),
-- CTE to assign RFM scores to each customer 
customer_rfm_scores AS ( 
    SELECT  
        CUSTOMER_ID, 
        Recency,
        Frequency,
        MonetaryValue, 
        NTILE(5) OVER (ORDER BY Recency DESC) AS RecencyScore,   
        NTILE(5) OVER (ORDER BY Frequency) AS FrequencyScore, 
        NTILE(5) OVER (ORDER BY MonetaryValue) AS MonetaryScore  
    FROM  
        customer_rfm_metrics 
),
-- CTE to calculate the combined RFM score and assign customer segments 
customer_rfm_segments AS (
    SELECT 
        CUSTOMER_ID, 
        Recency,
        Frequency,
        MonetaryValue,
        RecencyScore,  
        ROUND((FrequencyScore + MonetaryScore) / 2) AS FM_SCORE 
    FROM  
        customer_rfm_scores 
)
-- Selecting final metrics and assigning customer segments
SELECT 
    CUSTOMER_ID, 
    Recency,
    Frequency,
    MonetaryValue, 
    RecencyScore, 
    FM_SCORE, 
    CASE 
        WHEN (RecencyScore = 5 AND FM_SCORE = 5) OR (RecencyScore = 5 AND FM_SCORE = 4) OR (RecencyScore = 4 AND FM_SCORE = 5) THEN 'Champions' 
        WHEN (RecencyScore = 5 AND FM_SCORE = 2) OR (RecencyScore = 4 AND FM_SCORE = 2) OR (RecencyScore = 3 AND FM_SCORE = 3) OR (RecencyScore = 4 AND FM_SCORE = 3) THEN 'Potential Loyalists' 
        WHEN (RecencyScore = 5 AND FM_SCORE = 3) OR (RecencyScore = 4 AND FM_SCORE = 4) OR (RecencyScore = 3 AND FM_SCORE = 5) OR (RecencyScore = 3 AND FM_SCORE = 4) THEN 'Loyal Customers' 
        WHEN (RecencyScore = 5 AND FM_SCORE = 1) THEN 'Recent Customers' 
        WHEN (RecencyScore = 4 AND FM_SCORE = 1) OR (RecencyScore = 3 AND FM_SCORE = 1) THEN 'Promising' 
        WHEN (RecencyScore = 3 AND FM_SCORE = 2) OR (RecencyScore = 2 AND FM_SCORE = 3) OR (RecencyScore = 2 AND FM_SCORE = 2) THEN 'Customers Needing Attention' 
        WHEN (RecencyScore = 2 AND FM_SCORE = 5) OR (RecencyScore = 2 AND FM_SCORE = 4) OR (RecencyScore = 1 AND FM_SCORE = 3) THEN 'At Risk' 
        WHEN (RecencyScore = 1 AND FM_SCORE = 5) OR (RecencyScore = 1 AND FM_SCORE = 4) THEN ' Can not Lose Them'
        WHEN (RecencyScore = 1 AND FM_SCORE = 2) THEN 'Hibernating' 
        WHEN (RecencyScore = 1 AND FM_SCORE = 1) THEN 'Lost' 
        ELSE 'About to Sleep' 
    END AS CustomerSegment 
FROM 
    customer_rfm_segments 
ORDER BY 
    CustomerSegment; 


/*
This SQL query analyzes customer engagement by identifying the maximum consecutive days of activity for each customer.
 It calculates the number of consecutive days each customer has been active and determines the maximum consecutive day count, 
 offering valuable insights into customer behavior and engagement patterns over time.
*/

WITH consecutive_days AS ( 
    -- CTE to identify consecutive days for each customer
    SELECT 
        CUSTOMER_ID, 
        Dates, 
        CASE 
            WHEN Dates - LAG(Dates) OVER (PARTITION BY CUSTOMER_ID ORDER BY Dates) = 1 THEN 0 -- Check if the date is consecutive 
            ELSE 1 -- Start a new group if the date is not consecutive 
        END AS is_consecutive_group 
    FROM 
        hr.customers 
), 
-- CTE to count the number of consecutive days for each customer 
consecutive_counts AS ( 
    SELECT 
        CUSTOMER_ID, 
        Dates, 
        SUM(is_consecutive_group) OVER (PARTITION BY CUSTOMER_ID ORDER BY Dates) AS 
        consecutive_day_count 
    FROM 
        consecutive_days 
), 
-- CTE to count consecutive day occurrences for each customer 
final_table AS ( 
    SELECT 
        CUSTOMER_ID, 
        consecutive_day_count, 
        COUNT(consecutive_day_count) AS occurrences_count 
    FROM 
        consecutive_counts 
    GROUP BY 
        CUSTOMER_ID, 
        consecutive_day_count 
) 
-- Select the maximum consecutive day count for each customer 
SELECT 
    CUSTOMER_ID, 
    MAX(occurrences_count) AS max_consecutive_day 
FROM 
    final_table 
GROUP BY 
    CUSTOMER_ID 
ORDER BY 
    CUSTOMER_ID;




----------------------------------------------------------------------------------

/*
This SQL query calculates the average minimum spending rank across all customers, providing a concise measure of customer spending behavior within the dataset.
*/
-- CTE to calculate cumulative spending for each customer over time
WITH customer_cumulative_spending AS (
    SELECT 
        customer_id, 
        dates, 
        SUM(amount) OVER (PARTITION BY customer_id ORDER BY dates) AS cumulative_spending 
    FROM 
        hr.customers 
),
-- CTE to assign row numbers for each customer's cumulative spending, ordered by spending amount
customer_spending_ranks AS (
    SELECT 
        customer_cumulative_spending.*,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY cumulative_spending) AS spending_rank 
    FROM 
        customer_cumulative_spending 
),
-- CTE to filter out records where cumulative spending is less than 250
filtered_cumulative_spending AS (
    SELECT 
        * 
    FROM  
        customer_spending_ranks 
    WHERE  
        cumulative_spending >= 250 
),
-- CTE to determine the minimum row number for each customer's spending
min_spending_row AS (
    SELECT 
        customer_id, 
        MIN(spending_rank) AS min_rank 
    FROM 
        filtered_cumulative_spending 
    GROUP BY 
        customer_id 
)
-- Calculate the average of the minimum row numbers across all customers
SELECT 
    ROUND(AVG(min_rank),3) AS average_min_rank 
FROM  
    min_spending_row;
