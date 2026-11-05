-- 第 2 周 · 子任务 1+2：用户维度表（枚举标准化 + 格式统一 + 缺失值）
-- 来源：ydsh_ods.ods_user（贴源层）→ ydsh_dwd.dim_user（明细层）
-- 用法：beeline -u jdbc:hive2://localhost:10000/ -f /sql/clean/11_dim_user.sql

drop table if exists ydsh_dwd.dim_user;

create table if not exists ydsh_dwd.dim_user (
  user_id             string    comment '用户ID',
  user_name           string    comment '姓名',
  gender_code         string    comment '性别编码 -> dim_gender',
  age                 int       comment '年龄（异常值已填充）',
  age_is_filled       tinyint   comment '1=原始缺失或越界，已填充',
  city                string    comment '城市',
  province            string    comment '省份',
  region              string    comment '省-市合并（子任务3）',
  register_date       string    comment '注册日期 yyyy-MM-dd',
  member_level_code   string    comment '会员等级编码 -> dim_member_level',
  phone               string    comment '手机号（11 位纯数字）',
  email               string    comment '邮箱（保留原值）',
  email_is_missing    tinyint   comment '1=原始缺失'
) comment '用户维度表（清洗后）'
stored as orc;

insert overwrite table ydsh_dwd.dim_user
select
  u.user_id,
  trim(u.user_name)                                            as user_name,
  coalesce(g.gender_code, 'G0')                                as gender_code,
  case when u.age is null or u.age < 1 or u.age > 120 then 41 else u.age end as age,
  cast(case when u.age is null or u.age < 1 or u.age > 120 then 1 else 0 end as tinyint) as age_is_filled,
  trim(u.city)                                                 as city,
  trim(u.province)                                             as province,
  -- 子任务 3：province + city 合并为 region
  concat_ws('-', trim(u.province), trim(u.city))               as region,
  -- 日期统一为 yyyy-MM-dd：兼容 yyyy-MM-dd / yyyy/MM/dd / yyyyMMdd
  case when u.register_date rlike '^[0-9]{4}/[0-9]{1,2}/[0-9]{1,2}$'
            then regexp_replace(u.register_date, '/', '-')
       when u.register_date rlike '^[0-9]{8}$'
            then concat(substr(u.register_date,1,4), '-', substr(u.register_date,5,2), '-', substr(u.register_date,7,2))
       else u.register_date end                               as register_date,
  coalesce(l.level_code, 'LV4')                                as member_level_code,
  -- 手机号去分隔符，只保留数字
  regexp_replace(u.phone, '[^0-9]', '')                        as phone,
  u.email,
  cast(case when u.email is null or trim(u.email) = '' then 1 else 0 end as tinyint) as email_is_missing
from ydsh_ods.ods_user u
left join ydsh_dwd.map_gender       g on u.gender       = g.raw_value
left join ydsh_dwd.map_member_level l on u.member_level = l.raw_value;

-- 校验 1：行数应为 1000
select count(*) as total, count(distinct user_id) as users from ydsh_dwd.dim_user;

-- 校验 2：枚举收敛情况（应与维表行数一致）
select 'gender'       as field, count(distinct gender_code)       as distinct_cnt from ydsh_dwd.dim_user
union all
select 'member_level',        count(distinct member_level_code)   from ydsh_dwd.dim_user;

-- 校验 3：格式统一（应全部为 0）
select
  sum(case when phone not rlike '^[0-9]{11}$' then 1 else 0 end)              as phone_bad,
  sum(case when register_date not rlike '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then 1 else 0 end) as date_bad,
  sum(case when age < 1 or age > 120 then 1 else 0 end)                       as age_bad
from ydsh_dwd.dim_user;

-- 校验 3.1：region 字段（应无 null，格式为 省-市）
select count(*) as total,
       sum(case when region is null or region = '' then 1 else 0 end) as region_null,
       sum(case when region not like '%-%' then 1 else 0 end)         as region_bad
from ydsh_dwd.dim_user;

select region, count(*) as cnt from ydsh_dwd.dim_user group by region order by cnt desc limit 5;

-- 校验 4：标准化后的实际分布
select d.gender_name, count(*) as cnt
from ydsh_dwd.dim_user u join ydsh_dwd.dim_gender d on u.gender_code = d.gender_code
group by d.gender_name order by cnt desc;

select l.level_name, l.sort_no, count(*) as cnt
from ydsh_dwd.dim_user u join ydsh_dwd.dim_member_level l on u.member_level_code = l.level_code
group by l.level_name, l.sort_no order by l.sort_no;
