import * as cheerio from "cheerio";
import type { ApproachSighting, SourceStatus } from "./types";
import { fetchText } from "./http";
import { compactRoute, htmlToText, normalizeDigits } from "./text";

/**
 * 川崎市バスナビ PC 接近情報。
 * 乗車 富士見台 → 降車 溝口駅南口。停留所名は市バス側の表記（溝口、の なし）。
 */
export function kawasakiApproachUrl(): string {
  const params = new URLSearchParams({
    from: "富士見台",
    fromType: "1",
    to: "溝口駅南口",
    toType: "1",
    locale: "ja",
    tabName: "searchTab",
    bsid: "1",
    mapFlag: "false",
    existYn: "N",
    nextDiagramFlag: "0",
  });
  return `https://kcbn.bus-navigation.jp/wgsys/wgp/bus.htm?${params.toString()}`;
}

export function parseKawasakiApproach(html: string): {
  buses: ApproachSighting[];
  updatedAt: string | null;
  message: string | null;
  pageError: string | null;
} {
  if (!html.includes("市バスナビ") && !html.includes("buslist")) {
    return {
      buses: [],
      updatedAt: null,
      message: null,
      pageError: "川崎市バスナビの接近ページではありません",
    };
  }
  const $ = cheerio.load(html);
  const updated = html.match(/fa-clock-o"\s*>\s*<\/i>\s*(\d{1,2}:\d{2})/);
  const notice = normalizeDigits($("#errInfo").text());
  const buses: ApproachSighting[] = [];

  $("#buslist .route_box").each((index, element) => {
    const box = $(element);
    const fragment = box.html() ?? "";
    const text = normalizeDigits(htmlToText(fragment));
    const route = routeFromBox($, box, text);
    if (!route) return;
    const destinationMatch = text.match(/(\S{1,24}?)\s*行き/);
    const minutesMatch = text.match(/約\s*([0-9]{1,2})\s*分で発車/);
    const soon = /まもなく/.test(text);
    const minutes = soon ? 0 : minutesMatch ? Number(minutesMatch[1]) : null;
    const status = soon
      ? "まもなく"
      : minutesMatch
        ? `約${minutes}分で発車`
        : "接近";
    buses.push({
      id: `kawasaki-${route}-${minutes ?? "x"}-${index}`,
      operator: "川崎市バス",
      route,
      destination: destinationMatch?.[1] ? `${destinationMatch[1]}行き` : "溝口駅南口方面",
      minutes,
      status,
    });
  });

  const noBus = /接近しているバスはありません/.test(notice);
  return {
    buses,
    updatedAt: updated?.[1] ?? null,
    message: noBus ? notice : buses.length === 0 ? notice || "接近しているバスはありません" : null,
    pageError: null,
  };
}

function routeFromBox($: cheerio.CheerioAPI, box: ReturnType<typeof $>, text: string): string {
  let route = "";
  box.find("font").each((_, element) => {
    if (route) return;
    const node = $(element);
    const color = `${node.attr("color") ?? ""} ${node.attr("style") ?? ""}`.toLowerCase();
    const blue =
      color.includes("blue") ||
      color.includes("#00f") ||
      color.includes("0000ff") ||
      color.includes("0000ee");
    if (!blue) return;
    const label = compactRoute(node.text());
    if (label) route = label;
  });
  if (route) return route;
  const match = text.match(/溝\s*[0-9]{2}/);
  return match ? compactRoute(match[0]) : "";
}

export async function loadKawasakiApproach(): Promise<{
  buses: ApproachSighting[];
  source: SourceStatus;
}> {
  try {
    const html = await fetchText(kawasakiApproachUrl());
    const parsed = parseKawasakiApproach(html);
    if (parsed.pageError) {
      return {
        buses: [],
        source: {
          operator: "川崎市バス",
          ok: false,
          message: parsed.pageError,
          updatedAt: null,
        },
      };
    }
    return {
      buses: parsed.buses,
      source: {
        operator: "川崎市バス",
        ok: true,
        message: parsed.message,
        updatedAt: parsed.updatedAt,
      },
    };
  } catch (error) {
    return {
      buses: [],
      source: {
        operator: "川崎市バス",
        ok: false,
        message: error instanceof Error ? error.message : "取得に失敗しました",
        updatedAt: null,
      },
    };
  }
}
