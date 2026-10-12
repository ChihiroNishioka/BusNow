"use client";

import { useCallback, useEffect, useState } from "react";
import type { ApproachBus, ApproachPayload } from "@/lib/types";
import { Sheet, SourceNotes, type BoardLink } from "@/components/sheet";

const REFRESH_MS = 30_000;

export function ApproachBoard({
  initial,
  links,
}: {
  initial: ApproachPayload;
  links: BoardLink[];
}) {
  const [data, setData] = useState(initial);
  const [refreshing, setRefreshing] = useState(false);
  const [refreshError, setRefreshError] = useState<string | null>(null);

  const reload = useCallback(async () => {
    setRefreshing(true);
    try {
      const response = await fetch("/api/approach", { cache: "no-store" });
      if (!response.ok) throw new Error("更新できませんでした");
      const next = (await response.json()) as ApproachPayload;
      setData(next);
      setRefreshError(null);
    } catch {
      setRefreshError("更新できませんでした。前の表示のままです");
    } finally {
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    const timer = window.setInterval(() => void reload(), REFRESH_MS);
    const onVisible = () => {
      if (document.visibilityState === "visible") void reload();
    };
    document.addEventListener("visibilitychange", onVisible);
    return () => {
      window.clearInterval(timer);
      document.removeEventListener("visibilitychange", onVisible);
    };
  }, [reload]);

  return (
    <Sheet tone="fuji" title="富士見台発" refreshing={refreshing} onRefresh={() => void reload()}>
      <p className="sheet-sub">溝の口方面</p>
      {data.buses.length === 0 ? (
        <p className="hero-empty">接近しているバスはありません</p>
      ) : (
        <ul className="bus-list">
          {data.buses.map((bus) => (
            <li key={bus.id}>
              <BusRow bus={bus} />
            </li>
          ))}
        </ul>
      )}
      {refreshError ? <p className="note warn">{refreshError}</p> : null}
      <p className="note quiet">30秒ごとに更新</p>
      <SourceNotes sources={data.sources} />
      <OfficialLinks links={links} />
    </Sheet>
  );
}

function BusRow({ bus }: { bus: ApproachBus }) {
  return (
    <article className="bus">
      <div className="bus-main">
        <p className={`chip ${bus.operator === "東急バス" ? "op-tokyu" : "op-kawasaki"}`}>
          {bus.operator}
        </p>
        <p className="route">{bus.route}</p>
        <p className="dest">{bus.destination}</p>
      </div>
      <MinuteMark bus={bus} />
    </article>
  );
}

function MinuteMark({ bus }: { bus: ApproachBus }) {
  if (bus.minutes === 0) {
    return <p className="minute soon">まもなく</p>;
  }
  if (bus.minutes == null) {
    return <p className="minute soon">{bus.status}</p>;
  }
  return (
    <p className="minute">
      <span className="num">{bus.minutes}</span>
      <span className="unit">分</span>
    </p>
  );
}

function OfficialLinks({ links }: { links: BoardLink[] }) {
  return (
    <p className="official">
      {links.map((link) => (
        <a key={link.href} href={link.href} target="_blank" rel="noreferrer">
          {link.label}
        </a>
      ))}
    </p>
  );
}
