import{describe,expect,it}from"vitest";
import{isDtgDispatch,isDtgPicking,isDtgPrinting,isDtgPutwall,isUpDispatch,isUpPicking,isUpPrinting}from"../src/source-flow-rules";

describe("canonical source flow rules",()=>{
 it("classifies exact DTG stages",()=>{expect(isDtgPicking(" sp11 ")).toBe(true);expect(isDtgPrinting("PCOR")).toBe(true);expect(isDtgPutwall("pwl1")).toBe(true);expect(isDtgDispatch("DTGMOVE")).toBe(true)});
 it("rejects broad DTG matches",()=>{expect(isDtgPicking("SP110")).toBe(false);expect(isDtgPrinting("PCOR HOLD")).toBe(false);expect(isDtgPutwall("PWL10")).toBe(false);expect(isDtgDispatch("DTGMOVE-OLD")).toBe(false)});
 it("separates UP picking, printing and dispatch",()=>{expect(isUpPicking("UNDERPRINT")).toBe(true);expect(isUpPrinting("CHERAYUP")).toBe(true);expect(isUpDispatch("UPMOVE")).toBe(true);expect(isUpPicking("UNDERPRINT-OLD")).toBe(false);expect(isUpPrinting("UPMOVE")).toBe(false)});
});
