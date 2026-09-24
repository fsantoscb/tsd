import {NextResponse} from "next/server";
import {authorizeIngest,ingestDtgOrderHistory,readJson} from "../../../../lib/ingest";

export async function POST(request:Request){
  if(!authorizeIngest(request.headers.get("authorization"),process.env.INGEST_SECRET))return NextResponse.json({error:"Unauthorized"},{status:401});
  try{
    return NextResponse.json(await ingestDtgOrderHistory(await readJson(request)));
  }catch(error){
    return NextResponse.json({error:error instanceof Error?error.message:"DTG order history ingestion failed"},{status:400});
  }
}
