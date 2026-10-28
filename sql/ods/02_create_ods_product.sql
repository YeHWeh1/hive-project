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
