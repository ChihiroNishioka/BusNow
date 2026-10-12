"use client";

import { Button } from "@/components/ui/button";

export default function MizonokuchiError({ reset }: { error: Error; reset: () => void }) {
  return (
    <div className="street">
      <div className="sheet sheet-mizo">
        <p className="hero-empty">うまく取れませんでした</p>
        <Button type="button" className="refresh-btn" onClick={reset}>
          もう一度
        </Button>
      </div>
    </div>
  );
}
