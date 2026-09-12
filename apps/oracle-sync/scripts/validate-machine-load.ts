import oracledb from "oracledb";
import {resolveOracleCredential} from "../src/credential";

const credential=resolveOracleCredential(process.env as never);
const connection=await oracledb.getConnection({
  connectString:process.env.ORACLE_CONNECT_STRING,
  user:credential.username,
  password:credential.password,
});

try{
  const result=await connection.execute(
    `select
       coalesce(sum(case when upper(w.FROM_ZONE)='PG11' then case when upper(trim(w.PACKDESC))='CARTON' then to_number(w.WEIGHT) else to_number(w.QTY) end else 0 end),0) dtg_pick_garments,
       coalesce(sum(case when upper(w.FROM_ZONE)='DTGS' then case when upper(trim(w.PACKDESC))='CARTON' then to_number(w.WEIGHT) else to_number(w.QTY) end else 0 end),0) dtg_print_garments,
       coalesce(sum(case when upper(w.FROM_ZONE) in ('PG01','PG1H','PG1A','PG1D') then case when upper(trim(w.PACKDESC))='CARTON' then to_number(w.WEIGHT) else to_number(w.QTY) end else 0 end),0) underprint_workbank,
       max((select coalesce(sum(s.WEIGHT),0) from IS_STOCK s where s.PRODUCT like '#%' and s.LOCATION not like 'CONS%' and s.LOCATION not like 'DROPZONE%' and upper(s.LOCATION) like '%UNDERPRINT%')) underprint_stock
     from IS_WORKBANK_V w
     join IS_ORDER_HEAD oh on oh.ORDER_NO=w.ONO
     where oh.DATE_COMPLETED is null`,
    {},
    {outFormat:oracledb.OUT_FORMAT_OBJECT},
  );
  console.log(result.rows?.[0]);
}finally{
  await connection.close();
}
