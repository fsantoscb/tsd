import {NextResponse} from "next/server";import {authorizeIngest,ingest,readJson} from "@/lib/ingest";
export async function POST(request:Request){
 if(!authorizeIngest(request.headers.get("authorization"),process.env.INGEST_SECRET)) return NextResponse.json({error:"Unauthorized"},{status:401});
 try{return NextResponse.json({batchId:await ingest(await readJson(request))},{status:202})}
 catch(error){const message=error instanceof Error?error.message:"Ingestion failed";return NextResponse.json({error:message},{status:message==="PAYLOAD_TOO_LARGE"?413:400})}
}
