-- 数据质量五维度预评估（步骤 7）
-- ① 完整性（空值）  ② 唯一性（主键重复）  ③ 有效性（取值分布）


-- ========== ods_user 用户维度表 ==========
-- ① 完整性 + ② 唯一性
select count(*) as total,
       sum(case when user_id is null or user_id = '' then 1 else 0 end) as user_id_null,
       sum(case when user_name is null or user_name = '' then 1 else 0 end) as user_name_null,
       sum(case when gender is null or gender = '' then 1 else 0 end) as gender_null,
       sum(case when city is null or city = '' then 1 else 0 end) as city_null,
       sum(case when province is null or province = '' then 1 else 0 end) as province_null,
       sum(case when register_date is null or register_date = '' then 1 else 0 end) as register_date_null,
       sum(case when member_level is null or member_level = '' then 1 else 0 end) as member_level_null,
       sum(case when phone is null or phone = '' then 1 else 0 end) as phone_null,
       sum(case when email is null or email = '' then 1 else 0 end) as email_null,
       sum(case when age is null then 1 else 0 end) as age_null
from ydsh_ods.ods_user;
select count(*) as total, count(distinct user_id) as distinct_pk,
       count(*) - count(distinct user_id) as dup_cnt
from ydsh_ods.ods_user;

-- ========== ods_product 商品维度表 ==========
-- ① 完整性 + ② 唯一性
select count(*) as total,
       sum(case when product_id is null or product_id = '' then 1 else 0 end) as product_id_null,
       sum(case when product_name is null or product_name = '' then 1 else 0 end) as product_name_null,
       sum(case when category is null or category = '' then 1 else 0 end) as category_null,
       sum(case when sub_category is null or sub_category = '' then 1 else 0 end) as sub_category_null,
       sum(case when brand is null or brand = '' then 1 else 0 end) as brand_null,
       sum(case when status is null or status = '' then 1 else 0 end) as status_null,
       sum(case when launch_date is null or launch_date = '' then 1 else 0 end) as launch_date_null,
       sum(case when price is null then 1 else 0 end) as price_null, sum(case when cost is null then 1 else 0 end) as cost_null, sum(case when stock is null then 1 else 0 end) as stock_null
from ydsh_ods.ods_product;
select count(*) as total, count(distinct product_id) as distinct_pk,
       count(*) - count(distinct product_id) as dup_cnt
from ydsh_ods.ods_product;

-- ========== ods_store 门店维度表 ==========
-- ① 完整性 + ② 唯一性
select count(*) as total,
       sum(case when store_id is null or store_id = '' then 1 else 0 end) as store_id_null,
       sum(case when store_name is null or store_name = '' then 1 else 0 end) as store_name_null,
       sum(case when province is null or province = '' then 1 else 0 end) as province_null,
       sum(case when city is null or city = '' then 1 else 0 end) as city_null,
       sum(case when district is null or district = '' then 1 else 0 end) as district_null,
       sum(case when address is null or address = '' then 1 else 0 end) as address_null,
       sum(case when open_date is null or open_date = '' then 1 else 0 end) as open_date_null,
       sum(case when manager is null or manager = '' then 1 else 0 end) as manager_null,
       sum(case when area is null then 1 else 0 end) as area_null
from ydsh_ods.ods_store;
select count(*) as total, count(distinct store_id) as distinct_pk,
       count(*) - count(distinct store_id) as dup_cnt
from ydsh_ods.ods_store;

-- ========== ods_order 订单事实表 ==========
-- ① 完整性 + ② 唯一性
select count(*) as total,
       sum(case when order_id is null or order_id = '' then 1 else 0 end) as order_id_null,
       sum(case when user_id is null or user_id = '' then 1 else 0 end) as user_id_null,
       sum(case when store_id is null or store_id = '' then 1 else 0 end) as store_id_null,
       sum(case when order_date is null or order_date = '' then 1 else 0 end) as order_date_null,
       sum(case when order_time is null or order_time = '' then 1 else 0 end) as order_time_null,
       sum(case when pay_type is null or pay_type = '' then 1 else 0 end) as pay_type_null,
       sum(case when order_status is null or order_status = '' then 1 else 0 end) as order_status_null,
       sum(case when channel is null or channel = '' then 1 else 0 end) as channel_null,
       sum(case when pay_amount is null then 1 else 0 end) as pay_amount_null, sum(case when discount_amount is null then 1 else 0 end) as discount_amount_null
from ydsh_ods.ods_order;
select count(*) as total, count(distinct order_id) as distinct_pk,
       count(*) - count(distinct order_id) as dup_cnt
