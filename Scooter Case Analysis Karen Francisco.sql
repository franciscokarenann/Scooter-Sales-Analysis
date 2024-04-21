/** Karen Francisco  **/
/***BE SURE TO DROP ALL TABLES IN WORK THAT BEGIN WITH "CASE_"***/

/*Set Time Zone*/
set time_zone='-4:00';
select now();

/***PRELIMINARY ANALYSIS***/

/*Create a VIEW in WORK called CASE_SCOOT_NAMES that is a subset of the prod table
which only contains scooters.
Result should have 7 records.*/
CREATE VIEW work.case_scoot_names as
	Select * from ba710case.ba710_prod
		where product_type in ('scooter');
        
select * from work.case_scoot_names;

/*The following code uses a join to combine the view above with the sales information.
  Can the expected performance be improved using an index?
  A) Calculate the EXPLAIN COST.
  B) Create the appropriate indexes.
  C) Calculate the new EXPLAIN COST.
  D) What is your conclusion?:
  
  
*/

select a.model, a.product_type, a.product_id,
    b.customer_id, b.sales_transaction_date, date(b.sales_transaction_date) as sale_date,
    b.sales_amount, b.channel, b.dealership_id
from work.case_scoot_names a 
inner join ba710case.ba710_sales b
    on a.product_id=b.product_id;
    
# A) Calculate the EXPLAIN COST. 4589.01
  
  EXPLAIN FORMAT = JSON select a.model, a.product_type, a.product_id,
    b.customer_id, b.sales_transaction_date, date(b.sales_transaction_date) as sale_date,
    b.sales_amount, b.channel, b.dealership_id
from work.case_scoot_names a 
inner join ba710case.ba710_sales b
    on a.product_id=b.product_id;
     
# B) Create the appropriate indexes.
	Create index idx_prod on ba710case.ba710_sales(product_id);
    Create index idx_prod on work.case_scoot_names(product_id); #cannot create index in work.case_scoot_names as this is a view, not a base table
	
     
# C) Calculate the new EXPLAIN COST. 615.85
  
  EXPLAIN FORMAT = JSON select a.model, a.product_type, a.product_id,
    b.customer_id, b.sales_transaction_date, date(b.sales_transaction_date) as sale_date,
    b.sales_amount, b.channel, b.dealership_id
from work.case_scoot_names a 
inner join ba710case.ba710_sales b
    on a.product_id=b.product_id;
    
# D) What is your conclusion?:
/*Creating an index in the base table ba710case.ba710_sales for product_id greatly improved the cost from 4589.01 to 615.85 */


/***PART 1: INVESTIGATE BAT SALES TRENDS***/  
    
/*The following creates a table of daily sales with four columns and will be used in the following step.*/

CREATE TABLE work.case_daily_sales AS
	select p.model, p.product_id, date(s.sales_transaction_date) as sale_date, 
		   round(sum(s.sales_amount),2) as daily_sales
	from ba710case.ba710_sales as s 
    inner join ba710case.ba710_prod as p
		on s.product_id=p.product_id
    group by date(s.sales_transaction_date),p.product_id,p.model;

select * from work.case_daily_sales;

/*Create a view (5 columns)of cumulative sales figures for just the Bat scooter from
the daily sales table you created.
Using the table created above, add a column that contains the cumulative
sales amount (one row per date).
Hint: Window Functions, Over*/

CREATE VIEW work.cumu_sales_bat as
	Select *, round(sum(daily_sales) over (order by sale_date), 2) as cumulative_sales
		from work.case_daily_sales
        where model in ('Bat');

Select * from work.cumu_sales_bat;

/*Using the view above, create a VIEW (6 columns) that computes the cumulative sales 
for the previous 7 days for just the Bat scooter. 
(i.e., running total of sales for 7 rows inclusive of the current row.)
This is calculated as the 7 day lag of cumulative sum of sales
(i.e., each record should contain the sum of sales for the current date plus
the sales for the preceeding 6 records).
*/

CREATE VIEW work.cumu_sales_7_days_bat AS
	Select *, round(sum(daily_sales) over(rows between 6 preceding and current row), 2) as cum_sales_7_days
    from work.cumu_sales_bat;
    
Select * from work.cumu_sales_7_days_bat;

/*Using the view you just created, create a new view (7 columns) that calculates
the weekly sales growth as a percentage change of cumulative sales
compared to the cumulative sales from the previous week (seven days ago).
See the Word document for an example of the expected output for the Blade scooter.*/

CREATE VIEW work.weekly_sales_bat AS
	Select *, round((cumulative_sales-(lag(cumulative_sales,7) over())) / (lag(cumulative_sales,7) over ())*100, 2)as pct_weekly_increase_cumu_sales
	from work.cumu_sales_7_days_bat;

Select * from work.weekly_sales_bat;


/* Question: On what date does the cumulative weekly sales growth drop below 10%?
Answer: 2016-12-06 */

select min(sale_date)
from WORK.weekly_sales_bat
where pct_weekly_increase_cumu_sales < 10;

