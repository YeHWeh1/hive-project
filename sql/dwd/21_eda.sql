-- 第 2 周 · 子任务 7：探索性数据分析（EDA）
-- 基于 DWD 星型模型，完成 KPI、多维分布、窗口函数分析
-- 用法：beeline -u jdbc:hive2://localhost:10000/ -f /sql/dwd/21_eda.sql

-- ========== 1. 核心 KPI ==========
select
  round(sum(pay_amount), 2)                              as gmv,
  count(distinct order_id)                               as order_cnt,
  count(distinct user_id)                                as buyer_cnt,
  round(sum(pay_amount) / count(distinct order_id), 2)   as aov
from ydsh_dwd.fact_order
where amount_invalid = 0;

-- ========== 2. 月度销售趋势 ==========
select
  order_month,
  count(distinct order_id)              as order_cnt,
  round(sum(pay_amount), 2)             as gmv,
  round(sum(pay_amount) / count(distinct order_id), 2) as aov
from ydsh_dwd.fact_order
where amount_invalid = 0
group by order_month
order by order_month;

-- ========== 3. 品类销售分布（订单明细 -> 商品维度） ==========
select
  p.category,
  count(distinct oi.order_id)           as order_cnt,
  sum(oi.quantity)                      as qty,
  round(sum(oi.item_amount), 2)         as sales
from ydsh_dwd.fact_order_item oi
join ydsh_dwd.dim_product p on oi.product_id = p.product_id
where oi.qty_invalid = 0
group by p.category
order by sales desc;

-- ========== 4. 省份销售分布（订单 -> 用户维度） ==========
select
  u.province,
  count(distinct f.order_id)            as order_cnt,
  round(sum(f.pay_amount), 2)           as gmv
from ydsh_dwd.fact_order f
join ydsh_dwd.dim_user u on f.user_id = u.user_id
where f.amount_invalid = 0
group by u.province
order by gmv desc
limit 10;

-- ========== 5. 门店销售排行 ==========
select
  s.store_name,
  count(distinct f.order_id)            as order_cnt,
  round(sum(f.pay_amount), 2)           as gmv
from ydsh_dwd.fact_order f
join ydsh_dwd.dim_store s on f.store_id = s.store_id
where f.amount_invalid = 0
group by s.store_name
order by gmv desc
limit 10;

-- ========== 6. 渠道分布 ==========
select
  c.channel_name,
  count(distinct f.order_id)            as order_cnt,
  round(sum(f.pay_amount), 2)           as gmv,
  round(avg(f.pay_amount), 2)           as avg_amount
from ydsh_dwd.fact_order f
join ydsh_dwd.dim_channel c on f.channel_code = c.channel_code
where f.amount_invalid = 0
group by c.channel_name
order by gmv desc;

-- ========== 7. 支付方式与状态构成 ==========
select p.pay_name, count(*) as order_cnt, round(sum(f.pay_amount), 2) as gmv
from ydsh_dwd.fact_order f join ydsh_dwd.dim_pay_type p on f.pay_code = p.pay_code
where f.amount_invalid = 0
group by p.pay_name order by order_cnt desc;

select s.status_name, count(*) as order_cnt, round(sum(f.pay_amount), 2) as gmv
from ydsh_dwd.fact_order f join ydsh_dwd.dim_order_status s on f.status_code = s.status_code
where f.amount_invalid = 0
group by s.status_name order by order_cnt desc;

-- ========== 8. 窗口函数：用户累计消费与排名 ==========
-- 每个用户按时间顺序累计消费金额，并给出其订单在本用户内的序号
select
  user_id, order_id, order_timestamp, pay_amount,
  sum(pay_amount) over (partition by user_id order by order_timestamp
                        rows between unbounded preceding and current row) as cum_amount,
  row_number()    over (partition by user_id order by order_timestamp)     as rn_in_user
from ydsh_dwd.fact_order
where amount_invalid = 0
order by user_id, rn_in_user
limit 20;

-- ========== 9. 用户消费分层（高价值用户） ==========
select
  t.user_id, t.total_amount, t.order_cnt,
  rank() over (order by t.total_amount desc) as rk
from (
  select user_id, round(sum(pay_amount), 2) as total_amount, count(*) as order_cnt
  from ydsh_dwd.fact_order
  where amount_invalid = 0
  group by user_id
) t
order by rk
limit 10;

-- ========== 10. 会员等级消费对比 ==========
select
  l.level_name,
  count(distinct f.user_id)             as user_cnt,
  count(distinct f.order_id)            as order_cnt,
  round(sum(f.pay_amount), 2)           as gmv,
  round(avg(f.pay_amount), 2)           as avg_per_order
from ydsh_dwd.fact_order f
join ydsh_dwd.dim_user u        on f.user_id = u.user_id
join ydsh_dwd.dim_member_level l on u.member_level_code = l.level_code
where f.amount_invalid = 0
group by l.level_name, l.sort_no
order by l.sort_no;
