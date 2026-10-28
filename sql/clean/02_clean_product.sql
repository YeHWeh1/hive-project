-- 步骤 8-2：商品表缺失值处理
--   launch_date 缺失（11 条）→ 补占位日期 1970-01-01，并加标记列
-- 用法：beeline -u jdbc:hive2://localhost:10000/ -f /sql/clean/02_clean_product.sql

create table if not exists ydsh_dwd.dwd_product (
  product_id              string         comment '商品ID',
  product_name            string         comment '商品名称',
  category                string         comment '一级品类',
  sub_category            string         comment '二级品类',
  brand                   string         comment '品牌',
  price                   decimal(12,2)  comment '售价',
  cost                    decimal(12,2)  comment '成本',
  stock                   int            comment '库存',
  status                  string         comment '商品状态',
  launch_date             string         comment '上架日期（已补全）',
  launch_date_is_missing  tinyint        comment '1=原始缺失'
) comment '商品维度表（清洗后）'
stored as textfile;

insert overwrite table ydsh_dwd.dwd_product
select
  product_id, product_name, category, sub_category, brand,
  price, cost, stock, status,
  case when launch_date is null or trim(launch_date) = '' then '1970-01-01' else launch_date end as launch_date,
  case when launch_date is null or trim(launch_date) = '' then 1 else 0 end as launch_date_is_missing
from ydsh_ods.ods_product;

-- 校验：应为 600 / 0 / 11
select count(*) as total,
       sum(case when launch_date is null or launch_date = '' then 1 else 0 end) as launch_date_null,
       sum(case when launch_date_is_missing = 1 then 1 else 0 end) as filled_cnt
from ydsh_dwd.dwd_product;
