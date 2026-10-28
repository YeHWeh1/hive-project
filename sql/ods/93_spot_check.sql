-- 关键质量问题抽查（与《数据质量预评估表》逐个对数字）
-- 用法：beeline -u jdbc:hive2://localhost:10000/ -f /sql/ods/93_spot_check.sql
-- 注意：一个 DAG 里 union 分支太多会触发 Tez "Too many counters: 121 max=120"，
--       所以这里调高上限，并拆成 3 组查询（每组不超过 6 个 union）。

set tez.counters.max=2000;
set tez.counters.max.groups=500;

-- ========== 第 1 组：用户表（6 项） ==========
select 'ods_user.gender 为空' as item, sum(case when gender is null or gender='' then 1 else 0 end) as cnt from ydsh_ods.ods_user
union all
select 'ods_user.age 为空', sum(case when age is null then 1 else 0 end) from ydsh_ods.ods_user
union all
select 'ods_user.age 越界(<1或>120)', sum(case when age < 1 or age > 120 then 1 else 0 end) from ydsh_ods.ods_user
union all
select 'ods_user.email 为空', sum(case when email is null or email='' then 1 else 0 end) from ydsh_ods.ods_user
union all
select 'ods_user.member_level 为空', sum(case when member_level is null or member_level='' then 1 else 0 end) from ydsh_ods.ods_user
union all
select 'ods_user.gender 中英文混用', sum(case when gender in ('male','M','female','F','未知') then 1 else 0 end) from ydsh_ods.ods_user;

-- ========== 第 2 组：商品表 + 订单表（6 项） ==========
select 'ods_product.launch_date 为空' as item, sum(case when launch_date is null or launch_date='' then 1 else 0 end) as cnt from ydsh_ods.ods_product
union all
select 'ods_order.order_id 重复条次', count(*) - count(distinct order_id) from ydsh_ods.ods_order
union all
select 'ods_order.pay_amount < 0', sum(case when pay_amount < 0 then 1 else 0 end) from ydsh_ods.ods_order
union all
select 'ods_order.pay_amount > 100000', sum(case when pay_amount > 100000 then 1 else 0 end) from ydsh_ods.ods_order
union all
select 'ods_order.pay_type 英文写法', sum(case when pay_type in ('wechat','alipay') then 1 else 0 end) from ydsh_ods.ods_order
union all
select 'ods_order.channel 小写写法', sum(case when channel in ('app','pc') then 1 else 0 end) from ydsh_ods.ods_order;

-- ========== 第 3 组：明细表 + 行为表（3 项） ==========
select 'ods_order_item.quantity <= 0' as item, sum(case when quantity <= 0 then 1 else 0 end) as cnt from ydsh_ods.ods_order_item
union all
select 'ods_order_item.quantity = 99', sum(case when quantity = 99 then 1 else 0 end) from ydsh_ods.ods_order_item
union all
select 'ods_user_behavior.behavior_type 非规范写法', sum(case when behavior_type not in ('pv','buy','cart','fav') then 1 else 0 end) from ydsh_ods.ods_user_behavior;
