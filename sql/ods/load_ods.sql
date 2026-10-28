-- ODS 层：把 6 个 CSV 导入对应表（文件需已在容器 /data 下）
-- 用法：beeline -u jdbc:hive2://localhost:10000/ -f /sql/ods/load_ods.sql
-- 重复导入前先 truncate，避免数据翻倍

-- ods_user
-- truncate table ydsh_ods.ods_user;
load data local inpath '/data/ods_user.csv' into table ydsh_ods.ods_user;

-- ods_product
-- truncate table ydsh_ods.ods_product;
load data local inpath '/data/ods_product.csv' into table ydsh_ods.ods_product;

-- ods_store
-- truncate table ydsh_ods.ods_store;
load data local inpath '/data/ods_store.csv' into table ydsh_ods.ods_store;

-- ods_order
-- truncate table ydsh_ods.ods_order;
load data local inpath '/data/ods_order.csv' into table ydsh_ods.ods_order;

-- ods_order_item
-- truncate table ydsh_ods.ods_order_item;
load data local inpath '/data/ods_order_item.csv' into table ydsh_ods.ods_order_item;

-- ods_user_behavior
-- truncate table ydsh_ods.ods_user_behavior;
load data local inpath '/data/ods_user_behavior.csv' into table ydsh_ods.ods_user_behavior;

