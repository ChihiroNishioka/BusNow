import * as cheerio from "cheerio";
import type { ApproachSighting, SourceStatus } from "./types";
import { fetchText } from "./http";
import { compactRoute, htmlToText, normalizeDigits } from "./text";

/**
 * 東急バスナビの路線別運行情報（溝22、RAMK=61）。
 * 停留所の接近ページは富士見台の手前6停留所までしか出さない。
 * 子母口住宅前や鷹巣橋の (折)溝口南行はそこに入らないので、路線図の方を読む。
 * 溝の口を上、蟹ヶ谷を下に描き、左（上向き）が溝口南行。
 */
export const TOKYU_FUJIMIDAI_URL =
  "https://tokyu.bus-location.jp/blsys/navi?VID=rsc&EID=nt&RAMK=61&SCT=2&DSMK=2994&DSN=%E5%AF%8C%E5%A3%AB%E8%A6%8B%E5%8F%B0%EF%BC%88%E9%AB%98%E6%B4%A5%E5%8C%BA%EF%BC%89&ASMK=2991&ASN=%E6%BA%9D%E3%81%AE%E5%8F%A3%E9%A7%85%E5%8D%97%E5%8F%A3&FDSN=0&FASN=0&CTYP=0";

export function parseTokyuApproach(html: string): {
  buses: ApproachSighting[];
  updatedAt: string | null;
  pageError: string | null;
} {
  if (/セッションタイムアウト|ページが見つかりません/.test(html)) {
    return {
      buses: [],
      updatedAt: null,
      pageError: "東急バスナビのセッションを開始できませんでした",
    };
  }
  if (!html.includes("バス接近情報") && !html.includes("富士見台")) {
    return {
      buses: [],
      updatedAt: null,
      pageError: "東急バスナビの接近ページではありません",
    };
  }

  const $ = cheerio.load(html);
  const plain = htmlToText(html);
  const updated = plain.match(/(\d{1,2}:\d{2})\s*時点/);
  const buses: ApproachSighting[] = [];

  if ($("table.routeListTbl").length > 0) {
    for (const item of busesOnRouteDiagram($)) {
      buses.push({ ...item, id: `${item.id}-${buses.length}` });
    }
  } else if ($("#selectStop").length > 0) {
    for (const item of busesOnPhoneDiagram($)) {
      buses.push({ ...item, id: `${item.id}-${buses.length}` });
    }
  } else {
    $("td.businfo, td.colmsg").each((index, element) => {
      const fragment = $(element).html() ?? "";
      const text = normalizeDigits(htmlToText(fragment));
      if (!text || text === " ") return;
      for (const item of busesFromTokyuText(text)) {
        buses.push({ ...item, id: `${item.id}-${index}-${buses.length}` });
      }
    });
  }

  return {
    buses: dedupe(buses),
    updatedAt: updated?.[1] ?? null,
    pageError: null,
  };
}

/** PC 路線図。富士見台より下（まだ着いていない側）の左列だけが溝の口方面。 */
function busesOnRouteDiagram($: cheerio.CheerioAPI): ApproachSighting[] {
  return busesAfterFujimidai($("table.routeListTbl tr").toArray().map((row) => $(row)), (row) =>
    normalizeDigits(row.find("td.balloonL").text()),
  );
}

/** スマホ路線図。label-u が溝の口方面。 */
function busesOnPhoneDiagram($: cheerio.CheerioAPI): ApproachSighting[] {
  return busesAfterFujimidai($("tr").toArray().map((row) => $(row)), (row) =>
    normalizeDigits(row.find(".label-u").text()),
  );
}

