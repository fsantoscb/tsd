import {describe,expect,it} from "vitest";import {authorizeIngest,readJson} from "../lib/ingest";
describe("ingest security",()=>{const secret="s".repeat(32);
 it("requires exact bearer secret",()=>{expect(authorizeIngest(`Bearer ${secret}`,secret)).toBe(true);expect(authorizeIngest("Bearer bad",secret)).toBe(false)});
 it("rejects payloads larger than the 200 MB ingestion limit",async()=>{const request=new Request("http://local",{method:"POST",headers:{"content-length":String(201*1024*1024)},body:"{}"});await expect(readJson(request)).rejects.toThrow("PAYLOAD_TOO_LARGE")});
});
