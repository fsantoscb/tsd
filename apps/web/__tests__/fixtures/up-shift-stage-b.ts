// Mirrors Stage B UP_SHIFT_DAILY_V1, including row snapshot IDs and coverage.
export function upShiftFixture(){
 const sourceSnapshotId='00000000-0000-4000-8000-000000000002';
 const rows=[
  {shiftCode:'SHIFT_1',garments:663.053,sourceEventCount:20,sourceMaxEventAt:'2026-09-30T13:52:57+10:00'},
  {shiftCode:'SHIFT_2',garments:763.106,sourceEventCount:17,sourceMaxEventAt:'2026-09-30T19:50:03+10:00'},
  {shiftCode:'SHIFT_3',garments:16,sourceEventCount:1,sourceMaxEventAt:'2026-10-01T05:58:37+10:00'},
 ].map(r=>({...r,operationalDate:'2026-09-30',calculationVersion:'UP_UNDERPRINT_EXIT_SHIFT_DAILY_V1',sourceSnapshotId}));
 return {organizationId:'00000000-0000-4000-8000-000000000001',from:'2026-09-30',to:'2026-10-01',contractVersion:'UP_SHIFT_DAILY_V1',sourceSnapshotId,sourceMaxEventAt:'2026-10-01T05:58:37+10:00',
  coverage:[{operationalDate:'2026-09-30',complete:true,hasActivity:true},{operationalDate:'2026-10-01',complete:true,hasActivity:false}],rows,
  dailySummaries:[{operationalDate:'2026-09-30',garments:1442.159,jobs:38,sourceEventCount:38,sourceMaxEventAt:'2026-10-01T05:58:37+10:00',calculationVersion:'UP_UNDERPRINT_EXIT_DAILY_V1',sourceSnapshotId}]};
}
