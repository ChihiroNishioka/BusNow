"use client";

import { useCallback, useState } from "react";
import type { Departure, DeparturePayload } from "@/lib/types";
import { Sheet, SourceNotes, type BoardLink } from "@/components/sheet";

export function DepartureBoard({
  initial,
  links,
}: {
  initial: DeparturePayload;
  links: BoardLink[];
}) {
  const [data, setData] = useState(initial);
  const [refreshing, setRefreshing] = useState(false);
  const [refreshError, setRefreshError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    setRefreshing(true);
    try {
      const response = await fetch("/api/departures", { cache: "no-store" });
      if (!response.ok) throw new Error("更新できませんでした");
      const next = (await response.json()) as DeparturePayload;
      setData(next);
      setRefreshError(null);
    } catch {
      setRefreshError("更新できませんでした。前の表示のままです");
    } finally {
      setRefreshing(false);
    }
  }, []);

  const bothDown = data.sources.every((source) => !source.ok);

  return (
    <Sheet
      tone="mizo"
      title="溝の口駅南口発"
      refreshing={refreshing}
      onRefresh={() => void reload()}
    >
      <p className="sheet-sub">富士見台方面</p>
      {data.serviceFinishedToday && data.departures.length > 0 ? (
        <p className="finished">きょうの運行は終わりました</p>
      ) : null}
      {data.departures.length === 0 ? (
        <p className="hero-empty">{bothDown ? "うまく取れませんでした" : "次の便がありません"}</p>
      ) : (
        <ol className="dep-list">
          {data.departures.map((departure) => (
            <li key={departure.id}>
              <DepartureRow departure={departure} />
            </li>
          ))}
        </ol>
      )}
      {refreshError ? <p className="note warn">{refreshError}</p> : null}
      <SourceNotes sources={data.sources} />
      <p className="official">
        {links.map((link) => (
          <a key={link.href} href={link.href} target="_blank" rel="noreferrer">
            {link.label}
          </a>
        ))}
      </p>
    </Sheet>
  );
}

function DepartureRow({ departure }: { departure: Departure }) {
  return (
    <article className="dep">
      <p className="dep-time">{departure.time}</p>
      <div className="dep-main">
        <p className={`chip ${departure.operator === "東急バス" ? "op-tokyu" : "op-kawasaki"}`}>
          {departure.operator}
        </p>
        <p className="route">
          {departure.route} {departure.destination}
        </p>
        <p className="when">
          {departure.whenLabel} · {departure.dayLabel}
        </p>
      </div>
    </article>
  );
}
