-- 清洗结果总校验（步骤 8 + 步骤 9 一次看完）
-- 用法：beeline -u jdbc:hive2://localhost:10000/ -f /sql/clean/90_clean_check.sql

select 'dwd_user 行数'                as item, count(*) as val from ydsh_dwd.dwd_user
union all
select 'dwd_user.age 为空',            sum(case when age is null then 1 else 0 end) from ydsh_dwd.dwd_user
union all
select 'dwd_user.age 越界',            sum(case when age < 1 or age > 120 then 1 else 0 end) from ydsh_dwd.dwd_user
union all
select 'dwd_user 邮箱缺失标记数',       sum(case when email_is_missing = 1 then 1 else 0 end) from ydsh_dwd.dwd_user
union all
select 'dwd_product 行数',             count(*) from ydsh_dwd.dwd_product
union all
select 'dwd_product.launch_date 为空', sum(case when launch_date is null or launch_date = '' then 1 else 0 end) from ydsh_dwd.dwd_product
union all
select 'dwd_order 行数',               count(*) from ydsh_dwd.dwd_order
union all
select 'dwd_order 重复 order_id',      count(*) - count(distinct order_id) from ydsh_dwd.dwd_order;
