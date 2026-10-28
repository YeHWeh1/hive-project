-- 用户维度表（ods_user）
create table if not exists ydsh_ods.ods_user (
  user_id        string           comment '用户ID',
  user_name      string           comment '用户姓名',
  gender         string           comment '性别',
  age            int              comment '年龄',
  city           string           comment '城市',
  province       string           comment '省份',
  register_date  string           comment '注册日期',
  member_level   string           comment '会员等级',
  phone          string           comment '手机号',
  email          string           comment '邮箱'
) comment '用户维度表'
row format delimited fields terminated by ','
stored as textfile
tblproperties('skip.header.line.count'='1');