from ydsh_ods.ods_order;

-- ========== ods_order_item 订单明细表 ==========
-- ① 完整性 + ② 唯一性
select count(*) as total,
       sum(case when item_id is null or item_id = '' then 1 else 0 end) as item_id_null,
       sum(case when order_id is null or order_id = '' then 1 else 0 end) as order_id_null,
       sum(case when product_id is null or product_id = '' then 1 else 0 end) as product_id_null,
       sum(case when quantity is null then 1 else 0 end) as quantity_null, sum(case when unit_price is null then 1 else 0 end) as unit_price_null, sum(case when discount is null then 1 else 0 end) as discount_null
from ydsh_ods.ods_order_item;
select count(*) as total, count(distinct item_id) as distinct_pk,
       count(*) - count(distinct item_id) as dup_cnt
from ydsh_ods.ods_order_item;

-- ========== ods_user_behavior 用户行为表 ==========
-- ① 完整性 + ② 唯一性
select count(*) as total,
       sum(case when behavior_id is null or behavior_id = '' then 1 else 0 end) as behavior_id_null,
       sum(case when user_id is null or user_id = '' then 1 else 0 end) as user_id_null,
       sum(case when product_id is null or product_id = '' then 1 else 0 end) as product_id_null,
       sum(case when behavior_type is null or behavior_type = '' then 1 else 0 end) as behavior_type_null,
       sum(case when behavior_time is null or behavior_time = '' then 1 else 0 end) as behavior_time_null,
       sum(case when session_id is null or session_id = '' then 1 else 0 end) as session_id_null,
       
from ydsh_ods.ods_user_behavior;
select count(*) as total, count(distinct behavior_id) as distinct_pk,
       count(*) - count(distinct behavior_id) as dup_cnt
from ydsh_ods.ods_user_behavior;

-- ========== ③ 有效性：枚举值分布 ==========
select 'ods_user' as tbl, 'gender' as col, gender, count(*) as cnt
from ydsh_ods.ods_user group by gender order by cnt desc;
select 'ods_user' as tbl, 'member_level' as col, member_level, count(*) as cnt
from ydsh_ods.ods_user group by member_level order by cnt desc;
select 'ods_product' as tbl, 'status' as col, status, count(*) as cnt
from ydsh_ods.ods_product group by status order by cnt desc;
select 'ods_store' as tbl, 'province' as col, province, count(*) as cnt
from ydsh_ods.ods_store group by province order by cnt desc;
select 'ods_order' as tbl, 'pay_type' as col, pay_type, count(*) as cnt
from ydsh_ods.ods_order group by pay_type order by cnt desc;
select 'ods_order' as tbl, 'order_status' as col, order_status, count(*) as cnt
from ydsh_ods.ods_order group by order_status order by cnt desc;
select 'ods_order' as tbl, 'channel' as col, channel, count(*) as cnt
from ydsh_ods.ods_order group by channel order by cnt desc;
select 'ods_user_behavior' as tbl, 'behavior_type' as col, behavior_type, count(*) as cnt
from ydsh_ods.ods_user_behavior group by behavior_type order by cnt desc;

-- ========== ③ 有效性：数值区间 ==========
select 'ods_user' as tbl, 'age' as col, min(age) as min_v, max(age) as max_v,
       sum(case when age is null then 1 else 0 end) as null_cnt
from ydsh_ods.ods_user;
select 'ods_product' as tbl, 'price' as col, min(price) as min_v, max(price) as max_v,
       sum(case when price is null then 1 else 0 end) as null_cnt
from ydsh_ods.ods_product;
select 'ods_product' as tbl, 'stock' as col, min(stock) as min_v, max(stock) as max_v,
       sum(case when stock is null then 1 else 0 end) as null_cnt
from ydsh_ods.ods_product;
select 'ods_order' as tbl, 'pay_amount' as col, min(pay_amount) as min_v, max(pay_amount) as max_v,
       sum(case when pay_amount is null then 1 else 0 end) as null_cnt
from ydsh_ods.ods_order;
select 'ods_order_item' as tbl, 'quantity' as col, min(quantity) as min_v, max(quantity) as max_v,
       sum(case when quantity is null then 1 else 0 end) as null_cnt
from ydsh_ods.ods_order_item;
select 'ods_order_item' as tbl, 'unit_price' as col, min(unit_price) as min_v, max(unit_price) as max_v,
       sum(case when unit_price is null then 1 else 0 end) as null_cnt
from ydsh_ods.ods_order_item;
