-- 用户行为表（ods_user_behavior）
create table if not exists ydsh_ods.ods_user_behavior (
  behavior_id    string           comment '行为ID',
  user_id        string           comment '用户ID',
  product_id     string           comment '商品ID',
  behavior_type  string           comment '行为类型',
  behavior_time  string           comment '行为时间',
  session_id     string           comment '会话ID'
) comment '用户行为表'
row format delimited fields terminated by ','
stored as textfile
tblproperties('skip.header.line.count'='1');
