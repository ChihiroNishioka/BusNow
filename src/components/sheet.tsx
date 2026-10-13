"use client";

import Link from "next/link";
import type { ReactNode } from "react";
import { Button } from "@/components/ui/button";
import type { SourceStatus } from "@/lib/types";

export type BoardLink = { label: string; href: string };

export function Sheet({
  tone,
  title,
  children,
  refreshing,
  onRefresh,
}: {
  tone: "fuji" | "mizo";
  title: string;
  children: ReactNode;
  refreshing?: boolean;
  onRefresh?: () => void;
}) {
  return (
    <div className="street">
      <div className={`sheet sheet-${tone}`}>
        <div className="sheet-top">
          <Button asChild variant="ghost" className="back-btn">
            <Link href="/">もどる</Link>
          </Button>
          {onRefresh ? (
            <Button
              type="button"
              variant="outline"
              className="refresh-btn"
              onClick={onRefresh}
            >
              {refreshing ? "更新中" : "更新"}
            </Button>
          ) : null}
        </div>
        <h1 className="sheet-title">{title}</h1>
        {children}
      </div>
    </div>
  );
}

export function SourceNotes({
  sources,
  showClock = true,
}: {
  sources: SourceStatus[];
  showClock?: boolean;
}) {
  return (
    <div className="sources">
      {sources.map((source) => {
        const clock = showClock ? source.updatedAt : null;
        if (source.ok && !source.message && !clock) return null;
        return (
          <p key={source.operator} className={source.ok ? "note" : "note warn"}>
            <span className={`chip ${source.operator === "東急バス" ? "op-tokyu" : "op-kawasaki"}`}>
              {source.operator}
            </span>
            {source.ok ? source.message : source.message ?? "うまく取れませんでした"}
            {clock ? ` · ${clock}時点` : ""}
          </p>
        );
      })}
    </div>
  );
}
