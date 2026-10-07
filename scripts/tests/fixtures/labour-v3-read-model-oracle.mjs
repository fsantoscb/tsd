// TEST ONLY: explicit selection join and contract state machine. Does not
// choose source snapshots, recompute fingerprints, classify rules or metrics.
const key=c=>JSON.stringify([c.organization_id,c.person_key,c.payroll_week]);
export function project(segments,selections,generations){
  const selected=new Map(selections.filter(c=>c.enabled).map(c=>[key(c),c]));
  if(selected.size!==selections.filter(c=>c.enabled).length)throw Error('DUPLICATE_SELECTION_KEY');
  const eligible=new Set(generations.filter(g=>g.status==='READY'&&g.validation_complete).map(g=>g.id));
  const rows=segments.flatMap(s=>{
    const c=selected.get(key({...s,payroll_week:s.week_start}));
    return c&&c.generation_id===s.generation_id&&eligible.has(s.generation_id)?[{...s,selection_version:c.selection_version}]:[];
  });
  const common=['id','organization_id','generation_id','source_timesheet_row_id','person_key','area_code','segment_start','segment_end'];
  const fields=(s,names)=>Object.fromEntries(names.map(n=>[n,s[n]]));
  const employee=rows.map(s=>({...fields(s,[...common,'employee_shift_code','employee_operational_date','paid_hours','paid_break_hours','productive_hours','regular_hours','overtime_hours']),
    payroll_week:s.week_start,...fields(s,['approval_status','calculation_version','scheduled_start_at','scheduled_end_at','selection_version'])}));
  const window=rows.map(s=>({...fields(s,[...common,'window_shift_code','window_operational_date','employee_shift_code','employee_operational_date']),
    employee_payroll_week:s.week_start,...fields(s,['productive_hours','paid_hours','paid_break_hours']),
    employee_regular_hours:s.regular_hours,employee_overtime_hours:s.overtime_hours,
    ...fields(s,['approval_status','calculation_version','selection_version'])}));
  return {shared:rows,employee,window};
}
export function cas(previous,request){
  if(!/^(0|[1-9][0-9]*)$/.test(request.expectedVersion))throw Error('INVALID_SELECTION_REQUEST');
  if(previous){
    if(previous.generation!==request.expectedGeneration||previous.version!==request.expectedVersion)throw Error('CAS_CONFLICT');
    if(previous.version==='9223372036854775807')throw Error('SELECTION_VERSION_EXHAUSTED');
    if(!request.enabled&&request.generation!==previous.generation)throw Error('DISABLE_CANNOT_REPLACE_GENERATION');
  }else if(request.expectedGeneration!==null||request.expectedVersion!=='0'||!request.enabled)throw Error('CAS_CONFLICT');
  return {generation:request.generation,version:(BigInt(previous?.version??'0')+1n).toString(),enabled:request.enabled};
}
// Takes an already-resolved authoritative domain and full-manifest read evidence.
// Never chooses FULL snapshots, hashes HR raws or resolves effective shift rules.
export function certificate(input){
  if(!['repeatable read','serializable'].includes(input.isolation)||!input.readOnly)throw Error('CONSISTENT_READ_ONLY_TRANSACTION_REQUIRED');
  const statuses=new Set(input.domain.coverageStatuses),vector=[],checks=[],checked=new Set();
  const required=input.domain.requiredCohorts.map(c=>({...c}));
  const all=[...new Map([...required,...input.observedCohorts].map(c=>[JSON.stringify([c.personKey,c.weekStart]),c])).values()];
  for(const c of all){
    const s=input.selections.find(s=>s.enabled&&s.personKey===c.personKey&&s.weekStart===c.weekStart);
    if(!s){statuses.add(c.weekStart<input.firstWeek?'PARTIAL_PREVIOUS_COHORT':c.weekStart>input.lastWeek?'PARTIAL_NEXT_COHORT':'MISSING_COHORT');continue;}
    vector.push({personKey:s.personKey,weekStart:s.weekStart,generationId:s.generationId,selectionVersion:s.selectionVersion});
    if(checked.has(s.generationId))continue;
    checked.add(s.generationId);const g=input.generations[s.generationId];let failure;
    if(!g||g.status!=='READY'||!g.validationComplete||g.algorithm!=='LABOUR_V3_STAGE2_V1')failure='INELIGIBLE_GENERATION';
    else if(g.storedAuthority!==g.currentAuthority||g.storedRules!==g.currentRules||JSON.stringify(g.manifest)!==JSON.stringify(g.recertifiedManifest))failure='STALE_GENERATION';
    if(failure){statuses.add('STALE_GENERATION');checks.push({generationId:s.generationId,valid:false,failure});}
    else checks.push({generationId:s.generationId,authorityFingerprint:g.storedAuthority,ruleFingerprint:g.storedRules,rawCount:g.rawCount,segmentCount:g.segmentCount,valid:true});
  }
  const sorted=statuses.size?[...statuses].sort():['CERTIFIED_COMPLETE'];
  return {statuses:sorted,blocking:statuses.has('AUTHORITY_AMBIGUOUS')||statuses.has('STALE_GENERATION'),
    certifiedComplete:sorted.length===1&&sorted[0]==='CERTIFIED_COMPLETE',requiredCohorts:required,selectionVector:vector,generationChecks:checks};
}
