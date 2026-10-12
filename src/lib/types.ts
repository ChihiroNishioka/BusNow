export type Operator = "東急バス" | "川崎市バス";

export type SourceStatus = {
  operator: Operator;
  ok: boolean;
  message: string | null;
  updatedAt: string | null;
};

export type ApproachBus = {
  id: string;
  operator: Operator;
  route: string;
  destination: string;
  minutes: number | null;
  status: string;
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
