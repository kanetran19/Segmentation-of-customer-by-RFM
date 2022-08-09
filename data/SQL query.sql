with rfm_metrics as (
    select customer_id, 
    MAX (adjusted_created_at)::Date as last_active_date,
    current_date - MAX (adjusted_created_at)::Date as recency,
    COUNT (distinct sales_id) as frequency,
    sum (net_sales) as monetary
    from sales_adjusted
    where adjusted_created_at >= current_date - interval '1 year'
    group by customer_id)
, rfm_percent_rank as (
    select *, 
    percent_rank() over (order by frequency) as frequency_percent_rank,
    percent_rank() over (order by monetary) as monetary_percent_rank
    from rfm_metrics)
, rfm_rank as (
select *
    , case 
        when recency between 0 and 100 then 3
        when recency between 100 and 200 then 2
        when recency between 200 and 370 then 1
        else 0
        end
        as recency_rank
    ,case
        when frequency_percent_rank between 0.8 and 1 then 3
        when frequency_percent_rank between 0.5 and 8 then 2
        when frequency_percent_rank between 0 and 0.5 then 1
        else 0
        end
        as frequency_rank
    ,case 
        when monetary_percent_rank between 0.8 and 1 then 3
        when monetary_percent_rank between 0.5 and 8 then 2
        when monetary_percent_rank between 0 and 0.5 then 1
        else 0
        end as monetary_rank
from rfm_percent_rank),
rfm_concat as (
    select *, concat (recency_rank, frequency_rank, monetary_rank) as rfm_rank_concat
    from rfm_rank)
select *, 
case 
    when recency_rank = 1 then '1_churned'
    when recency_rank = 2 then '2_churning'
    when recency_rank = 2 then '3_acitve'
end as recency_segment,
case 
    when frequency_rank = 1 then '1_least frequent'
    when frequency_rank = 2 then '2_frequent'
    when frequency_rank = 3 then '3_most_frequent'
end as frequent_segment,
case 
    when monetary_rank = 1 then '1_least spending'
    when monetary_rank = 2 then '2_normal spending'
    when monetary_rank = 3 then '3_most spending'
end as monetery_segment,
case 
    when rfm_rank_concat in ('333', '323') then 'Vip pro'
    when rfm_rank_concat in ('313') then 'Vip, mua si, mua nhieu'
    when rfm_rank_concat in ('223', '233', '133','123') then 'Vip nhung sap rot'
    when rfm_rank_concat in ('213', '113') then 'Vip, mua si, mua nhieu nhung sap rot'
    when rfm_rank_concat in ('332', '331', '322','321') then 'KH binh thuong'
    when rfm_rank_concat in ('311') then 'KH moi'
    when rfm_rank_concat in ('211', '111', '112') then 'khach hang vang lai'
    when rfm_rank_concat in ('212', '312','222', '122') then 'KH tiem nang'
end as rfm_segment
from rfm_concat