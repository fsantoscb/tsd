export function validatePassword(value:string){if(value.length<12)return "Use at least 12 characters.";if(!/[a-z]/.test(value)||!/[A-Z]/.test(value)||!/[0-9]/.test(value))return "Include uppercase, lowercase and a number.";return null}
export function isAuthorizedAdminEmail(email:string|null|undefined,configured=process.env.ADMIN_EMAIL){
 const allowed=(configured??"").toLowerCase().split(",").map(value=>value.trim()).filter(Boolean);
 return allowed.length>0&&Boolean(email)&&allowed.includes(email!.toLowerCase());
}
