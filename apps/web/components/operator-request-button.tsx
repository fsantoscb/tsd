"use client";
import{useFormStatus}from"react-dom";
export function OperatorRequestButton({title,body,tone}:{title:string;body:string;tone:string}){const{pending}=useFormStatus();return <button className={`operator-choice ${tone}`} disabled={pending}><strong>{pending?"STARTING...":title}</strong><span>{body}</span></button>}
