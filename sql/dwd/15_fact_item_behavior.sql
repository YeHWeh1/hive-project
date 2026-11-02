-- 第 2 周 · 订单明细事实表 + 用户行为事实表
-- 明细表尝试分桶（按 order_id 分 8 桶），行为表按月分区
-- 用法：beeline -u jdbc:hive2://localhost:10000/ -f /sql/dwd/15_fact_item_behavior.sql

-- ========== 订单明细事实表（分桶） ==========
set hive.enforce.bucketing = true;

create table if not exists ydsh_dwd.fact_order_item (
  item_id      string         comment '明细ID',
  order_id     string         comment '订单ID -> fact_order',
  product_id   string         comment '商品ID -> dim_product',
  quantity     int            comment '数量（<=0 视为异常）',
  unit_price   decimal(12,2)  comment '单价',
  discount     decimal(5,2)   comment '折扣（0~1）',
  item_amount  decimal(14,2)  comment '明细金额 = 数量*单价*(1-折扣)',
  qty_invalid  tinyint        comment '1=数量异常'
) comment '订单明细事实表（按 order_id 分桶）'
clustered by (order_id) into 8 buckets
stored as orc;

insert overwrite table ydsh_dwd.fact_order_item
select
  item_id, order_id, product_id,
  quantity, unit_price,
  case when discount < 0 or discount > 1 then 0 else discount end as discount,
  case when quantity <= 0 then null
       else cast(round(quantity * unit_price * (1 - case when discount < 0 or discount > 1 then 0 else discount end), 2) as decimal(14,2))
  end as item_amount,
  cast(case when quantity <= 0 then 1 else 0 end as tinyint) as qty_invalid
from ydsh_ods.ods_order_item;

select count(*) as total,
       sum(case when qty_invalid = 1 then 1 else 0 end) as qty_invalid_cnt,
       sum(case when item_amount is null then 1 else 0 end) as amount_null
from ydsh_dwd.fact_order_item;

-- ========== 用户行为事实表（按天分区） ==========
set hive.exec.dynamic.partition = true;
set hive.exec.dynamic.partition.mode = nonstrict;

create table if not exists ydsh_dwd.fact_behavior (
  behavior_id    string comment '行为ID',
  user_id        string comment '用户ID',
  product_id     string comment '商品ID',
  behavior_code  string comment '行为编码 -> dim_behavior_type',
  behavior_time  string comment '行为时间 yyyy-MM-dd HH:mm:ss',
  session_id     string comment '会话ID'
) comment '用户行为事实表'
partitioned by (behavior_month string comment '行为月份 yyyy-MM')
stored as orc;

insert overwrite table ydsh_dwd.fact_behavior partition (behavior_month)
select
  b.behavior_id,
  b.user_id,
  b.product_id,
  coalesce(m.behavior_code, 'BT0') as behavior_code,
  b.btime as behavior_time,
  b.session_id,
  substr(b.btime, 1, 7) as behavior_month
from (
  select
    behavior_id, user_id, product_id, behavior_type, session_id,
    case when length(regexp_replace(behavior_time, '/', '-')) = 16
         then concat(regexp_replace(behavior_time, '/', '-'), ':00')
         else regexp_replace(behavior_time, '/', '-') end as btime
  from ydsh_ods.ods_user_behavior
) b
left join ydsh_dwd.map_behavior_type m on b.behavior_type = m.raw_value;

select count(*) as total, count(distinct behavior_month) as months,
       sum(case when behavior_time not rlike '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$' then 1 else 0 end) as ts_bad
from ydsh_dwd.fact_behavior;

select d.behavior_name, count(*) as cnt
from ydsh_dwd.fact_behavior f join ydsh_dwd.dim_behavior_type d on f.behavior_code = d.behavior_code
group by d.behavior_name order by cnt desc;
