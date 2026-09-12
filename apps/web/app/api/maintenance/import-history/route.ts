import {NextResponse}from"next/server";
import {authorizeIngest,readJson}from"@/lib/ingest";
import {capacityDb}from"@/lib/capacity";
export const runtime="nodejs";export const maxDuration=300;
export async function POST(request:Request){
 if(!authorizeIngest(request.headers.get("authorization"),process.env.INGEST_SECRET))return NextResponse.json({error:"Unauthorized"},{status:401});
 try{
  const body=await readJson(request)as any,db=capacityDb(),organizationId=process.env.ORGANIZATION_ID;
  if(!organizationId)throw Error("ORGANIZATION_ID missing");
  const{data,error}=await db.rpc("maintenance_import_history",{p_organization_id:organizationId,p_file_name:body.file_name,p_file_hash:body.file_hash,p_assets:body.assets,p_events:body.events,p_report:body.report});
  if(error)throw error;return NextResponse.json(data);
 }catch(error){return NextResponse.json({error:error instanceof Error?error.message:"Import failed"},{status:400})}
}
