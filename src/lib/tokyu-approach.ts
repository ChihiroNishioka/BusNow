import * as cheerio from "cheerio";
import type { ApproachBus, SourceStatus } from "./types";
import { fetchText } from "./http";
import { compactRoute, htmlToText, normalizeDigits } from "./text";

/**
 * 東急バスナビ PC 接近情報。
 * 溝22（RAMK=61）富士見台（SKF=2994, 表示順4）→ 溝の口駅南口（SKS=2991, 表示順1）。
 * 確認日: 2026-10-12 にこの URL が
 * 「バス接近情報｜富士見台（高津区）→溝の口駅南口」を返した。
 */
export const TOKYU_FUJIMIDAI_URL =
  "https://tokyu.bus-location.jp/blsys/navi?VID=rsi&EID=nt&RAMK=61&SKF=2994&SKS=2991&DOF=4&DOS=1&SSC=2&DIF=true&SCT=1&ASMK=0&DPMK=0&DSMK=0&RMK=0&TOP=-1&FASN=0&FDSN=0";

export function parseTokyuApproach(html: string): {
  buses: ApproachBus[];
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
  const buses: ApproachBus[] = [];

  $("td.businfo, td.colmsg").each((index, element) => {
    const fragment = $(element).html() ?? "";
    const text = normalizeDigits(htmlToText(fragment));
    if (!text || text === " ") return;
    for (const item of busesFromTokyuText(text)) {
      buses.push({ ...item, id: `${item.id}-${index}-${buses.length}` });
    }
  });

  return {
    buses: dedupe(buses),
    updatedAt: updated?.[1] ?? null,
    pageError: null,
  };
}

function busesFromTokyuText(text: string): ApproachBus[] {
  const found: ApproachBus[] = [];
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
): ApproachBus {
  return {
    id: `tokyu-${compactRoute(route)}-${minutes}-${status}`,
    operator: "東急バス",
    route: compactRoute(route),
    destination,
    minutes,
    status,
  };
}

function dedupe(buses: ApproachBus[]): ApproachBus[] {
  const seen = new Set<string>();
  return buses.filter((item) => {
    if (seen.has(item.id)) return false;
    seen.add(item.id);
    return true;
  });
}

export async function loadTokyuApproach(): Promise<{
  buses: ApproachBus[];
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
