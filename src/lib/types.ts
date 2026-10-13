export type Operator = "東急バス" | "川崎市バス";

export type SourceStatus = {
  operator: Operator;
  ok: boolean;
  message: string | null;
  /** Operator clock as HH:MM, when the page printed one. */
  updatedAt: string | null;
  /** Instant that clock (or our fetch) refers to. */
  observedAt?: string | null;
};

/** A bus as parsed, before it is anchored to a clock. */
export type ApproachSighting = {
  id: string;
  operator: Operator;
  route: string;
  destination: string;
  minutes: number | null;
  status: string;
};

export type ApproachBus = ApproachSighting & {
  /** When `minutes` was true: the source clock, or the fetch time. */
  observedAt: string;
  /** observedAt plus `minutes`. Null when the page gave no minute count. */
  arrivesAt: string | null;
};

export type ApproachPayload = {
  stop: "富士見台";
  toward: "溝の口";
  fetchedAt: string;
  buses: ApproachBus[];
  sources: SourceStatus[];
};

export type Departure = {
  id: string;
  operator: Operator;
  route: string;
  destination: string;
  time: string;
  date: string;
  dayLabel: "平日" | "土曜" | "休日";
  whenLabel: string;
};

export type DeparturePayload = {
  stop: "溝の口駅南口";
  toward: "富士見台";
  fetchedAt: string;
  today: string;
  serviceFinishedToday: boolean;
  departures: Departure[];
  sources: SourceStatus[];
};