function busesAfterFujimidai(
  rows: Array<ReturnType<cheerio.CheerioAPI>>,
  textOf: (row: ReturnType<cheerio.CheerioAPI>) => string,
): ApproachSighting[] {
  let sawFujimidai = false;
  const found: ApproachSighting[] = [];
  for (const row of rows) {
    const stop = normalizeDigits(row.find(".stopName, .stopnm").text()).replace(/\s/g, "");
    if (/^富士見台(?:[（(]|$)/.test(stop) || row.find("#selectStop").length > 0) {
      sawFujimidai = true;
      continue;
    }
    const text = textOf(row);
    if (!text) continue;
    if (sawFujimidai) {
      const item = busTowardMizonokuchi(text);
      if (item) found.push(item);
    }
  }
  if (sawFujimidai) return found;
  return rows.flatMap((row) => {
    const item = busTowardMizonokuchi(textOf(row));
    return item ? [item] : [];
  });
}

/** 溝口南行と (折)溝口南行。蟹ヶ谷行は反対方向なので捨てる。 */
function busTowardMizonokuchi(text: string): ApproachSighting | null {
  const match = text.match(
    /((?:\(折\)|（折）)\s*)?(溝口\S{0,8}行)\s*(?:(\d{1,2})\s*分待ち|まもなく)/,
  );
  if (!match) return null;
  const destination = `${match[1] ? "(折)" : ""}${match[2]}`;
  const soon = match[3] == null;
  const minutes = soon ? 0 : Number(match[3]);
  return bus("溝22", destination, minutes, soon ? "まもなく" : `${minutes}分待ち`);
}

function busesFromTokyuText(text: string): ApproachSighting[] {
  const found: ApproachSighting[] = [];
  const wait = /溝\s*([0-9]{2})([\s\S]{0,40}?)([0-9]{1,2})\s*分待ち/g;
  for (const match of text.matchAll(wait)) {
    found.push(
      bus(`溝${match[1]}`, destinationFrom(match[2]), Number(match[3]), `${Number(match[3])}分待ち`),
    );
  }
  const soon = /溝\s*([0-9]{2})([\s\S]{0,40}?)まもなく/g;
  for (const match of text.matchAll(soon)) {
    found.push(bus(`溝${match[1]}`, destinationFrom(match[2]), 0, "まもなく"));
  }
  return found;
}

function destinationFrom(chunk: string): string {
  const cleaned = chunk.replace(/[【】]/g, " ").replace(/\s+/g, "");
  const bound = cleaned.match(/([^\d]{1,16})行/);
  if (bound) return bound[1].replace(/行き?$/, "") + "行";
  return "溝の口方面";
}

function bus(
  route: string,
  destination: string,
  minutes: number,
  status: string,
): ApproachSighting {
  return {
    id: `tokyu-${compactRoute(route)}-${minutes}-${status}`,
    operator: "東急バス",
    route: compactRoute(route),
    destination,
    minutes,
    status,
  };
}

function dedupe(buses: ApproachSighting[]): ApproachSighting[] {
  const seen = new Set<string>();
  return buses.filter((item) => {
    if (seen.has(item.id)) return false;
    seen.add(item.id);
    return true;
  });
}

export async function loadTokyuApproach(): Promise<{
  buses: ApproachSighting[];
  source: SourceStatus;
}> {
  try {
    const html = await fetchText(TOKYU_FUJIMIDAI_URL);
    const parsed = parseTokyuApproach(html);
    if (parsed.pageError) {
      return {
        buses: [],
        source: {
          operator: "東急バス",
          ok: false,
          message: parsed.pageError,
          updatedAt: null,
        },
      };
    }
    const empty =
      parsed.buses.length === 0 ? "接近しているバスはありません" : null;
    return {
      buses: parsed.buses,
      source: {
        operator: "東急バス",
        ok: true,
        message: empty,
        updatedAt: parsed.updatedAt,
      },
    };
  } catch (error) {
    return {
      buses: [],
      source: {
        operator: "東急バス",
        ok: false,
        message: error instanceof Error ? error.message : "取得に失敗しました",
        updatedAt: null,
      },
    };
  }
}
