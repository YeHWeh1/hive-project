-- 第 2 周 · 门店维度表 + 日期维度表
-- 用法：beeline -u jdbc:hive2://localhost:10000/ -f /sql/clean/13_dim_store_date.sql

-- ========== 门店维度 ==========
create table if not exists ydsh_dwd.dim_store (
  store_id    string comment '门店ID',
  store_name  string comment '门店名称',
  province    string comment '省份',
  city        string comment '城市',
  district    string comment '区县',
  address     string comment '详细地址',
  open_date   string comment '开业日期 yyyy-MM-dd',
  area        int    comment '面积(平米)',
  manager     string comment '店长'
) comment '门店维度表（清洗后）'
stored as orc;

insert overwrite table ydsh_dwd.dim_store
select
  s.store_id,
  trim(s.store_name),
  trim(s.province),
  trim(s.city),
  trim(s.district),
  trim(s.address),
  case when s.open_date rlike '^[0-9]{4}/[0-9]{1,2}/[0-9]{1,2}$' then regexp_replace(s.open_date, '/', '-')
       when s.open_date rlike '^[0-9]{8}$'
            then concat(substr(s.open_date,1,4), '-', substr(s.open_date,5,2), '-', substr(s.open_date,7,2))
       else s.open_date end as open_date,
  s.area,
  trim(s.manager)
from ydsh_ods.ods_store s;

select count(*) as total, count(distinct store_id) as stores from ydsh_dwd.dim_store;
select sum(case when open_date not rlike '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then 1 else 0 end) as date_bad from ydsh_dwd.dim_store;

-- ========== 日期维度 ==========
-- 覆盖 2023-01-01 ~ 2025-12-31（共 1096 天），供事实表按日期关联
create table if not exists ydsh_dwd.dim_date (
  date_key      string comment '日期 yyyy-MM-dd',
  year_no       int,
  month_no      int,
  day_no        int,
  weekday_name  string,
  week_of_year  int,
  quarter_no    int,
  is_weekend    tinyint
) comment '日期维度表'
stored as orc;

insert overwrite table ydsh_dwd.dim_date
select
  date_format(d, 'yyyy-MM-dd')          as date_key,
  year(d)                               as year_no,
  month(d)                              as month_no,
  day(d)                                as day_no,
  date_format(d, 'EEEE')                as weekday_name,
  weekofyear(d)                         as week_of_year,
  quarter(d)                            as quarter_no,
  cast(case when dayofweek(d) in (1, 7) then 1 else 0 end as tinyint) as is_weekend
from (
  select date_add(to_date('2023-01-01'), p.pos) as d
  from (select posexplode(split(repeat(' ', 1095), ' ')) as (pos, val)) p
) t;

select count(*) as days, min(date_key) as min_d, max(date_key) as max_d from ydsh_dwd.dim_date;
