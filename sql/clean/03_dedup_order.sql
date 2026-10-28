-- 步骤 9：订单去重
--   原则：同一 order_id 只保留 order_time 最新的一条（row_number() 窗口函数）
--   预期：15600 → 15000（去掉 600 条冗余）
-- 用法：beeline -u jdbc:hive2://localhost:10000/ -f /sql/clean/03_dedup_order.sql

create table if not exists ydsh_dwd.dwd_order (
  order_id         string         comment '订单ID',
  user_id          string         comment '用户ID',
  store_id         string         comment '门店ID',
  order_date       string         comment '下单日期',
  order_time       string         comment '下单时间',
  pay_amount       decimal(12,2)  comment '实付金额',
  discount_amount  decimal(12,2)  comment '优惠金额',
  pay_type         string         comment '支付方式',
  order_status     string         comment '订单状态',
  channel          string         comment '下单渠道'
) comment '订单事实表（去重后）'
stored as textfile;

insert overwrite table ydsh_dwd.dwd_order
select
  order_id, user_id, store_id, order_date, order_time,
  pay_amount, discount_amount, pay_type, order_status, channel
from (
  select *,
         row_number() over (partition by order_id order by order_time desc) as rn
  from ydsh_ods.ods_order
) t
where t.rn = 1;

-- 校验 1：去重后是否还有重复（应为 0）
select count(*) as total,
       count(distinct order_id) as distinct_order,
       count(*) - count(distinct order_id) as dup_cnt
from ydsh_dwd.dwd_order;

-- 校验 2：去重前后行数与差额（应为 15600 / 15000 / 600）
select
  (select count(*) from ydsh_ods.ods_order)  as ods_cnt,
  (select count(*) from ydsh_dwd.dwd_order)  as dwd_cnt,
  (select count(*) from ydsh_ods.ods_order) - (select count(*) from ydsh_dwd.dwd_order) as diff;
