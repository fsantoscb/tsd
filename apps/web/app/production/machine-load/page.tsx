import { AppShell } from "@/components/app-shell";
import { machineLoad } from "@/lib/machine-load";
import Link from "next/link";

const num = (v: number) => v.toLocaleString("en-AU", { maximumFractionDigits: 0 });
const dec = (v: number) => v.toLocaleString("en-AU", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const brisbaneToday = () => new Date(`${new Intl.DateTimeFormat("en-CA", { timeZone: "Australia/Brisbane", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date())}T12:00:00Z`);
const dayLabel = (date: Date) => new Intl.DateTimeFormat("en-AU", { weekday: "short", day: "2-digit", month: "short", timeZone: "UTC" }).format(date);

type Params = { sat?:string; sun?:string; dueFrom?:string; dueTo?:string; customer?:string; order?:string; priority?:string; site?:string; mixGroup?:string; productType?:string };

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
    ro: s.ro + Number(r.ready_orders),
    rl: s.rl + Number(r.ready_locations),
    rb: s.rb + Number(r.ready_boxes),
    rg: s.rg + Number(r.ready_garments),
  }), { wg: 0, wp: 0, pg: 0, pp: 0, fp: 0, fr: 0, fc: 0, up: 0, ua: 0, ro: 0, rl: 0, rb: 0, rg: 0 });
  const capacity = data.dailyCapacity;
  const confirmedDemand = total.pp;
  const forecastDemand = total.fp;
  const demand = confirmedDemand + forecastDemand;
  const lead = capacity ? demand / capacity : 0;
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

  return <AppShell><div className="ops-dashboard">
    <section className="capacity-hero">
      <div><p className="eyebrow">Production control · live snapshot</p><h2>Machine load</h2><p>Consolidated flow from warehouse pick to DTG print.</p></div>
      <div className="capacity-lead"><span>DTG RELATIVE LEAD TIME</span><strong>{dec(lead)}</strong><small>working days at current capacity</small></div>
    </section>

    <section className="load-matrix">
      <div className="matrix-title"><span>Machine load</span><strong>PRINTS</strong><small>Live queue snapshot</small></div>
      <div className="matrix-groups">
        <article><header>Underprint</header><div className="matrix-cells"><div><span>UP to pick</span><b>{num(total.up)}</b><small>garments</small></div><div><span>UP to print</span><b>{num(total.ua)}</b><small>garments</small></div></div><footer><span>Workbank + Underprint stock</span><strong>{num(total.up + total.ua)}</strong></footer></article>
        <article className="primary"><header>DTG</header><div className="matrix-cells"><div><span>Pick · PG11</span><b>{num(total.wg)}</b><small>≈ {num(forecastDemand)} forecast prints</small></div><div><span>Blanks to print · DTGS</span><b>{num(total.pg)}</b><small>{num(confirmedDemand)} confirmed prints</small></div></div><footer><span>Confirmed + forecast pipeline</span><strong>{num(demand)}</strong></footer></article>
        <article><header>Dispatch</header><div className="matrix-cells four"><div><span>Released orders</span><b>{num(total.ro)}</b><small>ready to lift</small></div><div><span>Putwall locations</span><b>{num(total.rl)}</b><small>occupied locations</small></div><div><span>Boxes now</span><b>{num(total.rb)}</b><small>ready for lift</small></div><div><span>Total garments</span><b>{num(total.rg)}</b><small>ready to dispatch</small></div></div><footer><span>Current Ready to Lift snapshot</span><strong>{num(total.rg)} garments</strong></footer></article>
      </div>
      <div className="matrix-summary"><div><span>Confirmed demand</span><strong>{num(confirmedDemand)} prints</strong></div><div><span>To Pick forecast</span><strong>≈ {num(forecastDemand)} prints</strong></div><div><span>Total pipeline · lead</span><strong>{num(demand)} · {dec(lead)} days</strong></div></div>
    </section>

    <section className="production-mix">
      <div className="section-title"><div><p className="eyebrow">Physical workload profile</p><h3>Production Mix</h3><p className="mix-intro">Garments waiting for warehouse picking plus garments released to print. This view anticipates machine productivity impact.</p></div><span>{num(data.productionMix.total)} garments</span></div>
      <form className="mix-filters" method="get">
        <input type="hidden" name="sat" value={saturday ? "1" : "0"}/><input type="hidden" name="sun" value={sunday ? "1" : "0"}/>
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
      <div className="mix-legend"><span><i className="awaiting"/>Awaiting Picking · SP11</span><span><i className="ready"/>Ready to Print · PCOR</span></div>
      <div className="mix-chart" role="img" aria-label="Stacked production volume by production mix group">
        {data.productionMix.groups.map(group => {
          const maximum = data.productionMix.groups[0]?.total || 1;
          const tooltip = `${group.group}\nAwaiting Picking: ${num(group.awaiting)}\nReady to Print: ${num(group.ready)}\nTotal Load: ${num(group.total)}\nProduction Mix: ${dec(group.percent)}%\nOrders: ${num(group.orders)}\nSKUs: ${num(group.skus)}`;
          return <article key={group.group} title={tooltip}>
            <div className="mix-total"><strong>{num(group.total)}</strong><span>{dec(group.percent)}%</span></div>
            <div className="mix-bar-space"><div className="mix-bar" style={{height:`${Math.max(1, group.total / maximum * 100)}%`}}>
              {group.ready > 0 && <i className="ready" style={{height:`${group.ready / group.total * 100}%`}}>{group.ready / maximum >= .06 && <b>{num(group.ready)}</b>}</i>}
              {group.awaiting > 0 && <i className="awaiting" style={{height:`${group.awaiting / group.total * 100}%`}}>{group.awaiting / maximum >= .06 && <b>{num(group.awaiting)}</b>}</i>}
            </div></div>
            <h4>{group.group}</h4><small>{num(group.orders)} orders · {num(group.skus)} SKUs</small>
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
