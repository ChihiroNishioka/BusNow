"use client";

import { useCallback, useEffect, useState } from "react";
import { basisCaption, countdownAt, type Countdown } from "@/lib/countdown";
import type { ApproachBus, ApproachPayload } from "@/lib/types";
import { Sheet, SourceNotes, type BoardLink } from "@/components/sheet";

const REFRESH_MS = 30_000;
const TICK_MS = 1_000;

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
  const [nowMs, setNowMs] = useState<number | null>(null);

  const reload = useCallback(async () => {
    setRefreshing(true);
    try {
      const response = await fetch("/api/approach", { cache: "no-store" });
      if (!response.ok) throw new Error("更新できませんでした");
      const next = (await response.json()) as ApproachPayload;
      setData(next);
      setNowMs(Date.now());
      setRefreshError(null);
    } catch {
      setRefreshError("更新できませんでした。前の表示のままです");
    } finally {
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    let timer = 0;
    const tick = () => setNowMs(Date.now());
    const start = () => {
      stop();
      tick();
      timer = window.setInterval(tick, TICK_MS);
    };
    const stop = () => window.clearInterval(timer);
    const onVisible = () => {
      if (document.visibilityState === "hidden") {
        stop();
        return;
      }
      start();
      void reload();
    };
    const onShow = () => tick();
    if (document.visibilityState !== "hidden") start();
    document.addEventListener("visibilitychange", onVisible);
    window.addEventListener("pageshow", onShow);
    window.addEventListener("focus", onShow);
    return () => {
      stop();
      document.removeEventListener("visibilitychange", onVisible);
      window.removeEventListener("pageshow", onShow);
      window.removeEventListener("focus", onShow);
    };
  }, [reload]);

  useEffect(() => {
    const timer = window.setInterval(() => {
      if (document.visibilityState === "hidden") return;
      void reload();
    }, REFRESH_MS);
    return () => window.clearInterval(timer);
  }, [reload]);

  const now = nowMs == null ? null : new Date(nowMs);
  const rows = data.buses
    .map((bus) => ({ bus, countdown: displayCountdown(bus, now) }))
    .filter((row) => row.countdown.kind !== "past")
    .sort((a, b) => rank(a.countdown) - rank(b.countdown) || a.bus.route.localeCompare(b.bus.route, "ja"));
  const basis = basisCaption(data.sources);

  return (
    <Sheet tone="fuji" title="富士見台発" refreshing={refreshing} onRefresh={() => void reload()}>
      <p className="sheet-sub">溝の口方面</p>
      {rows.length === 0 ? (
        <p className="hero-empty">接近しているバスはありません</p>
      ) : (
        <ul className="bus-list">
          {rows.map(({ bus, countdown }) => (
            <li key={bus.id}>
              <BusRow bus={bus} countdown={countdown} />
            </li>
          ))}
        </ul>
      )}
      {refreshError ? <p className="note warn">{refreshError}</p> : null}
      <p className="note quiet">{basis ? `${basis} · 30秒ごとに更新` : "30秒ごとに更新"}</p>
      <SourceNotes sources={data.sources} showClock={false} />
      <OfficialLinks links={links} />
    </Sheet>
  );
}

function displayCountdown(bus: ApproachBus, now: Date | null): Countdown {
  if (now && bus.arrivesAt) return countdownAt(bus.arrivesAt, now);
  if (bus.minutes === 0) return { kind: "soon" };
  if (bus.minutes == null) return { kind: "unknown" };
  return { kind: "minutes", minutes: bus.minutes };
}

function rank(countdown: Countdown): number {
  if (countdown.kind === "soon") return 0;
  if (countdown.kind === "minutes") return countdown.minutes;
  return 10_000;
}

function BusRow({ bus, countdown }: { bus: ApproachBus; countdown: Countdown }) {
  return (
    <article className="bus">
      <div className="bus-main">
        <p className={`chip ${bus.operator === "東急バス" ? "op-tokyu" : "op-kawasaki"}`}>
          {bus.operator}
        </p>
        <p className="route">{bus.route}</p>
        <p className="dest">{bus.destination}</p>
      </div>
      <MinuteMark countdown={countdown} fallback={bus.status} />
    </article>
  );
}

function MinuteMark({ countdown, fallback }: { countdown: Countdown; fallback: string }) {
  if (countdown.kind === "soon") {
    return <p className="minute soon">まもなく</p>;
  }
  if (countdown.kind === "unknown") {
    return <p className="minute soon">{fallback}</p>;
  }
  if (countdown.kind === "past") return null;
  return (
    <p className="minute">
      <span className="num">{countdown.minutes}</span>
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
