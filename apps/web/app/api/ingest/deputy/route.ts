import {NextResponse} from "next/server";
import {authorizeIngest} from "@/lib/ingest";
import {capacityDb} from "@/lib/capacity";
import {importDeputy} from "@/lib/deputy";

export const runtime="nodejs";
export const maxDuration=60;

export async function POST(request:Request){
  if(!authorizeIngest(request.headers.get("authorization"),process.env.INGEST_SECRET))return NextResponse.json({error:"Unauthorized"},{status:401});
  try{
    const form=await request.formData(),file=form.get("file"),timezone=String(form.get("timezone")||"Australia/Brisbane");
    if(!(file instanceof File))return NextResponse.json({error:"Multipart field 'file' is required"},{status:400});
    if(timezone!=="Australia/Brisbane"&&timezone!=="UTC")return NextResponse.json({error:"Unsupported timezone"},{status:400});
    const configured=process.env.ORGANIZATION_ID;
    const organizationId=configured||await capacityDb().from("organizations").select("id").limit(1).single().then(x=>{if(x.error)throw x.error;return x.data.id});
    const duplicate=await importDeputy(file,timezone,{organizationId,email:"sharepoint-automation@system"});
    return NextResponse.json({ok:true,status:duplicate?"duplicate":"imported",filename:file.name},{status:duplicate?200:201});
  }catch(error){
    const message=error instanceof Error?error.message:"Deputy import failed";
    return NextResponse.json({error:message},{status:message.includes("15 MB")?413:400});
  }
}
