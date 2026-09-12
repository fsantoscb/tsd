"use client";
import{useEffect,useState}from"react";
export function OperatorLiveTimer({startedAt}:{startedAt:string}){const[seconds,setSeconds]=useState(()=>Math.max(0,Math.floor((Date.now()-new Date(startedAt).getTime())/1000)));useEffect(()=>{const id=setInterval(()=>setSeconds(Math.max(0,Math.floor((Date.now()-new Date(startedAt).getTime())/1000))),1000);return()=>clearInterval(id)},[startedAt]);const h=Math.floor(seconds/3600),m=Math.floor(seconds%3600/60),s=seconds%60;return <time className="operator-live-time">{[h,m,s].map(x=>String(x).padStart(2,"0")).join(":")}</time>}
