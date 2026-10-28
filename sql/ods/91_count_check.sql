-- ODS 层：行数校验（期望值与手册一致）

select 'ods_user              ' as table_name, count(*) as actual, 1000 as expected,
       case when count(*) = 1000 then 'OK' else 'CHECK' end as result
from ydsh_ods.ods_user
union all
select 'ods_product           ' as table_name, count(*) as actual, 600 as expected,
       case when count(*) = 600 then 'OK' else 'CHECK' end as result
from ydsh_ods.ods_product
union all
select 'ods_store             ' as table_name, count(*) as actual, 60 as expected,
       case when count(*) = 60 then 'OK' else 'CHECK' end as result
from ydsh_ods.ods_store
union all
select 'ods_order             ' as table_name, count(*) as actual, 15600 as expected,
       case when count(*) = 15600 then 'OK' else 'CHECK' end as result
from ydsh_ods.ods_order
union all
select 'ods_order_item        ' as table_name, count(*) as actual, 37549 as expected,
       case when count(*) = 37549 then 'OK' else 'CHECK' end as result
from ydsh_ods.ods_order_item
union all
select 'ods_user_behavior     ' as table_name, count(*) as actual, 60000 as expected,
       case when count(*) = 60000 then 'OK' else 'CHECK' end as result
from ydsh_ods.ods_user_behavior;
