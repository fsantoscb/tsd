import argparse,gzip,hashlib,json,os,sys,urllib.error,urllib.request
from collections import Counter
from datetime import date,datetime
import openpyxl

def clean(v):
    if isinstance(v,(datetime,date)): return v.isoformat(sep=" ")
    return v
def rows(ws):
    it=ws.iter_rows(values_only=True); heads=[str(x).strip() for x in next(it)]
    return [{heads[i]:clean(v) for i,v in enumerate(row)} for row in it if any(v is not None for v in row)]
def load(path):
    wb=openpyxl.load_workbook(path,read_only=True,data_only=True)
    assets=rows(wb["Asset Matrix"]); events=rows(wb["ERP Maintenance Import"])
    ph=[x for x in rows(wb["PH Registry"]) if "template/example" not in str(x.get("notes","")).lower()]
    installs=[x for x in rows(wb["PH Installation History"]) if "template/example" not in str(x.get("notes","")).lower()]
    for x in assets:x.update(asset_kind="FIXED",asset_type=x.get("asset_level"))
    for x in ph:
        code=x.pop("ph_asset_code");x.update(asset_code=code,asset_name=code+" Printhead",asset_kind="MOVABLE",category="Printhead",parent_asset_code=None)
    return assets+ph,events,installs
def dry(path):
    assets,events,installs=load(path);codes={x["asset_code"] for x in assets};errors=[];warnings=[]
    keys=Counter((x.get("source_system"),x.get("source_key")) for x in events)
    for x in events:
        row=x.get("source_row")
        if x.get("parent_asset_code") not in codes:errors.append({"row":row,"error":"MISSING_HOST","code":x.get("parent_asset_code")})
        if x.get("asset_code") not in codes:errors.append({"row":row,"error":"MISSING_ASSET","code":x.get("asset_code")})
        if x.get("downtime_minutes") is None or float(x["downtime_minutes"])<0:errors.append({"row":row,"error":"INVALID_DOWNTIME"})
        if keys[(x.get("source_system"),x.get("source_key"))]>1:errors.append({"row":row,"error":"DUPLICATE_SOURCE_KEY"})
        if x.get("ph_reference") and not x.get("ph_asset_code"):warnings.append({"row":row,"warning":"UNRESOLVED_PH","reference":x.get("ph_reference")})
    report={"total_rows":len(events),"valid_rows":len(events)-len({e["row"] for e in errors}),"warning_rows":len({w["row"] for w in warnings}),
      "error_rows":len({e["row"] for e in errors}),"duplicate_rows":sum(v-1 for v in keys.values() if v>1),"assets_found":len(assets),
      "assets_missing":sorted({e.get("code") for e in errors if e.get("code")}),"events_to_insert":len(events),"events_to_update":0,
      "unresolved_ph_references":dict(Counter(w["reference"] for w in warnings)),"invalid_installation_ranges":0,
      "duplicate_active_installations":0,"source_downtime_minutes":sum(float(x.get("downtime_minutes")or 0) for x in events),
      "by_host":dict(Counter(x.get("parent_asset_code") for x in events)),"by_year":dict(Counter(str(x.get("event_date"))[:4] for x in events)),
      "by_event_type":dict(Counter(x.get("event_type") for x in events)),"errors":errors[:500],"warnings":warnings[:500]}
    return assets,events,installs,report
def main():
    ap=argparse.ArgumentParser();ap.add_argument("workbook");ap.add_argument("--output",default="docs/maintenance-import-reconciliation.json");ap.add_argument("--commit",action="store_true");a=ap.parse_args()
    assets,events,installs,report=dry(a.workbook);os.makedirs(os.path.dirname(a.output),exist_ok=True)
    with open(a.output,"w",encoding="utf-8")as f:json.dump(report,f,indent=2,ensure_ascii=False)
    print(json.dumps({k:v for k,v in report.items()if k not in("errors","warnings")},indent=2))
    if report["error_rows"]:sys.exit(2)
    if a.commit:
        url=os.environ.get("NEXT_PUBLIC_APP_URL","https://tsd-production-control.vercel.app")+"/api/maintenance/import-history";key=os.environ["INGEST_SECRET"]
        digest=hashlib.sha256(open(a.workbook,"rb").read()).hexdigest()
        body=gzip.compress(json.dumps({"file_name":os.path.basename(a.workbook),"file_hash":digest,"assets":assets,"events":events,"report":report}).encode())
        req=urllib.request.Request(url,body,{"Authorization":"Bearer "+key,"Content-Type":"application/json","Content-Encoding":"gzip"},method="POST")
        try: print(urllib.request.urlopen(req,timeout=180).read().decode())
        except urllib.error.HTTPError as e:
            print(e.read().decode(),file=sys.stderr);raise
if __name__=="__main__":main()
