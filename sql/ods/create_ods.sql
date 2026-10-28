-- ODS 层：建库 + 6 张贴源表
-- 用法：beeline -u jdbc:hive2://localhost:10000/ -f /sql/ods/create_ods.sql

create database if not exists ydsh_ods;

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

-- 商品维度表（ods_product）
create table if not exists ydsh_ods.ods_product (
  product_id     string           comment '商品ID',
  product_name   string           comment '商品名称',
  category       string           comment '一级品类',
  sub_category   string           comment '二级品类',
  brand          string           comment '品牌',
  price          decimal(12,2)    comment '售价',
  cost           decimal(12,2)    comment '成本',
  stock          int              comment '库存',
  status         string           comment '商品状态',
  launch_date    string           comment '上架日期'
) comment '商品维度表'
row format delimited fields terminated by ','
stored as textfile
tblproperties('skip.header.line.count'='1');

-- 门店维度表（ods_store）
create table if not exists ydsh_ods.ods_store (
  store_id       string           comment '门店ID',
  store_name     string           comment '门店名称',
  province       string           comment '省份',
  city           string           comment '城市',
  district       string           comment '区县',
  address        string           comment '详细地址',
  open_date      string           comment '开业日期',
  area           int              comment '面积(平米)',
  manager        string           comment '店长'
) comment '门店维度表'
row format delimited fields terminated by ','
stored as textfile
tblproperties('skip.header.line.count'='1');

-- 订单事实表（ods_order）
create table if not exists ydsh_ods.ods_order (
  order_id       string           comment '订单ID',
  user_id        string           comment '用户ID',
  store_id       string           comment '门店ID',
  order_date     string           comment '下单日期',
  order_time     string           comment '下单时间',
  pay_amount     decimal(12,2)    comment '实付金额',
  discount_amount decimal(12,2)    comment '优惠金额',
  pay_type       string           comment '支付方式',
  order_status   string           comment '订单状态',
  channel        string           comment '下单渠道'
) comment '订单事实表'
row format delimited fields terminated by ','
stored as textfile
tblproperties('skip.header.line.count'='1');

-- 订单明细表（ods_order_item）
create table if not exists ydsh_ods.ods_order_item (
  item_id        string           comment '明细ID',
  order_id       string           comment '订单ID',
  product_id     string           comment '商品ID',
  quantity       int              comment '购买数量',
  unit_price     decimal(12,2)    comment '单价',
  discount       decimal(5,2)     comment '折扣'
) comment '订单明细表'
row format delimited fields terminated by ','
stored as textfile
tblproperties('skip.header.line.count'='1');

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

