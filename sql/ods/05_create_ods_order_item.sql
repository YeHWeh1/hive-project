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
