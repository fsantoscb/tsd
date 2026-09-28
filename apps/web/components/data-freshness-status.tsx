"use client";

import {useEffect,useRef,useState} from "react";

type Health={state:string;lastSuccess:string|null;heartbeat:any;lastRun:any;activeRequest:any};
type VisibilitySource=Pick<EventTarget,"addEventListener"|"removeEventListener"> & {visibilityState:DocumentVisibilityState};

const fmt=(v:string|null)=>v?new Intl.DateTimeFormat("en-AU",{timeZone:"Australia/Brisbane",day:"2-digit",month:"short",hour:"2-digit",minute:"2-digit"}).format(new Date(v)):"Never";
const relative=(v:string|null)=>{if(!v)return"No successful snapshot";const m=Math.max(0,Math.floor((Date.now()-new Date(v).getTime())/60000));return m<1?"Updated just now":`Updated ${m} min ago`};

export function startFreshnessPolling(load:()=>Promise<void>,page:VisibilitySource=document){
 let timer:ReturnType<typeof setInterval>|null=null;
 let visible=false;
 let stopped=false;
 let inFlight=false;
 let refreshPending=false;

 async function run(){
  if(stopped||page.visibilityState!=="visible")return;
  if(inFlight)return;
  inFlight=true;
  try{await load()}
  finally{
   inFlight=false;
   if(refreshPending){refreshPending=false;if(!stopped&&page.visibilityState==="visible")void run()}
  }
 }

 function onVisibilityChange(){
  if(page.visibilityState!=="visible"){
   visible=false;
   refreshPending=false;
   if(timer!==null){clearInterval(timer);timer=null}
   return;
  }
  if(visible)return;
  visible=true;
  if(inFlight)refreshPending=true;
  else void run();
  timer=setInterval(()=>{if(!inFlight)void run()},60_000);
 }

 page.addEventListener("visibilitychange",onVisibilityChange);
 onVisibilityChange();
 return{
  refresh(){if(inFlight){refreshPending=true;return Promise.resolve()}return run()},
  stop(){stopped=true;page.removeEventListener("visibilitychange",onVisibilityChange);if(timer!==null){clearInterval(timer);timer=null}},
 };
}

export function DataFreshnessStatus(){
 const[data,setData]=useState<Health|null>(null),[error,setError]=useState(false);
 const polling=useRef<ReturnType<typeof startFreshnessPolling>|null>(null);
 async function load(){try{const r=await fetch("/api/sync/status",{cache:"no-store"});if(r.ok){setData(await r.json());setError(false)}}catch{setError(true)}}
 useEffect(()=>{polling.current=startFreshnessPolling(load);return()=>{polling.current?.stop();polling.current=null}},[]);
 async function refresh(){setData(x=>x?{...x,activeRequest:{status:"QUEUED"}}:x);const r=await fetch("/api/sync/refresh",{method:"POST"});if(!r.ok)setError(true);await polling.current?.refresh()}
 const active=data?.activeRequest?.status,button=active==="RUNNING"?"REFRESHING...":active==="QUEUED"?"REFRESH REQUESTED":data?.lastRun?.trigger_type==="MANUAL"&&data.lastRun.status==="SUCCESS"?"UPDATED":data?.lastRun?.trigger_type==="MANUAL"&&data.lastRun.status==="FAILED"?"REFRESH FAILED":"REFRESH NOW";
 return <section className="global-freshness" role="status" aria-live="polite"><span><i className={(data?.state??"NO_DATA").toLowerCase()}/><b>ORACLE {error?"STATUS ERROR":data?.state??"LOADING"}</b><small>{relative(data?.lastSuccess??null)} · {fmt(data?.lastSuccess??null)}</small></span><button onClick={refresh} disabled={!data||Boolean(active)}>{button}</button><a href="/admin/sync-status">Source health</a></section>;
}
