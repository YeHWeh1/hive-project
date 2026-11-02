-- 第 2 周 · 子任务 1+2：商品维度表
-- 来源：ydsh_ods.ods_product → ydsh_dwd.dim_product
-- 用法：beeline -u jdbc:hive2://localhost:10000/ -f /sql/dwd/12_dim_product.sql

create table if not exists ydsh_dwd.dim_product (
  product_id              string         comment '商品ID',
  product_name            string         comment '商品名称（已去首尾空格）',
  category                string         comment '一级品类',
  sub_category            string         comment '二级品类',
  brand                   string         comment '品牌',
  price                   decimal(12,2)  comment '售价',
  cost                    decimal(12,2)  comment '成本',
  stock                   int            comment '库存',
  status_code             string         comment '状态编码 -> dim_product_status',
  launch_date             string         comment '上架日期 yyyy-MM-dd（已补全）',
  launch_date_is_missing  tinyint        comment '1=原始缺失'
) comment '商品维度表（清洗后）'
stored as orc;

insert overwrite table ydsh_dwd.dim_product
select
  p.product_id,
  trim(p.product_name)   as product_name,
  trim(p.category)       as category,
  trim(p.sub_category)   as sub_category,
  trim(p.brand)          as brand,
  p.price,
  p.cost,
  p.stock,
  coalesce(s.status_code, 'PS1') as status_code,
  case when p.launch_date is null or trim(p.launch_date) = '' then '1970-01-01'
       when p.launch_date rlike '^[0-9]{4}/[0-9]{1,2}/[0-9]{1,2}$' then regexp_replace(p.launch_date, '/', '-')
       when p.launch_date rlike '^[0-9]{8}$'
            then concat(substr(p.launch_date,1,4), '-', substr(p.launch_date,5,2), '-', substr(p.launch_date,7,2))
       else p.launch_date end as launch_date,
  cast(case when p.launch_date is null or trim(p.launch_date) = '' then 1 else 0 end as tinyint) as launch_date_is_missing
from ydsh_ods.ods_product p
left join ydsh_dwd.map_product_status s on p.status = s.raw_value;

-- 校验：600 行，3 个状态，日期格式全部合法
select count(*) as total, count(distinct product_id) as products from ydsh_dwd.dim_product;

select d.status_name, count(*) as cnt
from ydsh_dwd.dim_product p join ydsh_dwd.dim_product_status d on p.status_code = d.status_code
group by d.status_name;

select
  sum(case when launch_date not rlike '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then 1 else 0 end) as date_bad,
  sum(case when category <> trim(category) then 1 else 0 end) as space_left
from ydsh_dwd.dim_product;
