import {NextResponse} from "next/server";
import {authorizeIngest,resolveSingleOrganizationId} from "@/lib/ingest";

export async function GET(request:Request){
  if(!authorizeIngest(request.headers.get("authorization"),process.env.INGEST_SECRET)){
    return NextResponse.json({error:"Unauthorized"},{status:401});
  }
  try{
    const supabaseUrl=process.env.NEXT_PUBLIC_SUPABASE_URL;
    if(!supabaseUrl)throw new Error("Supabase target is not configured");
    const projectRef=new URL(supabaseUrl).hostname.split(".")[0];
    if(!projectRef)throw new Error("Supabase project ref is not available");
    return NextResponse.json({organizationId:await resolveSingleOrganizationId(),projectRef});
  }catch(error){
    const message=error instanceof Error?error.message:"Organization lookup failed";
    return NextResponse.json({error:message},{status:400});
  }
}
