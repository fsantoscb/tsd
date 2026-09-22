import { AppShell } from "@/components/app-shell";
import { machineLoad } from "@/lib/machine-load";
import Link from "next/link";

const num = (v: number) => v.toLocaleString("en-AU", { maximumFractionDigits: 0 });
const dec = (v: number) => v.toLocaleString("en-AU", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const brisbaneToday = () => new Date(`${new Intl.DateTimeFormat("en-CA", { timeZone: "Australia/Brisbane", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date())}T12:00:00Z`);
const dayLabel = (date: Date) => new Intl.DateTimeFormat("en-AU", { weekday: "short", day: "2-digit", month: "short", timeZone: "UTC" }).format(date);

type Params = { sat?:string; sun?:string; dueFrom?:string; dueTo?:string; customer?:string; order?:string; priority?:string; site?:string; mixGroup?:string; productType?:string; mixView?:string; showNotApproved?:string };

export default async function Page({searchParams}:{searchParams:Promise<Params>}) {
  const params = await searchParams;
  const saturday = params.sat === "1";
  const sunday = params.sun === "1";
  const productionDays = 5 + Number(saturday) + Number(sunday);
  const dates: Date[] = [];
  for (let date = brisbaneToday(); dates.length < productionDays; date = new Date(date.getTime() + 86400000)) {
    const weekday = date.getUTCDay();
    if ((weekday === 6 && !saturday) || (weekday === 0 && !sunday)) continue;
    dates.push(date);
  }
  const data = await machineLoad(params);
  const showNotApproved=params.showNotApproved==="1";
  const displayQuery=(enabled:boolean)=>{const q=new URLSearchParams(Object.entries(params).filter(([key,value])=>value&&key!=="showNotApproved").map(([key,value])=>[key,String(value)]));if(enabled)q.set("showNotApproved","1");return`?${q.toString()}`};
  const total = data.orders.reduce((s: any, r: any) => ({
    wg: s.wg + Number(r.warehouse_garments),
    wp: s.wp + Number(r.warehouse_prints),
    pg: s.pg + Number(r.print_garments),
    pp: s.pp + Number(r.print_prints),
    fp: s.fp + Number(r.forecast_pick_prints),
    fr: s.fr + Number(r.forecast_ratio),
    fc: s.fc + Number(r.forecast_product_coverage),
    up: s.up + Number(r.underprint_pick),
    ua: s.ua + Number(r.underprint_active),
    odo: s.odo + Number(r.ongoing_dtg_orders), odg: s.odg + Number(r.ongoing_dtg_garments), oso: s.oso + Number(r.ongoing_screen_orders), osg: s.osg + Number(r.ongoing_screen_garments),
    ro: s.ro + Number(r.ready_orders),
    rl: s.rl + Number(r.ready_locations),
    rb: s.rb + Number(r.ready_boxes),
    rg: s.rg + Number(r.ready_garments),
  }), { wg: 0, wp: 0, pg: 0, pp: 0, fp: 0, fr: 0, fc: 0, up: 0, ua: 0, odo:0, odg:0, oso:0, osg:0, ro: 0, rl: 0, rb: 0, rg: 0 });
  const capacity = data.dailyCapacity;
  const confirmedDemand = total.pp;
  const forecastDemand = total.fp;
  const demand = confirmedDemand + forecastDemand;
  const lead = capacity ? demand / capacity : 0;
  const upLead=data.upDailyCapacity?(total.up+total.ua)/data.upDailyCapacity:0;
  const dailyLoad = capacity ? demand / capacity * 100 : 0;
  const weeklyCapacity = capacity * productionDays;
  const weeklyLoad = weeklyCapacity ? demand / weeklyCapacity * 100 : 0;
  const runway = dates.map((date, index) => {
    const consumed = capacity * index;
    const confirmedStart = Math.max(0, confirmedDemand - consumed);
    const forecastStart = Math.max(0, forecastDemand - Math.max(0, consumed - confirmedDemand));
    const start = confirmedStart + forecastStart;
    const output = Math.max(0, Math.min(capacity, start));
    return { day: dayLabel(date), confirmedStart, forecastStart, start, output, end: Math.max(0, start - output), sla: capacity ? start / capacity : 0 };
  });
  const carryover = runway.at(-1)?.end ?? demand;
  const mixView=["audience","garment","pick"].includes(params.mixView??"")?params.mixView!:"audience";
  const mixQuery=(view:string)=>{const q=new URLSearchParams(Object.entries(params).filter(([,v])=>v).map(([k,v])=>[k,String(v)]));q.set("mixView",view);return `?${q}`};
  const mixRows=mixView==="audience"?data.productionMix.model.audiences.map(x=>({group:x.label,total:x.total,awaiting:x.toPick,ready:x.picked,percent:x.share,orders:x.orders,skus:0,detail:x.types.map(t=>`${t.label}: ${num(t.total)}`).join(" · ")})):data.productionMix.model.garmentTypes.map(x=>({group:x.label,total:x.total,awaiting:x.toPick,ready:x.picked,percent:x.share,orders:x.orders,skus:0,detail:`${num(x.toPick)} to pick · ${num(x.picked)} picked`}));

  return <AppShell><div className="ops-dashboard">
    <section className="capacity-hero">
      <div><p className="eyebrow">Production control · live snapshot</p><h2>Machine load</h2><p>Consolidated flow from warehouse pick to DTG print.</p></div>
      <div className="machine-hero-actions"><Link className={`potential-toggle ${showNotApproved?"on":""}`} href={displayQuery(!showNotApproved)} aria-pressed={showNotApproved}><span>Show Not Approved</span><b>{showNotApproved?"ON":"OFF"}</b><small>Informational only</small></Link><div className="capacity-lead-pair"><div className="capacity-lead"><span>UP RELATIVE LEAD TIME</span><strong>{data.upDailyCapacity?dec(upLead):"N/A"}</strong><small>{data.upDailyCapacity?"working days at current capacity":"capacity unavailable"}</small></div><div className="capacity-lead"><span>DTG RELATIVE LEAD TIME</span><strong>{dec(lead)}</strong><small>working days at current capacity</small></div></div></div>
    </section>

    {showNotApproved&&<section className="potential-load" aria-label="Potential Not Approved load"><div className="section-title"><div><p className="eyebrow">Informational only · not executable</p><h3>Potential Not Approved Load</h3><p>Canonical Release Queue records. These process quantities do not affect active load, capacity, utilisation, runway, backlog, Production Demand or Manufacturing Orders.</p></div><Link href="/production/release-queue?status=NOT_APPROVED">Open Release Queue</Link></div><div className="potential-kpis"><article><span>Orders</span><strong>{num(data.potentialNotApprovedLoad.summary.orders)}</strong><small>{num(data.potentialNotApprovedLoad.summary.lines)} source lines</small></article><article><span>DTG potential</span><strong>{num(data.potentialNotApprovedLoad.summary.dtgProcessQuantity)}</strong><small>process qty · not garments</small></article><article><span>Underprint potential</span><strong>{num(data.potentialNotApprovedLoad.summary.underprintProcessQuantity)}</strong><small>process qty · not garments</small></article><article><span>Unresolved / other</span><strong>{num(data.potentialNotApprovedLoad.summary.unresolvedProcessQuantity)}</strong><small>not assigned to a machine</small></article><article><span>Routing resolution</span><strong>{data.potentialNotApprovedLoad.summary.routingResolved} / {data.potentialNotApprovedLoad.summary.routingAmbiguous} / {data.potentialNotApprovedLoad.summary.routingUnresolved}</strong><small>resolved / ambiguous / unresolved orders</small></article></div><div className="potential-warning"><b>Potential load only</b><span>Physical garment count is unresolved. Values below preserve Oracle process quantity without conversion.</span></div><div className="potential-table"><table><thead><tr><th>SO / Line</th><th>Customer</th><th>Product</th><th>Process</th><th>Machine bucket</th><th>Due</th><th>Process Qty</th><th>Routing</th><th>Blockers</th><th>Status</th></tr></thead><tbody>{data.potentialNotApprovedLoad.items.map((row,index)=><tr key={`${row.order_no}:${row.line_number}:${index}`}><td><b>{row.order_no}</b><small>Line {row.line_number}</small></td><td>{row.customer_name??"—"}</td><td><b>{row.product??"—"}</b><small>{row.product_name??""}</small></td><td>{row.process}</td><td>{row.machine_load_bucket??"UNRESOLVED"}</td><td>{row.date_due?new Intl.DateTimeFormat("en-AU",{day:"2-digit",month:"short",year:"numeric"}).format(new Date(row.date_due)):"—"}</td><td className="potential-qty">{num(row.processQuantity)}<small>PROCESS QTY</small></td><td><span className={`resolution ${row.routing_resolution.toLowerCase()}`}>{row.routing_resolution}</span><small>{row.routing_code??"No canonical routing"}</small></td><td>{row.blockers.length?row.blockers.join(", "):"—"}</td><td><span className="not-approved">NOT APPROVED</span></td></tr>)}</tbody></table>{data.potentialNotApprovedLoad.items.length===0&&<p className="potential-empty">No Not Approved process lines match the applicable filters.</p>}</div></section>}

    <section className="load-matrix">
      <div className="matrix-title"><span>Machine load</span><strong>PRINTS</strong><small>Live queue snapshot</small></div>
      <div className="matrix-groups machine-four">
        <article><header>Underprint</header><div className="matrix-cells"><div><span>UP to pick</span><b>{num(total.up)}</b><small>garments</small></div><div><span>Ready to print</span><b>{num(total.ua)}</b><small>garments</small></div><div><span>Total UP load</span><b>{num(total.up+total.ua)}</b><small>garments</small></div></div></article>
        <article className="primary"><header>DTG</header><div className="matrix-cells"><div><span>To pick · PG11</span><b>{num(total.wg)}</b><small>garments · ≈ {num(forecastDemand)} forecast prints</small></div><div><span>Ready to print · DTGS</span><b>{num(total.pg)}</b><small>garments · {num(confirmedDemand)} confirmed prints</small></div><div><span>Total print load</span><b>{num(total.wg+total.pg)}</b><small>garments · {num(demand)} prints</small></div></div></article>
        <article className="ongoing"><header>On Going Orders</header><div className="matrix-cells"><div><span>DTG</span><b>{num(total.odo)}</b><small>{num(total.odg)} garments remaining</small></div><div><span>Screen Print</span><b>{num(total.oso)}</b><small>{num(total.osg)} garments remaining · manual source</small></div></div></article>
        <article className="dispatch"><header>Dispatch · Ready to Lift</header><div className="matrix-cells four"><div><span>Orders</span><b>{num(total.ro)}</b><small>to print = 0</small></div><div><span>Garments</span><b>{num(total.rg)}</b><small>ready to dispatch</small></div><div><span>Putwall locations</span><b>{num(total.rl)}</b><small>ready scope only</small></div><div><span>Boxes</span><b>{num(total.rb)}</b><small>ready scope only</small></div></div></article>
      </div>
      <div className="machine-reconciliation"><span>DTG · Not started {data.reconciliation.dtg.notStarted} · On going {data.reconciliation.dtg.ongoing} · Ready {data.reconciliation.dtg.ready} · Outside {data.reconciliation.dtg.outside}</span><span>Screen Print · Not started {data.reconciliation.screen.notStarted} · On going {data.reconciliation.screen.ongoing} · Ready {data.reconciliation.screen.ready} · Outside {data.reconciliation.screen.outside}</span>{(data.reconciliation.dtg.outside>0||data.reconciliation.screen.outside>0)&&<small title={`${data.reconciliation.outsideReasons.dtg}. ${data.reconciliation.outsideReasons.screen}`}>Outside records require dispatch evidence; no state was guessed.</small>}</div>
    </section>

    <section className="production-mix">
      <div className="section-title"><div><p className="eyebrow">Physical workload profile</p><h3>Production Mix</h3><p className="mix-intro">Garments waiting for warehouse picking plus garments released to print. This view anticipates machine productivity impact.</p></div><span>{num(data.productionMix.total)} garments</span></div>
      <nav className="mix-view-tabs" aria-label="Production Mix view"><Link className={mixView==="audience"?"active":""} href={mixQuery("audience")}>Audience</Link><Link className={mixView==="garment"?"active":""} href={mixQuery("garment")}>Garment type</Link><Link className={mixView==="pick"?"active":""} href={mixQuery("pick")}>Pick status</Link></nav>
      <form className="mix-filters" method="get">
        <input type="hidden" name="sat" value={saturday ? "1" : "0"}/><input type="hidden" name="sun" value={sunday ? "1" : "0"}/>{showNotApproved&&<input type="hidden" name="showNotApproved" value="1"/>}
        <label><span>Due from</span><input type="date" name="dueFrom" defaultValue={params.dueFrom}/></label>
        <label><span>Due to</span><input type="date" name="dueTo" defaultValue={params.dueTo}/></label>
        <label><span>Client</span><input name="customer" defaultValue={params.customer} placeholder="Name contains..."/></label>
        <label><span>Order</span><input name="order" defaultValue={params.order} placeholder="Order number"/></label>
        <label><span>Priority</span><select name="priority" defaultValue={params.priority ?? ""}><option value="">All</option>{data.productionMix.options.priorities.map(value => <option key={value}>{value}</option>)}</select></label>
        <label><span>Site</span><select name="site" defaultValue={params.site ?? ""}><option value="">All</option>{data.productionMix.options.sites.map(value => <option key={value}>{value}</option>)}</select></label>
        <label><span>Mix group</span><select name="mixGroup" defaultValue={params.mixGroup ?? ""}><option value="">All</option>{data.productionMix.options.groups.map(value => <option key={value}>{value}</option>)}</select></label>
        <label><span>Product type</span><select name="productType" defaultValue={params.productType ?? ""}><option value="">All</option>{data.productionMix.options.productTypes.map(value => <option key={value}>{value}</option>)}</select></label>
        <div className="mix-filter-actions"><button type="submit">Apply filters</button><Link href={`?sat=${saturday?1:0}&sun=${sunday?1:0}`}>Clear</Link></div>
      </form>
      <div className="mix-cards">
        <article><span>Total machine load</span><strong>{num(data.productionMix.total)}</strong><small>garments</small></article>
        <article><span>Adult T-shirts</span><strong>{dec(data.productionMix.cards.adult)}%</strong><small>of total load</small></article>
        <article><span>Kids T-shirts</span><strong>{dec(data.productionMix.cards.kids)}%</strong><small>of total load</small></article>
        <article><span>Hoodies / Sweats</span><strong>{dec(data.productionMix.cards.hoodies)}%</strong><small>of total load</small></article>
        <article><span>Other products</span><strong>{dec(data.productionMix.cards.other)}%</strong><small>includes unmapped types</small></article>
      </div>
      {(data.productionMix.quality.emptyDescription > 0 || data.productionMix.quality.invalidQuantity > 0 || data.productionMix.quality.unknownTypes.length > 0) && <div className="mix-quality"><strong>Data quality attention</strong><span>{data.productionMix.quality.emptyDescription} empty descriptions</span><span>{data.productionMix.quality.invalidQuantity} invalid quantities</span><span title={data.productionMix.quality.unknownTypes.join(", ")}>{data.productionMix.quality.unknownTypes.length} new product types in OTHER</span></div>}
      <div className={`mix-reconcile ${data.productionMix.model.reconciled?"ok":"bad"}`}>{data.productionMix.model.reconciled?"RECONCILED":"CHECK REQUIRED"} · Audience, garment type and pick status = {num(data.productionMix.model.total)} garments</div>
      <div className="mix-semantic-note"><b>Unit-safe view</b><span>Active bars are physical garments from Workbank. Not Approved is shown separately as process quantity and is never added to active load.</span></div>
      <div className="mix-family-grid" aria-label="Production mix by product family">
        {data.informationalProductMix.families.map(family=>{
          const activeMax=Math.max(1,...data.informationalProductMix.families.map(item=>item.activePhysicalTotal));
          const potentialMax=Math.max(1,...data.informationalProductMix.families.map(item=>item.notApprovedProcessQuantity));
          return <details key={family.family} className={`mix-family-card ${family.family==="OTHER"?"unclassified":""}`}>
            <summary><div><strong>{family.family==="OTHER"?"Unclassified / Other":family.family}</strong><small>{family.activeOrders} active orders{showNotApproved?` · ${family.potentialOrders} potential`:""}</small></div><b>{num(family.activePhysicalTotal)} <small>garments</small></b></summary>
            <div className="mix-family-bars"><div><span>Waiting for picking</span><i><b style={{width:`${family.waitingForPicking/activeMax*100}%`}}/></i><em>{num(family.waitingForPicking)}</em></div><div><span>Ready to print</span><i><b style={{width:`${family.readyToPrint/activeMax*100}%`}}/></i><em>{num(family.readyToPrint)}</em></div>{showNotApproved&&<div className="potential"><span>Not Approved</span><i><b style={{width:`${family.notApprovedProcessQuantity/potentialMax*100}%`}}/></i><em>{num(family.notApprovedProcessQuantity)} process qty</em></div>}</div>
            <div className="mix-family-detail"><table><thead><tr><th>SO / Line</th><th>Product</th><th>State</th><th>Quantity</th><th>Semantics</th><th>Due</th></tr></thead><tbody>{family.details.map(row=><tr key={row.recordKey}><td>{row.orderNo}{row.lineNumber?` / ${row.lineNumber}`:""}</td><td><b>{row.productCode||"—"}</b><small>{row.productDescription||"No description"}</small></td><td>{row.state.replaceAll("_"," ")}</td><td>{num(row.quantity)}</td><td>{row.quantitySemantics.replaceAll("_"," ")}</td><td>{row.dueDate?.slice(0,10)||"—"}</td></tr>)}</tbody></table>{family.details.length===0&&<p>No matching records.</p>}</div>
          </details>;
        })}
      </div>
      <div className="mix-coverage"><span>Classification coverage <b>{dec(data.informationalProductMix.summary.activeCoveragePercent)}%</b></span><span>Unclassified active <b>{num(data.informationalProductMix.summary.unclassifiedActiveQuantity)}</b></span>{showNotApproved&&<span>Not Approved <b>{num(data.informationalProductMix.summary.notApprovedProcessQuantity)}</b> process qty</span>}<span className={data.informationalProductMix.reconciled?"ok":"bad"}>{data.informationalProductMix.reconciled?"ACTIVE RECONCILED":"CHECK ACTIVE TOTAL"}</span></div>
      <div className="mix-legend"><span><i className="awaiting"/>To Pick · SP11</span><span><i className="ready"/>Picked / Ready · PCOR</span></div>
      <div className={`mix-chart mix-${mixView}`} role="img" aria-label={`Production volume by ${mixView}`}>
        {(mixView==="garment"?data.productionMix.groups:mixRows).map(group => {
          const maximum = data.productionMix.groups[0]?.total || 1;
          const tooltip = `${group.group}\nAwaiting Picking: ${num(group.awaiting)}\nReady to Print: ${num(group.ready)}\nTotal Load: ${num(group.total)}\nProduction Mix: ${dec(group.percent)}%\nOrders: ${num(group.orders)}\nSKUs: ${num(group.skus)}`;
          return <article key={group.group} title={tooltip}>
            <div className="mix-total"><strong>{num(group.total)}</strong><span>{dec(group.percent)}%</span></div>
            <div className="mix-bar-space"><div className="mix-bar" style={{height:`${Math.max(1, group.total / maximum * 100)}%`}}>
              {group.ready > 0 && <i className="ready" style={{height:`${group.ready / group.total * 100}%`}}>{group.ready / maximum >= .06 && <b>{num(group.ready)}</b>}</i>}
              {group.awaiting > 0 && <i className="awaiting" style={{height:`${group.awaiting / group.total * 100}%`}}>{group.awaiting / maximum >= .06 && <b>{num(group.awaiting)}</b>}</i>}
            </div></div>
            <h4>{group.group}</h4>{mixView==="garment"?<small>{num(group.orders)} orders · {num(group.skus)} SKUs</small>:<small>{"detail" in group?group.detail:""}</small>}
          </article>;
        })}
        {data.productionMix.groups.length === 0 && <p className="mix-empty">No production load matches the selected filters.</p>}
      </div>
    </section>

    <section className="capacity-section">
      <div className="section-title"><div><p className="eyebrow">Load versus capacity</p><h3>Daily and weekly position</h3></div><span className={dailyLoad > 100 ? "pressure" : "available"}>{dailyLoad > 100 ? "Capacity pressure" : "Capacity available"}</span></div>
      <div className="capacity-pair">
        <article><header><span>Daily</span><small>One working day</small></header><div className="capacity-kpis"><div><span>Demand</span><strong>{num(demand)}</strong></div><div><span>Capacity</span><strong>{num(capacity)}</strong></div><div><span>Load</span><strong className={dailyLoad > 100 ? "over" : "under"}>{num(dailyLoad)}%</strong></div><div><span>Lead time</span><strong>{dec(lead)} d</strong></div><div><span>Gap</span><strong className={demand > capacity ? "negative" : "positive"}>{num(capacity - demand)}</strong></div></div></article>
        <article><header><span>Weekly</span><small>{productionDays} production days</small></header><div className="capacity-kpis"><div><span>Demand</span><strong>{num(demand)}</strong></div><div><span>Capacity</span><strong>{num(weeklyCapacity)}</strong></div><div><span>Load</span><strong className={weeklyLoad > 100 ? "over" : "under"}>{num(weeklyLoad)}%</strong></div><div><span>Lead time</span><strong>{dec(weeklyCapacity ? demand / weeklyCapacity : 0)} wk</strong></div><div><span>Gap</span><strong className={demand > weeklyCapacity ? "negative" : "positive"}>{num(weeklyCapacity - demand)}</strong></div></div></article>
      </div>
      <div className="mapping-note"><b>Pipeline forecast</b><span>Confirmed {num(confirmedDemand)} + estimated {num(forecastDemand)} prints. Current global ratio: {dec(total.fr)} prints/garment; product-level coverage: {num(total.fc * 100)}%.</span></div>
    </section>

    <section className="runway">
      <div className="section-title"><div><p className="eyebrow">Dynamic production runway</p><h3>{productionDays}-day production outlook</h3></div><div className="weekend-flags"><Link className={saturday?"on":""} href={`?sat=${saturday?0:1}&sun=${sunday?1:0}`}>Saturday {saturday?"ON":"OFF"}</Link><Link className={sunday?"on":""} href={`?sat=${saturday?1:0}&sun=${sunday?0:1}`}>Sunday {sunday?"ON":"OFF"}</Link></div></div>
      <p className="runway-explain">Starting <b>{dayLabel(dates[0])}</b> with <b>{num(demand)} prints</b>. At the current capacity, the complete pipeline needs <b>{dec(lead)} production days</b>{carryover > 0 ? ` and ${num(carryover)} prints remain after this runway.` : " and clears within this runway."}</p>
      <div className="runway-kpis"><div><span>Ready to print</span><strong>{num(confirmedDemand)}</strong><small>confirmed</small></div><div><span>Waiting for pick</span><strong>≈ {num(forecastDemand)}</strong><small>forecast</small></div><div><span>Total workload</span><strong>{num(demand)}</strong><small>prints</small></div><div><span>Daily capacity</span><strong>{num(capacity)}</strong><small>prints/day</small></div><div><span>After {runway.at(-1)?.day}</span><strong>{num(carryover)}</strong><small>{carryover ? "remaining" : "cleared"}</small></div></div>
      <div className="runway-chart">{runway.map(r => <article key={r.day}><div className="bar-space"><i style={{height:`${Math.max(r.end ? 5 : 1,demand ? r.end/demand*100 : 0)}%`}}/><span>{num(r.end)}</span></div><strong>{r.day}</strong><small>left after production</small></article>)}</div>
      <div className="runway-table-wrap"><table className="runway-table runway-readable"><colgroup><col className="day-col"/><col/><col/><col/><col className="process-col"/></colgroup><thead><tr><th>Production day</th><th>Opening backlog</th><th>Planned output</th><th>Closing backlog</th><th>Work sequence</th></tr></thead><tbody>{runway.map(r => <tr key={r.day}><th>{r.day}</th><td>{num(r.start)}</td><td className="output-cell">− {num(r.output)}</td><td className={r.end ? "negative" : "positive"}>{num(r.end)}</td><td><span className={`process-pill ${r.confirmedStart > 0 ? "confirmed" : "forecast"}`}>{r.confirmedStart > 0 ? "Ready to print first" : "To Pick forecast"}</span></td></tr>)}</tbody></table></div>
    </section>
  </div></AppShell>;
}
