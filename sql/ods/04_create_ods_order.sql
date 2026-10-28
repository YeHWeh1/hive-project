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
