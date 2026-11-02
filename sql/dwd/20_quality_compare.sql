-- 第 2 周 · 子任务 4：数据质量对比（清洗前 ODS vs 清洗后 DWD）
-- 用法：beeline -u jdbc:hive2://localhost:10000/ -f /sql/dwd/20_quality_compare.sql
-- 说明：每条指标一个独立 SELECT，避免单 DAG 内 union 分支过多触发 Tez 计数器上限（120）
-- 修复率 = (清洗前 - 清洗后) / 清洗前

-- 1 年龄缺失或越界
select '1 年龄缺失或越界' as metric, (select count(*) from ydsh_ods.ods_user where age is null or age < 1 or age > 120) as before_cnt, (select count(*) from ydsh_dwd.dim_user where age is null or age < 1 or age > 120) as after_cnt;

-- 2 订单主键重复
select '2 订单主键重复' as metric, (select count(*) - count(distinct order_id) from ydsh_ods.ods_order) as before_cnt, (select count(*) - count(distinct order_id) from ydsh_dwd.fact_order) as after_cnt;

-- 3 金额为负
select '3 金额为负' as metric, (select count(*) from ydsh_ods.ods_order where pay_amount < 0) as before_cnt, (select count(*) from ydsh_dwd.fact_order where pay_amount < 0) as after_cnt;

-- 4 金额极端值(>10万)
select '4 金额极端值(>10万)' as metric, (select count(*) from ydsh_ods.ods_order where pay_amount > 100000) as before_cnt, (select count(*) from ydsh_dwd.fact_order where pay_amount > 100000) as after_cnt;

-- 5 数量为0或负数
select '5 数量为0或负数' as metric, (select count(*) from ydsh_ods.ods_order_item where quantity <= 0) as before_cnt, (select count(*) from ydsh_dwd.fact_order_item where quantity <= 0) as after_cnt;

-- 6 性别不规范取值
select '6 性别不规范取值' as metric, (select count(*) from ydsh_ods.ods_user where gender not in ('男','女')) as before_cnt, (select count(*) from ydsh_dwd.dim_user where gender_code = 'G0') as after_cnt;

-- 7 会员等级不规范取值
select '7 会员等级不规范取值' as metric, (select count(*) from ydsh_ods.ods_user where member_level not in ('金卡会员','银卡会员','钻石会员','普通会员')) as before_cnt, (select count(*) from ydsh_dwd.dim_user where member_level_code is null) as after_cnt;

-- 8 订单状态不规范取值
select '8 订单状态不规范取值' as metric, (select count(*) from ydsh_ods.ods_order where order_status not in ('待支付','已支付','已完成','已取消','退款中')) as before_cnt, (select count(*) from ydsh_dwd.fact_order where status_code = 'ST0') as after_cnt;

-- 9 支付方式不规范取值
select '9 支付方式不规范取值' as metric, (select count(*) from ydsh_ods.ods_order where pay_type not in ('支付宝','微信支付','银行卡','货到付款')) as before_cnt, (select count(*) from ydsh_dwd.fact_order where pay_code = 'PT0') as after_cnt;

-- 10 下单渠道不规范取值
select '10 下单渠道不规范取值' as metric, (select count(*) from ydsh_ods.ods_order where channel not in ('门店','APP','小程序','PC官网')) as before_cnt, (select count(*) from ydsh_dwd.fact_order where channel_code = 'CH0') as after_cnt;

-- 11 行为类型不规范取值
select '11 行为类型不规范取值' as metric, (select count(*) from ydsh_ods.ods_user_behavior where behavior_type not in ('pv','buy','cart','fav')) as before_cnt, (select count(*) from ydsh_dwd.fact_behavior where behavior_code = 'BT0') as after_cnt;

-- 12 注册日期格式非法
select '12 注册日期格式非法' as metric, (select count(*) from ydsh_ods.ods_user where register_date not rlike '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') as before_cnt, (select count(*) from ydsh_dwd.dim_user where register_date not rlike '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') as after_cnt;

-- 13 下单日期格式非法
select '13 下单日期格式非法' as metric, (select count(*) from ydsh_ods.ods_order where order_date not rlike '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') as before_cnt, (select count(*) from ydsh_dwd.fact_order where substr(order_timestamp,1,10) not rlike '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') as after_cnt;

-- 14 行为时间格式非法
select '14 行为时间格式非法' as metric, (select count(*) from ydsh_ods.ods_user_behavior where behavior_time not rlike '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$') as before_cnt, (select count(*) from ydsh_dwd.fact_behavior where behavior_time not rlike '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$') as after_cnt;

-- 15 手机号非11位
select '15 手机号非11位' as metric, (select count(*) from ydsh_ods.ods_user where phone not rlike '^[0-9]{11}$') as before_cnt, (select count(*) from ydsh_dwd.dim_user where phone not rlike '^[0-9]{11}$') as after_cnt;

-- 16 品类含首尾空格
select '16 品类含首尾空格' as metric, (select count(*) from ydsh_ods.ods_product where category <> trim(category)) as before_cnt, (select count(*) from ydsh_dwd.dim_product where category <> trim(category)) as after_cnt;

-- ===== 枚举取值个数收敛（清洗前 / 清洗后） =====
select 'gender' as field, (select count(distinct gender) from ydsh_ods.ods_user) as before_distinct, (select count(distinct gender_code) from ydsh_dwd.dim_user) as after_distinct;
select 'member_level' as field, (select count(distinct member_level) from ydsh_ods.ods_user) as before_distinct, (select count(distinct member_level_code) from ydsh_dwd.dim_user) as after_distinct;
select 'order_status' as field, (select count(distinct order_status) from ydsh_ods.ods_order) as before_distinct, (select count(distinct status_code) from ydsh_dwd.fact_order) as after_distinct;
select 'pay_type' as field, (select count(distinct pay_type) from ydsh_ods.ods_order) as before_distinct, (select count(distinct pay_code) from ydsh_dwd.fact_order) as after_distinct;
select 'channel' as field, (select count(distinct channel) from ydsh_ods.ods_order) as before_distinct, (select count(distinct channel_code) from ydsh_dwd.fact_order) as after_distinct;
select 'behavior_type' as field, (select count(distinct behavior_type) from ydsh_ods.ods_user_behavior) as before_distinct, (select count(distinct behavior_code) from ydsh_dwd.fact_behavior) as after_distinct;