/*Question: How many days since the launch date did it take for cumulative sales growth
to drop below 10%?
Answer: 57 days*/

select b.model "model", date(b.production_start_date) "launch date", 
datediff(min(a.sale_date), b.production_start_date) 
from WORK.weekly_sales_bat a,
ba710case.ba710_prod b
where b.model in ('Bat')
and pct_weekly_increase_cumu_sales < 10
group by b.production_start_date;

/*********************************************************************************************
Is the launch timing (October) a potential cause for the drop?
Replicate the Bat sales cumulative analysis for the Bat Limited Edition.
*/

/*Cumulative Sales for Bat Limited edition*/

CREATE VIEW work.cumu_sales_bat_limited as
	Select *, round(sum(daily_sales) over (order by sale_date), 2) as cumulative_sales
		from work.case_daily_sales
        where model in ('Bat Limited Edition');

Select * from work.cumu_sales_bat_limited;

/*Cumulative Sales for 7 days for Bat Limited Edition*/
CREATE VIEW work.cumu_sales_7_days_bat_limited AS
	Select *, round(sum(daily_sales) over(rows between 6 preceding and current row), 2) as cum_sales_7_days
    from work.cumu_sales_bat_limited;
    
Select * from work.cumu_sales_7_days_bat_limited;

/*Weekly Sales for Bat Limited Edition*/
CREATE VIEW work.weekly_sales_bat_limited AS
	Select *, round((cumulative_sales-(lag(cumulative_sales,7) over())) / (lag(cumulative_sales,7) over ())*100, 2)as pct_weekly_increase_cumu_sales
	from work.cumu_sales_7_days_bat_limited;

Select * from work.weekly_sales_bat_limited;

/* Questions: On what date does the cumulative weekly sales growth drop below 10%?
Answer: 2017-04-29 */

select min(sale_date)
from WORK.weekly_sales_bat_limited
where pct_weekly_increase_cumu_sales < 10;

/*Question: How many days since the launch date did it take for cumulative sales growth
to drop below 10%?
Answer: 73 days*/

select b.model "model", date(b.production_start_date) "launch date", 
datediff(min(a.sale_date), b.production_start_date) 
from WORK.weekly_sales_bat_limited a,
ba710case.ba710_prod b
where b.model in ('Bat Limited Edition')
and pct_weekly_increase_cumu_sales < 10
group by b.production_start_date;
  
/*Question: Is there a difference in the behavior in cumulative sales growth 
between the Bat edition and the Bat Limited edition?  (Make a statement comparing
the growth statistics.)
Answer:                            */

Select * from ba710case.ba710_prod
where model in ('Bat', 'Bat Limited Edition');

/*********************************************************************************************
However, the Bat Limited was at a higher price point.
Let's take a look at the 2013 Lemon model, since it's a similar price point.  
Is the launch timing (October) a potential cause for the drop?
Replicate the Bat sales cumulative analysis for the 2013 Lemon model.*/

/*Cumulative Sales for 2013 Lemon edition*/

CREATE VIEW work.cumu_sales_lemon_2013 as
	Select *, round(sum(daily_sales) over (order by sale_date), 2) as cumulative_sales
		from work.case_daily_sales
        where model in ('Lemon')
        and product_id = '3';

Select * from work.cumu_sales_lemon_2013;

/*Cumulative Sales for 7 days for 2013 Lemon edition*/
CREATE VIEW work.cumu_sales_7_days_lemon_2013 AS
	Select *, round(sum(daily_sales) over(rows between 6 preceding and current row), 2) as cum_sales_7_days
    from work.cumu_sales_lemon_2013;
    
Select * from work.cumu_sales_7_days_lemon_2013;

/*Weekly Sales for 2013 Lemon edition*/
CREATE VIEW work.weekly_sales_lemon_2013 AS
	Select *, round((cumulative_sales-(lag(cumulative_sales,7) over())) / (lag(cumulative_sales,7) over ())*100, 2)as pct_weekly_increase_cumu_sales
	from work.cumu_sales_7_days_lemon_2013;

Select * from work.weekly_sales_lemon_2013;


/* Questions: On what date does the cumulative weekly sales growth drop below 10%?
Answer: 2013-07-01 */

select min(sale_date)
from WORK.weekly_sales_lemon_2013
where pct_weekly_increase_cumu_sales < 10;

/*Question: How many days since the launch date did it take for cumulative sales growth
to drop below 10%?
Answer: 61 days*/

select b.model "model", date(b.production_start_date) "launch date",
datediff(min(a.sale_date), b.production_start_date) 
from WORK.weekly_sales_lemon_2013 a,
ba710case.ba710_prod b
where b.model in ('Lemon')
and b.product_id = '3'
and pct_weekly_increase_cumu_sales < 10
group by b.production_start_date;
  
/*Question: Is there a difference in the behavior in cumulative sales growth 
between the Bat edition and the 2013 Lemon edition?  (Make a statement comparing
the growth statistics.)
Answer:                            */

Select * from ba710case.ba710_prod
where model in ('Bat', 'Lemon', 'Bat Limited Edition')
and product_id in ('7', '3', '8');

