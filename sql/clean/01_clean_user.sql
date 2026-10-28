-- 步骤 8-1：用户表缺失值处理
--   age 为空或越界（<1 或 >120）→ 用合法值均值填充（实测 41.23，取整 41）
--   email 缺失 → 保留原值，另加标记列
-- 用法：beeline -u jdbc:hive2://localhost:10000/ -f /sql/clean/01_clean_user.sql

create database if not exists ydsh_dwd;

-- 先看一眼要用的均值（应输出 41.23 左右）
select round(avg(age), 2) as age_avg
from ydsh_ods.ods_user
where age is not null and age between 1 and 120;

create table if not exists ydsh_dwd.dwd_user (
  user_id           string   comment '用户ID',
  user_name         string   comment '用户姓名',
  gender            string   comment '性别（原样保留）',
  age               int      comment '年龄（已用均值填充）',
  city              string   comment '城市',
  province          string   comment '省份',
  register_date     string   comment '注册日期',
  member_level      string   comment '会员等级',
  phone             string   comment '手机号',
  email             string   comment '邮箱（原样保留）',
  email_is_missing  tinyint  comment '1=原始缺失'
) comment '用户维度表（清洗后）'
stored as textfile;

insert overwrite table ydsh_dwd.dwd_user
select
  user_id,
  user_name,
  gender,
  case when age is null or age < 1 or age > 120 then 41 else age end as age,
  city,
  province,
  register_date,
  member_level,
  phone,
  email,
  case when email is null or trim(email) = '' then 1 else 0 end as email_is_missing
from ydsh_ods.ods_user;

-- 校验：应为 1000 / 0 / 0 / 193
select count(*) as total,
       sum(case when age is null then 1 else 0 end) as age_null,
       sum(case when age < 1 or age > 120 then 1 else 0 end) as age_invalid,
       sum(case when email_is_missing = 1 then 1 else 0 end) as email_missing
from ydsh_dwd.dwd_user;
