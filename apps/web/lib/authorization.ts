import "server-only";
import {createClient} from "@supabase/supabase-js";
import {redirect} from "next/navigation";
import {createClient as sessionClient} from "@/lib/supabase/server";
import {roleHasPermission,type AppRole,type Permission} from "@/lib/permissions";
function admin(){const u=process.env.NEXT_PUBLIC_SUPABASE_URL,k=process.env.SUPABASE_SERVICE_ROLE_KEY;if(!u||!k)throw new Error("Supabase server environment missing");return createClient(u,k,{auth:{persistSession:false,autoRefreshToken:false}})}
export async function requirePermission(permission:Permission){const session=await sessionClient(),{data}=await session.auth.getUser();if(!data.user)redirect("/login");const db=admin(),{data:member,error}=await db.from("maintenance_members").select("organization_id,role,active").eq("user_id",data.user.id).eq("active",true).maybeSingle();if(error)throw error;if(!member||!roleHasPermission(member.role,permission))redirect("/login?error=unauthorized");return{user:data.user,organizationId:member.organization_id,role:member.role as AppRole,db}}
