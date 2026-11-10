-- 第 3 周 · 子任务 1：DWS 汇总层
-- 设计原则：按「时间 × 维度」轻度汇总，供 ADS 与临时分析复用
-- 统一口径：仅统计有效订单（fact_order.amount_invalid = 0）
-- 用法：beeline -u jdbc:hive2://localhost:10000/ -f /sql/dws/01_dws_sales.sql

create database if not exists ydsh_dws;

-- ========== 1. 日粒度销售汇总 ==========
drop table if exists ydsh_dws.dws_sales_day;
create table ydsh_dws.dws_sales_day (
  stat_date     string         comment '统计日期 yyyy-MM-dd',
  order_cnt     bigint         comment '订单量',
  gmv           decimal(18,2)  comment '成交总额',
  buyer_cnt     bigint         comment '下单用户数',
  aov           decimal(12,2)  comment '客单价 = gmv/order_cnt',
  cancel_cnt    bigint         comment '已取消订单数',
  refund_cnt    bigint         comment '退款中订单数'
) comment '日粒度销售汇总'
stored as orc;

insert overwrite table ydsh_dws.dws_sales_day
select
  substr(order_timestamp, 1, 10)                             as stat_date,
  count(distinct order_id)                                   as order_cnt,
  round(sum(pay_amount), 2)                                  as gmv,
  count(distinct user_id)                                    as buyer_cnt,
  round(sum(pay_amount) / count(distinct order_id), 2)       as aov,
  count(distinct case when status_code = 'ST4' then order_id end) as cancel_cnt,
  count(distinct case when status_code = 'ST5' then order_id end) as refund_cnt
from ydsh_dwd.fact_order
where amount_invalid = 0
group by substr(order_timestamp, 1, 10);

-- ========== 2. 月粒度销售汇总 ==========
drop table if exists ydsh_dws.dws_sales_month;
create table ydsh_dws.dws_sales_month (
  stat_month    string         comment '统计月份 yyyy-MM',
  order_cnt     bigint,
  gmv           decimal(18,2),
  buyer_cnt     bigint,
  aov           decimal(12,2),
  cancel_rate   decimal(6,4)   comment '取消率',
  refund_rate   decimal(6,4)   comment '退款率'
) comment '月粒度销售汇总'
stored as orc;

insert overwrite table ydsh_dws.dws_sales_month
select
  order_month,
  count(distinct order_id),
  round(sum(pay_amount), 2),
  count(distinct user_id),
  round(sum(pay_amount) / count(distinct order_id), 2),
  round(count(distinct case when status_code = 'ST4' then order_id end) / count(distinct order_id), 4),
  round(count(distinct case when status_code = 'ST5' then order_id end) / count(distinct order_id), 4)
from ydsh_dwd.fact_order
where amount_invalid = 0
group by order_month;

-- ========== 3. 月 × 门店 ==========
drop table if exists ydsh_dws.dws_store_month;
create table ydsh_dws.dws_store_month (
  stat_month   string,
  store_id     string,
  store_name   string,
  province     string,
  city         string,
  order_cnt    bigint,
  gmv          decimal(18,2),
  buyer_cnt    bigint,
  aov          decimal(12,2)
) comment '月 × 门店销售汇总'
stored as orc;

insert overwrite table ydsh_dws.dws_store_month
select
  f.order_month,
  f.store_id,
  s.store_name,
  s.province,
  s.city,
  count(distinct f.order_id),
  round(sum(f.pay_amount), 2),
  count(distinct f.user_id),
  round(sum(f.pay_amount) / count(distinct f.order_id), 2)
from ydsh_dwd.fact_order f
join ydsh_dwd.dim_store s on f.store_id = s.store_id
where f.amount_invalid = 0
group by f.order_month, f.store_id, s.store_name, s.province, s.city;

-- ========== 4. 月 × 渠道 ==========
drop table if exists ydsh_dws.dws_channel_month;
create table ydsh_dws.dws_channel_month (
  stat_month    string,
  channel_code  string,
  channel_name  string,
  order_cnt     bigint,
  gmv           decimal(18,2),
  buyer_cnt     bigint,
  aov           decimal(12,2)
) comment '月 × 渠道销售汇总'
stored as orc;

insert overwrite table ydsh_dws.dws_channel_month
select
  f.order_month,
  f.channel_code,
  c.channel_name,
  count(distinct f.order_id),
  round(sum(f.pay_amount), 2),
  count(distinct f.user_id),
  round(sum(f.pay_amount) / count(distinct f.order_id), 2)
from ydsh_dwd.fact_order f
join ydsh_dwd.dim_channel c on f.channel_code = c.channel_code
where f.amount_invalid = 0
group by f.order_month, f.channel_code, c.channel_name;

-- ========== 5. 月 × 品类（需经订单明细） ==========
drop table if exists ydsh_dws.dws_category_month;
create table ydsh_dws.dws_category_month (
  stat_month   string,
  category     string,
  order_cnt    bigint,
  qty          bigint,
  sales        decimal(18,2),
  sales_ratio  decimal(6,4)  comment '占当月销售额比重'
) comment '月 × 品类销售汇总'
stored as orc;

insert overwrite table ydsh_dws.dws_category_month
select
  substr(f.order_timestamp, 1, 7)      as stat_month,
  p.category,
  count(distinct oi.order_id)           as order_cnt,
  sum(oi.quantity)                      as qty,
  round(sum(oi.item_amount), 2)         as sales,
  round(sum(oi.item_amount) / sum(sum(oi.item_amount)) over (partition by substr(f.order_timestamp, 1, 7)), 4) as sales_ratio
from ydsh_dwd.fact_order_item oi
join ydsh_dwd.fact_order f  on oi.order_id = f.order_id
join ydsh_dwd.dim_product p on oi.product_id = p.product_id
where oi.qty_invalid = 0
group by substr(f.order_timestamp, 1, 7), p.category;

-- ---------- 校验 ----------
select 'dws_sales_day' as tbl, count(*) as cnt from ydsh_dws.dws_sales_day
union all select 'dws_sales_month', count(*) from ydsh_dws.dws_sales_month
union all select 'dws_store_month', count(*) from ydsh_dws.dws_store_month
union all select 'dws_channel_month', count(*) from ydsh_dws.dws_channel_month
union all select 'dws_category_month', count(*) from ydsh_dws.dws_category_month;
