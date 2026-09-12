import type { Metadata,Viewport } from "next";import{ServiceWorkerRegistration}from"@/components/service-worker-registration";import "./globals.css";import "./maintenance.css";
export const metadata:Metadata={title:"TSD Production Control",description:"Production planning and operational visibility",manifest:"/manifest.webmanifest",applicationName:"TSD Production Control",appleWebApp:{capable:true,statusBarStyle:"default",title:"TSD Production"},icons:{icon:"/icon.svg",apple:"/icon.svg"}};
export const viewport:Viewport={themeColor:"#0b2929",width:"device-width",initialScale:1};
export default function Layout({children}:{children:React.ReactNode}){return <html lang="en"><body>{children}<ServiceWorkerRegistration/></body></html>}
