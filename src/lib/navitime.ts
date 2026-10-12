import * as cheerio from "cheerio";
import type { DayKind } from "./tokyo-time";
import { htmlToText } from "./text";

export type TimetableColumns = Record<DayKind, string[]>;

const EMPTY: TimetableColumns = { weekday: [], saturday: [], holiday: [] };

/**
 * 東急バス公式時刻表（NAVITIME 連携の Diagram / DiagramIF）。
 * セル本文は「02 2分はつ 溝22…」の形になる。タグは空白にしてから分はつを拾う。
 */
export function parseNavitimeDiagram(html: string): TimetableColumns {
  const $ = cheerio.load(html);
  const columns: TimetableColumns = { weekday: [], saturday: [], holiday: [] };
  let indexes: Partial<Record<DayKind, number>> | null = null;

  $("tr").each((_, row) => {
    const cells = $(row).children("th,td");
    if (cells.length < 2) return;
    const labels = cells.toArray().map((cell) => htmlToText($(cell).html() ?? $(cell).text()));
    if (labels.some((label) => label.includes("平日"))) {
      indexes = {};
      labels.forEach((label, index) => {
        if (label.includes("平日")) indexes!.weekday = index;
        if (label.includes("土曜")) indexes!.saturday = index;
        if (label.includes("休日")) indexes!.holiday = index;
      });
      return;
    }
    if (!indexes) return;
    const hourMatch = labels[0]?.match(/(\d{1,2})/);
    if (!hourMatch) return;
    const hour = Number(hourMatch[1]);
    if (hour > 27) return;
    (Object.keys(indexes) as DayKind[]).forEach((kind) => {
      const index = indexes?.[kind];
      if (index == null) return;
      const cellHtml = $(cells[index]).html() ?? "";
      const text = cellHtml.replace(/<[^>]+>/g, " ").replace(/&nbsp;/gi, " ");
      for (const match of text.matchAll(/(\d{1,2})\s*分はつ/g)) {
        const minute = Number(match[1]);
        if (minute > 59) continue;
        columns[kind].push(
          `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`,
        );
      }
    });
  });

  if (columns.weekday.length === 0 && columns.saturday.length === 0) {
    return EMPTY;
  }
  return columns;
}
