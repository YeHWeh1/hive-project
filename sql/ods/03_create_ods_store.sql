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
