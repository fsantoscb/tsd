import oracledb from "oracledb";
import { resolveOracleCredential } from "../src/credential";

const env = {
  ORACLE_CONNECT_STRING: "192.168.0.222:1521/TSDPROD",
  ORACLE_CREDENTIAL_TARGET: "TSDPROD_KPI_ORACLE",
} as const;

const credential = resolveOracleCredential(env as never);
const connection = await oracledb.getConnection({
  connectString: env.ORACLE_CONNECT_STRING,
  user: credential.username,
  password: credential.password,
});

try {
  const query = async (sql: string) =>
    (await connection.execute(sql, {}, {
      outFormat: oracledb.OUT_FORMAT_OBJECT,
      fetchArraySize: 1000,
    })).rows ?? [];

  const columns = await query(`
    select TABLE_NAME, COLUMN_NAME, DATA_TYPE
    from ALL_TAB_COLUMNS
    where OWNER = user
      and TABLE_NAME in ('IS_ORDER_LINE','IS_ORDER_HEAD','IS_ORDER_VIEW_SALE_V','IS_WORKBANK_V')
      and regexp_like(COLUMN_NAME, 'QTY|QUANT|UNIT|WEIGHT|RELEASE|ORDER', 'i')
    order by TABLE_NAME, COLUMN_ID
  `);

  const groups = await query(`
    select upper(trim(p.GROUP_CODE)) GROUP_CODE,
      count(*) LINES,
      sum(case when ol.QTY_LCD > 0 then 1 else 0 end) POSITIVE_QTY_LCD,
      sum(case when ol.QTY_LCD = 0 then 1 else 0 end) ZERO_QTY_LCD,
      sum(case when ol.QTY_LCD is null then 1 else 0 end) NULL_QTY_LCD,
      sum(nvl(ol.QTY_LCD, 0)) TOTAL_QTY_LCD
    from IS_ORDER_LINE ol
    join IS_ORDER_HEAD oh on oh.ORDER_NO = ol.ORDER_NO
    left join IS_PRODUCT p on p.CODE = ol.PRODUCT and p.CLIENT = ol.CLIENT
    where oh.SITE = 'B'
      and oh.ORDER_NO like '13%'
      and oh.STATUS = 1
      and oh.DATE_DUE between SYSDATE - 30 and SYSDATE + 30
      and upper(trim(ol.RELEASED)) = 'Y'
    group by upper(trim(p.GROUP_CODE))
    order by 1
  `);

  const lineCandidates = await query(`
    select upper(trim(p.GROUP_CODE)) GROUP_CODE,
      count(*) LINES,
      sum(case when regexp_like(trim(ol.QUANTITY), '^-?[0-9]+([.][0-9]+)?$') and to_number(trim(ol.QUANTITY)) > 0 then 1 else 0 end) POSITIVE_QUANTITY,
      sum(case when ol.QUANTITY is null then 1 else 0 end) NULL_QUANTITY,
      sum(case when regexp_like(trim(ol.QUANTITY), '^-?[0-9]+([.][0-9]+)?$') then to_number(trim(ol.QUANTITY)) else 0 end) TOTAL_QUANTITY,
      sum(case when regexp_like(trim(ol.QTY_UNITS), '^-?[0-9]+([.][0-9]+)?$') and to_number(trim(ol.QTY_UNITS)) > 0 then 1 else 0 end) POSITIVE_QTY_UNITS,
      sum(case when ol.QTY_UNITS is null then 1 else 0 end) NULL_QTY_UNITS,
      sum(case when regexp_like(trim(ol.QTY_UNITS), '^-?[0-9]+([.][0-9]+)?$') then to_number(trim(ol.QTY_UNITS)) else 0 end) TOTAL_QTY_UNITS,
      sum(case when ol.WEIGHT > 0 then 1 else 0 end) POSITIVE_WEIGHT,
      sum(case when ol.WEIGHT is null then 1 else 0 end) NULL_WEIGHT,
      sum(nvl(ol.WEIGHT, 0)) TOTAL_WEIGHT,
      sum(case when ol.QTY_PROCESSED > 0 then 1 else 0 end) POSITIVE_QTY_PROCESSED,
      sum(case when ol.QTY_PROCESSED is null then 1 else 0 end) NULL_QTY_PROCESSED,
      sum(nvl(ol.QTY_PROCESSED, 0)) TOTAL_QTY_PROCESSED
    from IS_ORDER_LINE ol
    join IS_ORDER_HEAD oh on oh.ORDER_NO = ol.ORDER_NO
    left join IS_PRODUCT p on p.CODE = ol.PRODUCT and p.CLIENT = ol.CLIENT
    where oh.SITE = 'B'
      and oh.ORDER_NO like '13%'
      and oh.STATUS = 1
      and oh.DATE_DUE between SYSDATE - 30 and SYSDATE + 30
      and upper(trim(ol.RELEASED)) = 'Y'
    group by upper(trim(p.GROUP_CODE))
    order by 1
  `);

  const representativeLines = await query(`
    select * from (
      select ol.ORDER_NO, ol.LINE_NUMBER, ol.PRODUCT, upper(trim(p.GROUP_CODE)) GROUP_CODE,
        ol.RELEASED, ol.QUANTITY, ol.QTY_UNITS, ol.QTY_LCD, ol.QTY_PROCESSED, ol.WEIGHT,
        ol.ORIG_REF3, ol.CLIENT
      from IS_ORDER_LINE ol
      join IS_ORDER_HEAD oh on oh.ORDER_NO = ol.ORDER_NO
      left join IS_PRODUCT p on p.CODE = ol.PRODUCT and p.CLIENT = ol.CLIENT
      where oh.SITE = 'B'
        and oh.ORDER_NO like '13%'
        and oh.STATUS = 1
        and oh.DATE_DUE between SYSDATE - 30 and SYSDATE + 30
        and upper(trim(ol.RELEASED)) = 'Y'
        and upper(trim(p.GROUP_CODE)) in ('DTG_1','DTG_2','UNDERPRINT')
      order by ol.ORDER_NO, ol.LINE_NUMBER
    ) where rownum <= 20
  `);

  const relationshipColumns = await query(`
    select COLUMN_NAME, DATA_TYPE
    from ALL_TAB_COLUMNS
    where OWNER = user and TABLE_NAME = 'IS_ORDER_LINE'
      and regexp_like(COLUMN_NAME, 'REF|LINK|PARENT|KIT|COMP|SEQ|ORIG|LINE', 'i')
    order by COLUMN_ID
  `);

  const representativeOrderStructure = await query(`
    select ol.ORDER_NO, ol.LINE_NUMBER, ol.PRODUCT, p.NAME PRODUCT_NAME,
      upper(trim(p.GROUP_CODE)) GROUP_CODE, ol.RELEASED, ol.QUANTITY,
      ol.QTY_UNITS, ol.QTY_LCD, ol.QTY_PROCESSED, ol.WEIGHT,
      ol.ORIG_REF1, ol.ORIG_REF2, ol.ORIG_REF3
    from IS_ORDER_LINE ol
    left join IS_PRODUCT p on p.CODE = ol.PRODUCT and p.CLIENT = ol.CLIENT
    where ol.ORDER_NO = '130133510'
    order by ol.LINE_NUMBER
  `);

  const releaseAndProcessChecks = await query(`
    with scoped as (
      select ol.ORDER_NO, ol.LINE_NUMBER, ol.RELEASED, ol.ORIG_REF1,
        upper(trim(p.GROUP_CODE)) GROUP_CODE,
        case when regexp_like(trim(ol.QTY_UNITS), '^-?[0-9]+([.][0-9]+)?$')
          then to_number(trim(ol.QTY_UNITS)) end QTY_UNITS_NUM
      from IS_ORDER_LINE ol
      join IS_ORDER_HEAD oh on oh.ORDER_NO = ol.ORDER_NO
      left join IS_PRODUCT p on p.CODE = ol.PRODUCT and p.CLIENT = ol.CLIENT
      where oh.SITE = 'B' and oh.ORDER_NO like '13%' and oh.STATUS = 1
        and oh.DATE_DUE between SYSDATE - 30 and SYSDATE + 30
    ), partial_orders as (
      select ORDER_NO from scoped group by ORDER_NO
      having sum(case when upper(trim(RELEASED)) = 'Y' then 1 else 0 end) > 0
         and sum(case when upper(trim(RELEASED)) = 'N' then 1 else 0 end) > 0
    ), process_keys as (
      select ORDER_NO, ORIG_REF1, count(distinct case
        when GROUP_CODE in ('DTG_1','DTG_2') then 'DTG'
        when GROUP_CODE = 'UNDERPRINT' then 'UNDERPRINT' end) PROCESS_COUNT
      from scoped
      where upper(trim(RELEASED)) = 'Y'
        and GROUP_CODE in ('DTG_1','DTG_2','UNDERPRINT')
      group by ORDER_NO, ORIG_REF1
    )
    select
      (select count(*) from partial_orders) PARTIAL_ORDERS,
      (select count(*) from scoped s join partial_orders p on p.ORDER_NO=s.ORDER_NO
        where upper(trim(s.RELEASED))='Y' and s.QTY_UNITS_NUM > 0) PARTIAL_Y_POSITIVE,
      (select count(*) from scoped s join partial_orders p on p.ORDER_NO=s.ORDER_NO
        where upper(trim(s.RELEASED))='N') PARTIAL_N_LINES,
      (select count(*) from process_keys where PROCESS_COUNT > 1) MULTI_PROCESS_PHYSICAL_KEYS,
      (select count(*) from scoped where upper(trim(RELEASED))='Y'
        and GROUP_CODE in ('DTG_1','DTG_2','UNDERPRINT') and QTY_UNITS_NUM <= 0) SUPPORTED_NONPOSITIVE_QTY_UNITS,
      (select count(*) from scoped where upper(trim(RELEASED))='Y'
        and GROUP_CODE in ('DTG_1','DTG_2','UNDERPRINT') and QTY_UNITS_NUM is null) SUPPORTED_NULL_QTY_UNITS
    from dual
  `);

  const quantityComments = await query(`
    select COLUMN_NAME, COMMENTS from ALL_COL_COMMENTS
    where OWNER = user and TABLE_NAME = 'IS_ORDER_LINE'
      and COLUMN_NAME in ('QUANTITY','QTY_UNITS','QTY_LCD','QTY_PROCESSED','WEIGHT')
    order by COLUMN_NAME
  `);

  const workbankJoin = await query(`
    select upper(trim(p.GROUP_CODE)) GROUP_CODE,
      count(distinct ol.ORDER_NO || ':' || ol.LINE_NUMBER) RELEASE_LINES,
      count(distinct w.WB_ROWID) WORKBANK_ROWS,
      sum(nvl(w.QTY, 0)) WB_QTY,
      sum(nvl(w.WEIGHT, 0)) WB_WEIGHT
    from IS_ORDER_LINE ol
    join IS_ORDER_HEAD oh on oh.ORDER_NO = ol.ORDER_NO
    left join IS_PRODUCT p on p.CODE = ol.PRODUCT and p.CLIENT = ol.CLIENT
    left join IS_WORKBANK_V w on w.ONO = ol.ORDER_NO and w.PROD = ol.PRODUCT
    where oh.SITE = 'B'
      and oh.ORDER_NO like '13%'
      and oh.STATUS = 1
      and oh.DATE_DUE between SYSDATE - 30 and SYSDATE + 30
      and upper(trim(ol.RELEASED)) = 'Y'
      and upper(trim(p.GROUP_CODE)) in ('DTG_1','DTG_2','UNDERPRINT')
    group by upper(trim(p.GROUP_CODE))
    order by 1
  `);

  console.log(JSON.stringify({ columns, groups, lineCandidates, representativeLines,
    relationshipColumns, representativeOrderStructure, releaseAndProcessChecks,
    quantityComments, workbankJoin }, null, 2));
} finally {
  await connection.close();
}
