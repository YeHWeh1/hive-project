-- 第 3 周 · 子任务 1：ADS 应用层 + 核心 KPI
-- 面向业务场景的输出表：总览 KPI、销售日报、品类 TopN、门店排行、用户价值分层
-- 用法：beeline -u jdbc:hive2://localhost:10000/ -f /sql/ads/02_ads_kpi.sql

create database if not exists ydsh_ads;

-- ========== 1. 核心 KPI 总览（单行） ==========
drop table if exists ydsh_ads.ads_kpi_overview;
create table ydsh_ads.ads_kpi_overview (
  kpi_name    string         comment '指标名',
  kpi_value   decimal(18,2)  comment '指标值',
  kpi_unit    string         comment '单位',
  definition  string         comment '口径说明'
) comment '核心 KPI 总览'
stored as orc;

insert overwrite table ydsh_ads.ads_kpi_overview
select 'GMV' as kpi_name, round(sum(pay_amount), 2) as kpi_value, '元' as kpi_unit,
       '有效订单实付金额之和（排除金额异常订单）' as definition
from ydsh_dwd.fact_order where amount_invalid = 0
union all
select '订单量', count(distinct order_id), '笔', '去重订单数（有效订单）'
from ydsh_dwd.fact_order where amount_invalid = 0
union all
select '客单价 AOV', round(sum(pay_amount) / count(distinct order_id), 2), '元', 'GMV ÷ 订单量'
from ydsh_dwd.fact_order where amount_invalid = 0
union all
select '活跃用户数', count(distinct user_id), '人', '有下单行为的去重用户数'
from ydsh_dwd.fact_order where amount_invalid = 0
union all
select '复购率',
       round(sum(case when oc >= 2 then 1 else 0 end) / count(*), 4) * 100,
       '%', '下单≥2次用户数 ÷ 下单用户数'
from (
  select user_id, count(distinct order_id) as oc
  from ydsh_dwd.fact_order where amount_invalid = 0
  group by user_id
) t;

-- 把复购率单独算一份精确值（避免 union 类型混用）
insert into table ydsh_ads.ads_kpi_overview
select '复购用户数', count(*), '人', '下单≥2次的用户数'
from (
  select user_id, count(distinct order_id) as oc
  from ydsh_dwd.fact_order where amount_invalid = 0
  group by user_id having count(distinct order_id) >= 2
) t;

-- ========== 2. 销售日报（含环比） ==========
drop table if exists ydsh_ads.ads_sales_daily;
create table ydsh_ads.ads_sales_daily (
  stat_date     string,
  order_cnt     bigint,
  gmv           decimal(18,2),
  aov           decimal(12,2),
  gmv_dod       decimal(8,4)  comment 'GMV 日环比',
  gmv_ma7       decimal(18,2) comment 'GMV 7 日移动平均'
) comment '销售日报'
stored as orc;

insert overwrite table ydsh_ads.ads_sales_daily
select
  stat_date, order_cnt, gmv, aov,
  round((gmv - lag(gmv) over (order by stat_date)) / lag(gmv) over (order by stat_date), 4) as gmv_dod,
  round(avg(gmv) over (order by stat_date rows between 6 preceding and current row), 2) as gmv_ma7
from ydsh_dws.dws_sales_day;

-- ========== 3. 品类销售 TopN（全期） ==========
drop table if exists ydsh_ads.ads_category_topn;
create table ydsh_ads.ads_category_topn (
  rk          int,
  category    string,
  order_cnt   bigint,
  qty         bigint,
  sales       decimal(18,2),
  sales_ratio decimal(6,4)
) comment '品类销售排行'
stored as orc;

insert overwrite table ydsh_ads.ads_category_topn
select
  row_number() over (order by sales desc) as rk,
  category, order_cnt, qty, sales,
  round(sales / sum(sales) over (), 4) as sales_ratio
from (
  select p.category,
         count(distinct oi.order_id)   as order_cnt,
         sum(oi.quantity)              as qty,
         round(sum(oi.item_amount), 2) as sales
  from ydsh_dwd.fact_order_item oi
  join ydsh_dwd.dim_product p on oi.product_id = p.product_id
  where oi.qty_invalid = 0
  group by p.category
) t;

-- ========== 4. 门店销售排行 TopN ==========
drop table if exists ydsh_ads.ads_store_topn;
create table ydsh_ads.ads_store_topn (
  rk         int,
  store_id   string,
  store_name string,
  province   string,
  city       string,
  order_cnt  bigint,
  gmv        decimal(18,2),
  aov        decimal(12,2)
) comment '门店销售排行'
stored as orc;

insert overwrite table ydsh_ads.ads_store_topn
select
  row_number() over (order by gmv desc) as rk,
  store_id, store_name, province, city, order_cnt, gmv, aov
from (
  select f.store_id,
         s.store_name, s.province, s.city,
         count(distinct f.order_id)             as order_cnt,
         round(sum(f.pay_amount), 2)            as gmv,
         round(sum(f.pay_amount) / count(distinct f.order_id), 2) as aov
  from ydsh_dwd.fact_order f
  join ydsh_dwd.dim_store s on f.store_id = s.store_id
  where f.amount_invalid = 0
  group by f.store_id, s.store_name, s.province, s.city
) t;

-- ========== 5. 用户价值分层（RFM 简化：金额分档） ==========
drop table if exists ydsh_ads.ads_user_value;
create table ydsh_ads.ads_user_value (
  user_id        string,
  total_amount   decimal(18,2) comment '累计消费',
  order_cnt      bigint,
  last_order     string        comment '最近下单日期',
  value_level    string        comment '价值分层'
) comment '用户价值分层'
stored as orc;

insert overwrite table ydsh_ads.ads_user_value
select
  user_id, total_amount, order_cnt, last_order,
  case when total_amount >= 50000 then 'A-高价值'
       when total_amount >= 30000 then 'B-中高价值'
       when total_amount >= 15000 then 'C-中等价值'
       else 'D-普通用户' end as value_level
from (
  select user_id,
         round(sum(pay_amount), 2)      as total_amount,
         count(distinct order_id)       as order_cnt,
         max(substr(order_timestamp,1,10)) as last_order
  from ydsh_dwd.fact_order
  where amount_invalid = 0
  group by user_id
) t;

-- ---------- 校验 ----------
select 'KPI' as section, kpi_name as item, kpi_value as val, kpi_unit as unit from ydsh_ads.ads_kpi_overview
order by case kpi_name when 'GMV' then 1 when '订单量' then 2 when '客单价 AOV' then 3
                      when '活跃用户数' then 4 when '复购用户数' then 5 when '复购率' then 6 else 9 end;

select 'ads_sales_daily' as tbl, count(*) as cnt from ydsh_ads.ads_sales_daily
union all select 'ads_category_topn', count(*) from ydsh_ads.ads_category_topn
union all select 'ads_store_topn', count(*) from ydsh_ads.ads_store_topn
union all select 'ads_user_value', count(*) from ydsh_ads.ads_user_value;

select value_level, count(*) as user_cnt, round(sum(total_amount),2) as gmv
from ydsh_ads.ads_user_value group by value_level order by value_level;
