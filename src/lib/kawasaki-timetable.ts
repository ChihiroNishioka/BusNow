import * as cheerio from "cheerio";
import type { DayKind } from "./tokyo-time";
import { DAY_LABEL } from "./tokyo-time";
import { fetchFormJson, fetchText } from "./http";
import { compactRoute } from "./text";

const INDEX_URL = "https://kcbn.bus-navigation.jp/wgsys/wgp/timeTableRouteTab.htm";
const FILE_URL = "https://kcbn.bus-navigation.jp/wgsys/wgp/timeTableRouteTabFile.htm";

/**
 * 溝口駅南口 1番のりば側（標柱 145384）。
 * 経路ページで溝21・溝23・溝25・溝15・溝18が富士見台を経由することを確認した。
 */
const SIGNPOLE_KEY = "145384";

export const KAWASAKI_TIMETABLE_URL =
  "https://kcbn.bus-navigation.jp/wgsys/wgp/bus.htm?from=%E6%BA%9D%E5%8F%A3%E9%A7%85%E5%8D%97%E5%8F%A3&fromType=1&fromSignpoleKey=145384&locale=ja&tabName=timetableRouteTab";

type IndexRow = {
  timeTableRollsignNameJP?: string;
  timeTableDestinationNameJP?: string;
  noteJP?: string | null;
  timeTableHtmlList?: string[];
  timeTableHtmlListLink?: string[];
};

type IndexResponse = {
  timeTableRouteDestinationSubData?: IndexRow[] | null;
};

type FileResponse = {
  filePath?: string | null;
  errorFlg?: string | null;
};

export type ScheduledTrip = {
  operator: "川崎市バス";
  route: string;
  destination: string;
  dayKind: DayKind;
  time: string;
};

const cache = new Map<string, { at: number; trips: ScheduledTrip[] }>();
const TEN_MINUTES = 10 * 60 * 1000;

/**
 * 川崎市の時刻表 HTML は、時のセルと、その右の入れ子表に分がある。
 * 例: 6時 の行の内側に 08分 と 52分。
 */
export function parseKawasakiTimetableHtml(html: string): string[] {
  const $ = cheerio.load(html);
  const times: string[] = [];
  $("tr").each((_, row) => {
    const cells = $(row).children("td");
    if (cells.length < 2) return;
    const hourText = cells.first().text();
    if (!hourText.includes("時")) return;
    const hourMatch = hourText.match(/(\d{1,2})/);
    if (!hourMatch) return;
    const hour = Number(hourMatch[1]);
    if (hour > 27) return;
    const minuteText = cells.eq(1).text().replace(/\u3000/g, " ");
    for (const match of minuteText.matchAll(/(\d{1,2})\s*分/g)) {
      const minute = Number(match[1]);
      if (minute > 59) continue;
      times.push(
        `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`,
      );
    }
  });
  return times;
}

export async function loadKawasakiDepartures(
  kinds: DayKind[],
): Promise<ScheduledTrip[]> {
  const key = kinds.slice().sort().join(",");
  const hit = cache.get(key);
  if (hit && Date.now() - hit.at < TEN_MINUTES) return hit.trips;

  const index = await fetchFormJson<IndexResponse>(INDEX_URL, {
    from: "溝口駅南口",
    fromType: "1",
    fromSignpoleKey: SIGNPOLE_KEY,
    locale: "ja",
    tabName: "timetableRouteTab",
    nextDiagramFlag: "0",
    language: "ja",
  });
  const rows = index.timeTableRouteDestinationSubData ?? [];
  if (rows.length === 0) {
    throw new Error("川崎市バスの時刻表一覧が空でした");
  }

  const jobs: Array<Promise<ScheduledTrip[]>> = [];
  for (const row of rows) {
    const route = compactRoute(row.timeTableRollsignNameJP ?? "");
    const place = compactRoute(row.timeTableDestinationNameJP ?? "");
    const destination = place
      ? place.endsWith("行き")
        ? place
        : `${place}行き`
      : "";
    const note = compactRoute(row.noteJP ?? "");
    const labels = row.timeTableHtmlList ?? [];
    const links = row.timeTableHtmlListLink ?? [];
    for (const kind of kinds) {
      const label = DAY_LABEL[kind];
      const indexOfKind = labels.findIndex((item) => item.includes(label));
      const link = links[indexOfKind];
      if (!link) continue;
      jobs.push(
        loadOne(link, kind, route, note ? `${destination}（${note}）` : destination),
      );
    }
  }

  const trips = (await Promise.all(jobs)).flat();
  cache.set(key, { at: Date.now(), trips });
  return trips;
}

async function loadOne(
  link: string,
  dayKind: DayKind,
  route: string,
  destination: string,
): Promise<ScheduledTrip[]> {
  const [date, name] = link.split(",");
  const meta = await fetchFormJson<FileResponse>(FILE_URL, {
    type: "0",
    date,
    name,
  });
  if (!meta.filePath || meta.errorFlg === "1") {
    throw new Error(`時刻表ファイルがありません: ${name}`);
  }
  const url = `https://kcbn.bus-navigation.jp/wgsys${meta.filePath}`;
  const html = await fetchText(url);
  return parseKawasakiTimetableHtml(html).map((time) => ({
    operator: "川崎市バス" as const,
    route,
    destination: destination || "富士見台方面",
    dayKind,
    time,
  }));
}
