import type { NextConfig } from "next";
const securityHeaders=[{key:"X-Content-Type-Options",value:"nosniff"},{key:"X-Frame-Options",value:"DENY"},{key:"Referrer-Policy",value:"same-origin"},{key:"Permissions-Policy",value:"camera=(self), microphone=(), geolocation=()"}];
const config:NextConfig={transpilePackages:["@tsd/shared"],poweredByHeader:false,async headers(){return[{source:"/:path*",headers:securityHeaders},{source:"/sw.js",headers:[{key:"Cache-Control",value:"public, max-age=0, must-revalidate"},{key:"Service-Worker-Allowed",value:"/"}]}]}};export default config;
