-- 第 2 周 · 子任务 6：订单事实表（星型模型核心，分区表）
-- 处理：去重、日期/时间标准化与合并、枚举编码化、异常金额标记
-- 分区：order_month（按月，2024-01 ... 2024-12）
-- 用法：beeline -u jdbc:hive2://localhost:10000/ -f /sql/dwd/14_fact_order.sql

set hive.exec.dynamic.partition=true;
set hive.exec.dynamic.partition.mode=nonstrict;
-- 按天分区 = 366 个分区，超过默认的每节点 100 个上限，必须调高
set hive.exec.max.dynamic.partitions=10000;
set hive.exec.max.dynamic.partitions.pernode=10000;
set hive.exec.max.created.files=200000;

-- ---------- 中间表：清洗 + 去重 ----------
create table if not exists ydsh_dwd.tmp_order_clean (
  order_id         string,
  user_id          string,
  store_id         string,
  order_timestamp  string,
  pay_amount       decimal(12,2),
  discount_amount  decimal(12,2),
  pay_code         string,
  status_code      string,
  channel_code     string,
  amount_invalid   tinyint,
  order_date       string
) stored as orc;

insert overwrite table ydsh_dwd.tmp_order_clean
select
  order_id,
  user_id,
  store_id,
  order_timestamp,
  case when pay_amount < 0 or pay_amount > 100000 then null else pay_amount end as pay_amount,
  case when discount_amount < 0 then 0 else discount_amount end                       as discount_amount,
  coalesce(pay_code, 'PT0')      as pay_code,
  coalesce(status_code, 'ST0')   as status_code,
  coalesce(channel_code, 'CH0')  as channel_code,
  cast(case when pay_amount < 0 or pay_amount > 100000 then 1 else 0 end as tinyint)   as amount_invalid,
  order_date
from (
  select
    t.order_id, t.user_id, t.store_id,
    concat(t.order_date, ' ', t.order_time) as order_timestamp,
    t.pay_amount, t.discount_amount,
    p.pay_code, s.status_code, c.channel_code,
    t.order_date,
    row_number() over (partition by t.order_id order by concat(t.order_date, ' ', t.order_time) desc) as rn
  from (
    select
      order_id, user_id, store_id, order_time, pay_amount, discount_amount,
      -- 日期统一 yyyy-MM-dd
      case when order_date rlike '^[0-9]{4}/[0-9]{1,2}/[0-9]{1,2}$' then regexp_replace(order_date, '/', '-')
           when order_date rlike '^[0-9]{8}$'
                then concat(substr(order_date,1,4), '-', substr(order_date,5,2), '-', substr(order_date,7,2))
           else order_date end as order_date,
      pay_type, order_status, channel
    from ydsh_ods.ods_order
  ) t
  left join ydsh_dwd.map_pay_type     p on t.pay_type     = p.raw_value
  left join ydsh_dwd.map_order_status s on t.order_status = s.raw_value
  left join ydsh_dwd.map_channel      c on t.channel      = c.raw_value
) x
where rn = 1;

select count(*) as clean_cnt from ydsh_dwd.tmp_order_clean;

-- ---------- 分区事实表 ----------
drop table if exists ydsh_dwd.fact_order;

create table if not exists ydsh_dwd.fact_order (
  order_id         string         comment '订单ID',
  user_id          string         comment '用户ID -> dim_user',
  store_id         string         comment '门店ID -> dim_store',
  order_timestamp  string         comment '下单时间戳 yyyy-MM-dd HH:mm:ss',
  pay_amount       decimal(12,2)  comment '实付金额（异常已置空）',
  discount_amount  decimal(12,2)  comment '优惠金额',
  pay_code         string         comment '支付方式编码 -> dim_pay_type',
  status_code      string         comment '订单状态编码 -> dim_order_status',
  channel_code     string         comment '渠道编码 -> dim_channel',
  amount_invalid   tinyint        comment '1=原始金额异常（负值或超10万）'
) comment '订单事实表'
partitioned by (order_month string comment '下单月份 yyyy-MM')
stored as orc;

insert overwrite table ydsh_dwd.fact_order partition (order_month)
select
  order_id, user_id, store_id, order_timestamp,
  pay_amount, discount_amount,
  pay_code, status_code, channel_code, amount_invalid,
  substr(order_date, 1, 7) as order_month
from ydsh_dwd.tmp_order_clean;

-- ---------- 校验 ----------
select count(*) as total, count(distinct order_id) as orders, count(distinct order_month) as months
from ydsh_dwd.fact_order;

select sum(case when amount_invalid = 1 then 1 else 0 end) as invalid_amt,
       sum(case when order_timestamp not rlike '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$' then 1 else 0 end) as ts_bad
from ydsh_dwd.fact_order;

select 'pay_code' as field, count(distinct pay_code) as distinct_cnt from ydsh_dwd.fact_order
union all select 'status_code', count(distinct status_code) from ydsh_dwd.fact_order
union all select 'channel_code', count(distinct channel_code) from ydsh_dwd.fact_order;

show partitions ydsh_dwd.fact_order;
