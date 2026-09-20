import { NextResponse } from "next/server";
import { authorizeIngest, ingestDtgDailyActuals, readDtgShiftRules, readJson } from "@/lib/ingest";
const authorized = (request: Request) => authorizeIngest(request.headers.get("authorization"), process.env.INGEST_SECRET);
export async function GET(request: Request) {
  if (!authorized(request)) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  try { return NextResponse.json(await readDtgShiftRules(new URL(request.url).searchParams.get("organizationId") ?? "")); }
  catch (error) { return NextResponse.json({ error: error instanceof Error ? error.message : "DTG shift rules failed" }, { status: 400 }); }
}
export async function POST(request: Request) {
  if (!authorized(request)) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  try { return NextResponse.json(await ingestDtgDailyActuals(await readJson(request))); }
  catch (error) { return NextResponse.json({ error: error instanceof Error ? error.message : "DTG daily ingestion failed" }, { status: 400 }); }
}
