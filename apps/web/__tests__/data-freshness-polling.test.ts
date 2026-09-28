import {afterEach,beforeEach,describe,expect,it,vi} from "vitest";
import {startFreshnessPolling} from "../components/data-freshness-status";

function visibility(initial:DocumentVisibilityState="visible"){
  const surface=Object.assign(new EventTarget(),{visibilityState:initial});
  return {
    surface,
    set(value:DocumentVisibilityState){surface.visibilityState=value;surface.dispatchEvent(new Event("visibilitychange"));},
  };
}

describe("DataFreshnessStatus polling",()=>{
  beforeEach(()=>vi.useFakeTimers());
  afterEach(()=>vi.useRealTimers());

  it("fetches once on an initially visible mount, then once per 60 seconds",async()=>{
    const tab=visibility();
    const fetchStatus=vi.fn(async()=>{});
    const polling=startFreshnessPolling(fetchStatus,tab.surface);
    expect(fetchStatus).toHaveBeenCalledTimes(1);
    await vi.advanceTimersByTimeAsync(59_999);
    expect(fetchStatus).toHaveBeenCalledTimes(1);
    await vi.advanceTimersByTimeAsync(1);
    expect(fetchStatus).toHaveBeenCalledTimes(2);
    polling.stop();
  });

  it("does not fetch or run a timer while hidden",async()=>{
    const tab=visibility("hidden");
    const fetchStatus=vi.fn(async()=>{});
    const polling=startFreshnessPolling(fetchStatus,tab.surface);
    expect(vi.getTimerCount()).toBe(0);
    await vi.advanceTimersByTimeAsync(180_000);
    expect(fetchStatus).not.toHaveBeenCalled();
    polling.stop();
  });

  it("refreshes immediately on becoming visible and resumes one timer",async()=>{
    const tab=visibility("hidden");
    const fetchStatus=vi.fn(async()=>{});
    const polling=startFreshnessPolling(fetchStatus,tab.surface);
    tab.set("visible");
    expect(fetchStatus).toHaveBeenCalledTimes(1);
    expect(vi.getTimerCount()).toBe(1);
    await vi.advanceTimersByTimeAsync(60_000);
    expect(fetchStatus).toHaveBeenCalledTimes(2);
    polling.stop();
  });

  it("stops hidden polling and never stacks timers across visibility events",async()=>{
    const tab=visibility();
    const fetchStatus=vi.fn(async()=>{});
    const polling=startFreshnessPolling(fetchStatus,tab.surface);
    tab.set("hidden");
    expect(vi.getTimerCount()).toBe(0);
    await vi.advanceTimersByTimeAsync(120_000);
    expect(fetchStatus).toHaveBeenCalledTimes(1);
    tab.set("visible");
    tab.set("visible");
    expect(fetchStatus).toHaveBeenCalledTimes(2);
    expect(vi.getTimerCount()).toBe(1);
    await vi.advanceTimersByTimeAsync(60_000);
    expect(fetchStatus).toHaveBeenCalledTimes(3);
    polling.stop();
  });

  it("removes the listener and timer on unmount",async()=>{
    const tab=visibility();
    const fetchStatus=vi.fn(async()=>{});
    const polling=startFreshnessPolling(fetchStatus,tab.surface);
    polling.stop();
    expect(vi.getTimerCount()).toBe(0);
    tab.set("hidden");tab.set("visible");
    await vi.advanceTimersByTimeAsync(180_000);
    expect(fetchStatus).toHaveBeenCalledTimes(1);
  });

  it("coalesces rapid hide/show while a request is in flight",async()=>{
    const tab=visibility();
    let complete!:()=>void;
    const first=new Promise<void>(resolve=>{complete=resolve;});
    const fetchStatus=vi.fn().mockReturnValueOnce(first).mockResolvedValue(undefined);
    const polling=startFreshnessPolling(fetchStatus,tab.surface);
    tab.set("hidden");tab.set("visible");tab.set("hidden");tab.set("visible");
    await vi.advanceTimersByTimeAsync(60_000);
    expect(fetchStatus).toHaveBeenCalledTimes(1);
    complete();
    await Promise.resolve();await Promise.resolve();
    expect(fetchStatus).toHaveBeenCalledTimes(2);
    polling.stop();
  });
});
