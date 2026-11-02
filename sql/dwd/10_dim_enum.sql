-- 第 2 周 · 子任务 1：枚举字段标准化（编码映射表 + 维表）
-- 设计：脏值(raw) -> map 表 -> 标准编码(code) -> dim 表 -> 中文名称(name)
-- 用法：beeline -u jdbc:hive2://localhost:10000/ -f /sql/dwd/10_dim_enum.sql

create database if not exists ydsh_dwd;

-- ========== 性别 ==========
create table if not exists ydsh_dwd.dim_gender (
  gender_code string comment '编码',
  gender_name string comment '标准名称'
) comment '性别维表' stored as orc;

insert overwrite table ydsh_dwd.dim_gender values
('G1','男'), ('G2','女'), ('G0','未知');

create table if not exists ydsh_dwd.map_gender (
  raw_value string comment '原始取值',
  gender_code string comment '标准编码'
) comment '性别映射表' stored as orc;

insert overwrite table ydsh_dwd.map_gender values
('男','G1'), ('M','G1'), ('male','G1'), ('Male','G1'),
('女','G2'), ('F','G2'), ('female','G2'), ('Female','G2'),
('未知','G0'), ('','G0');

-- ========== 会员等级 ==========
create table if not exists ydsh_dwd.dim_member_level (
  level_code string comment '编码',
  level_name string comment '标准名称',
  sort_no int comment '等级排序，1 最高'
) comment '会员等级维表' stored as orc;

insert overwrite table ydsh_dwd.dim_member_level values
('LV1','钻石会员',1), ('LV2','金卡会员',2), ('LV3','银卡会员',3), ('LV4','普通会员',4);

create table if not exists ydsh_dwd.map_member_level (
  raw_value string,
  level_code string
) comment '会员等级映射表' stored as orc;

insert overwrite table ydsh_dwd.map_member_level values
('钻石会员','LV1'), ('钻石','LV1'),
('金卡会员','LV2'), ('金卡','LV2'), ('gold','LV2'), ('Gold','LV2'),
('银卡会员','LV3'), ('银卡','LV3'), ('silver','LV3'), ('Silver','LV3'),
('普通会员','LV4'), ('普通','LV4'), ('normal','LV4'), ('','LV4');

-- ========== 支付方式 ==========
create table if not exists ydsh_dwd.dim_pay_type (
  pay_code string,
  pay_name string
) comment '支付方式维表' stored as orc;

insert overwrite table ydsh_dwd.dim_pay_type values
('PT1','支付宝'), ('PT2','微信支付'), ('PT3','银行卡'), ('PT4','货到付款');

create table if not exists ydsh_dwd.map_pay_type (
  raw_value string,
  pay_code string
) comment '支付方式映射表' stored as orc;

insert overwrite table ydsh_dwd.map_pay_type values
('支付宝','PT1'), ('alipay','PT1'), ('Alipay','PT1'),
('微信支付','PT2'), ('微信','PT2'), ('wechat','PT2'), ('WeChat','PT2'),
('银行卡','PT3'),
('货到付款','PT4');

-- ========== 下单渠道 ==========
create table if not exists ydsh_dwd.dim_channel (
  channel_code string,
  channel_name string
) comment '下单渠道维表' stored as orc;

insert overwrite table ydsh_dwd.dim_channel values
('CH1','门店'), ('CH2','APP'), ('CH3','小程序'), ('CH4','PC官网');

create table if not exists ydsh_dwd.map_channel (
  raw_value string,
  channel_code string
) comment '渠道映射表' stored as orc;

insert overwrite table ydsh_dwd.map_channel values
('门店','CH1'), ('APP','CH2'), ('app','CH2'), ('App','CH2'),
('小程序','CH3'),
('PC官网','CH4'), ('pc','CH4'), ('PC','CH4');

-- ========== 订单状态 ==========
create table if not exists ydsh_dwd.dim_order_status (
  status_code string,
  status_name string,
  sort_no int
) comment '订单状态维表' stored as orc;

insert overwrite table ydsh_dwd.dim_order_status values
('ST1','待支付',1), ('ST2','已支付',2), ('ST3','已完成',3),
('ST4','已取消',4), ('ST5','退款中',5);

create table if not exists ydsh_dwd.map_order_status (
  raw_value string,
  status_code string
) comment '订单状态映射表（含数字状态码）' stored as orc;

insert overwrite table ydsh_dwd.map_order_status values
('待支付','ST1'), ('1','ST1'),
('已支付','ST2'), ('已付款','ST2'), ('2','ST2'),
('已完成','ST3'), ('完成','ST3'), ('3','ST3'),
('已取消','ST4'), ('cancelled','ST4'), ('Cancelled','ST4'), ('4','ST4'),
('退款中','ST5');

-- ========== 用户行为类型 ==========
create table if not exists ydsh_dwd.dim_behavior_type (
  behavior_code string,
  behavior_name string
) comment '行为类型维表' stored as orc;

insert overwrite table ydsh_dwd.dim_behavior_type values
('BT1','浏览'), ('BT2','加购'), ('BT3','收藏'), ('BT4','购买');

create table if not exists ydsh_dwd.map_behavior_type (
  raw_value string,
  behavior_code string
) comment '行为类型映射表' stored as orc;

insert overwrite table ydsh_dwd.map_behavior_type values
('pv','BT1'), ('PV','BT1'), ('浏览','BT1'),
('cart','BT2'), ('Cart','BT2'), ('加购','BT2'),
('fav','BT3'), ('收藏','BT3'),
('buy','BT4'), ('购买','BT4');

-- ========== 商品状态 ==========
create table if not exists ydsh_dwd.dim_product_status (
  status_code string,
  status_name string
) comment '商品状态维表' stored as orc;

insert overwrite table ydsh_dwd.dim_product_status values
('PS1','在售'), ('PS2','下架'), ('PS3','缺货');

create table if not exists ydsh_dwd.map_product_status (
  raw_value string,
  status_code string
) comment '商品状态映射表' stored as orc;

insert overwrite table ydsh_dwd.map_product_status values
('在售','PS1'), ('下架','PS2'), ('缺货','PS3');
