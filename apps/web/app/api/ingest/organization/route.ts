import {NextResponse} from "next/server";
import {authorizeIngest,resolveSingleOrganizationId} from "@/lib/ingest";

export async function GET(request:Request){
  if(!authorizeIngest(request.headers.get("authorization"),process.env.INGEST_SECRET)){
    return NextResponse.json({error:"Unauthorized"},{status:401});
  }
  try{
    return NextResponse.json({organizationId:await resolveSingleOrganizationId()});
  }catch(error){
    const message=error instanceof Error?error.message:"Organization lookup failed";
    return NextResponse.json({error:message},{status:400});
  }
}
