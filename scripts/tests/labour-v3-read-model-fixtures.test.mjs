// Disconnected projection oracle only. No authority chooser or runtime export.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const f=JSON.parse(readFileSync(new URL('./fixtures/labour-v3-read-model.json',import.meta.url),'utf8'));
const selected=(segments,selections)=>segments.filter(s=>selections.some(c=>c.enabled && ['organization','person','week','generation'].every(k=>c[k]===s[k])));
test('explicit selection includes all areas only for the requested cohort',()=>{
  const rows=selected(f.synthetic.segments,f.synthetic.selections);
  assert.deepEqual(rows.map(x=>x.id),['S1','S2']);
  assert.deepEqual(rows.map(x=>x.area),['DTG','UP']);
  assert.equal(new Set(rows.map(x=>x.id)).size,rows.length);
});
test('tombstone exposes no segments, alternate READY does not win',()=>{
  assert.equal(selected(f.synthetic.segments,[{...f.synthetic.selections[0],enabled:false,version:2}]).length,0);
  assert.equal(selected(f.synthetic.segments,[{...f.synthetic.selections[0],generation:'G2-ALTERNATE',version:3}])[0].id,'COMPETING-READY');
});
test('same set projects Employee ownership and physical Window without reallocating hours',()=>{
  const rows=selected(f.synthetic.segments,f.synthetic.selections);
  assert.deepEqual(rows.map(s=>s.employeeShift),['SHIFT_1','SHIFT_1']);
  assert.deepEqual(rows.map(s=>s.windowShift),['SHIFT_1','SHIFT_2']);
  assert.equal(rows[0].end,rows[1].start);
  assert.equal(rows.reduce((n,s)=>n+s.productive,0),11/12);
});
test('recorded 28 Sep boundary expectations conserve combined productive hours',()=>{
  assert.ok(Math.abs(f.boundary.windowA+f.boundary.windowB-f.boundary.legacyTotal)<1e-9);
  assert.equal(f.spillover.length,2);
  assert.ok(f.spillover.every(x=>x.productive>0));
});
test('known missing contribution is diagnostic only, never fabricated as a segment',()=>{
  assert.deepEqual(f.coverage[0].statuses,['PARTIAL_PREVIOUS_COHORT']);
  assert.ok(f.coverage[0].observedScreenRoomA>0);
  assert.equal(f.synthetic.segments.some(s=>s.id==='MISSING-PREVIOUS-GENERATION'),false);
  assert.equal(f.coverage[1].certifiedComplete,false);
});
