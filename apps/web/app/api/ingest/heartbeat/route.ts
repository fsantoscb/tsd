import {NextResponse} from "next/server";import {authorizeIngest,heartbeat,readJson} from "@/lib/ingest";
export async function POST(request:Request){
 if(!authorizeIngest(request.headers.get("authorization"),process.env.INGEST_SECRET)) return NextResponse.json({error:"Unauthorized"},{status:401});
 try{await heartbeat(await readJson(request));return NextResponse.json({ok:true})}catch(error){return NextResponse.json({error:error instanceof Error?error.message:"Invalid heartbeat"},{status:400})}
}
