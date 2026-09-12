export const PRODUCTION_TIMEZONE = "Australia/Brisbane";

export type ShiftCode = "SHIFT_1" | "SHIFT_2" | "SHIFT_3" | "OUT_OF_SHIFT";
export type ShiftRule = { weekday: number; shiftCode: Exclude<ShiftCode, "OUT_OF_SHIFT">; startMinute: number; endMinute: number; crossMidnight: boolean; toleranceMinutes: number };
export type ShiftResolution = { shift: ShiftCode; calendarDate: string; operationalDate: string; isOperationalOvertime: boolean; usedEarlyTolerance: boolean };
export type ShiftResolverOptions = { activeShiftCodes?: ReadonlySet<string>; confirmedShiftCodes?: ReadonlySet<string>; applyEarlyTolerance?: boolean; shift3Compatibility?: boolean };

const pad = (value: number) => String(value).padStart(2, "0");
const dateParts = (date: Date) => Object.fromEntries(new Intl.DateTimeFormat("en-CA", { timeZone: PRODUCTION_TIMEZONE, year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).formatToParts(date).filter(part => part.type !== "literal").map(part => [part.type, Number(part.value)])) as Record<string, number>;
const dateString = (year: number, month: number, day: number) => `${year}-${pad(month)}-${pad(day)}`;
const shiftDate = (date: string, days: number) => { const value = new Date(`${date}T12:00:00Z`); value.setUTCDate(value.getUTCDate() + days); return dateString(value.getUTCFullYear(), value.getUTCMonth() + 1, value.getUTCDate()); };
const weekday = (date: string) => { const value = new Date(`${date}T12:00:00Z`).getUTCDay(); return value === 0 ? 7 : value; };

export function resolveProductionShift(eventUtc: Date, rules: readonly ShiftRule[], options: ShiftResolverOptions = {}): ShiftResolution {
  const parts = dateParts(eventUtc);
  const calendarDate = dateString(parts.year, parts.month, parts.day);
  const minute = parts.hour * 60 + parts.minute;
  const currentDay = weekday(calendarDate);
  const previousDate = shiftDate(calendarDate, -1);
  const previousDay = weekday(previousDate);
  if (options.applyEarlyTolerance) {
    const early = rules.find(rule => rule.weekday === currentDay && minute >= rule.startMinute - rule.toleranceMinutes && minute < rule.startMinute && options.activeShiftCodes?.has(rule.shiftCode));
    if (early) return { shift: early.shiftCode, calendarDate, operationalDate: calendarDate, isOperationalOvertime: false, usedEarlyTolerance: true };
  }
  const candidate = rules.find(rule => rule.weekday === currentDay && (!rule.crossMidnight ? minute >= rule.startMinute && minute < rule.endMinute : minute >= rule.startMinute))
    ?? rules.find(rule => rule.weekday === previousDay && rule.crossMidnight && minute < rule.endMinute);

  if (candidate) {
    const operationalDate = candidate.crossMidnight && minute < candidate.endMinute ? previousDate : calendarDate;
    if (candidate.shiftCode === "SHIFT_3" && options.shift3Compatibility && !options.confirmedShiftCodes?.has("SHIFT_3")) {
      return { shift: "SHIFT_2", calendarDate, operationalDate, isOperationalOvertime: true, usedEarlyTolerance: false };
    }
    return { shift: candidate.shiftCode, calendarDate, operationalDate, isOperationalOvertime: false, usedEarlyTolerance: false };
  }

  return { shift: "OUT_OF_SHIFT", calendarDate, operationalDate: calendarDate, isOperationalOvertime: false, usedEarlyTolerance: false };
}

const rule = (weekday: number, shiftCode: ShiftRule["shiftCode"], startMinute: number, endMinute: number, crossMidnight = false): ShiftRule => ({ weekday, shiftCode, startMinute, endMinute, crossMidnight, toleranceMinutes: 20 });
export const DEFAULT_SHIFT_RULES: ShiftRule[] = [1,2,3,4,6,7].flatMap(day => [rule(day,"SHIFT_1",360,870),rule(day,"SHIFT_2",870,1380),rule(day,"SHIFT_3",1380,360,true)]).concat([rule(5,"SHIFT_1",360,720),rule(5,"SHIFT_2",720,1080),rule(5,"SHIFT_3",1080,1380)]);
