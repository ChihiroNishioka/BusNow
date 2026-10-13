import assert from "node:assert/strict";
import test from "node:test";
import { basisCaption, countdownAt, observedInstant, stampSightings } from "./countdown";
import type { ApproachSighting, SourceStatus } from "./types";

const sighting = (minutes: number | null): ApproachSighting => ({
  id: "bus",
  operator: "東急バス",
  route: "溝22",
  destination: "溝口南行",
  minutes,
  status: minutes == null ? "接近" : `${minutes}分待ち`,
});

test("a source clock becomes today's Tokyo instant", () => {
  const now = new Date("2026-10-13T01:52:20.000Z");
  const observed = observedInstant(now, "10:52");
  assert.equal(observed.toISOString(), "2026-10-13T01:52:00.000Z");
});

test("a clock just before midnight stays on yesterday after the date rolls", () => {
  const now = new Date("2026-10-13T15:05:00.000Z");
  const observed = observedInstant(now, "23:58");
  assert.equal(observed.toISOString(), "2026-10-13T14:58:00.000Z");
});

test("three minutes counts down to two, one, then まもなく, then drops", () => {
  const observed = new Date("2026-10-13T01:52:00.000Z");
  const [bus] = stampSightings([sighting(3)], observed);
  assert.equal(bus.arrivesAt, "2026-10-13T01:55:00.000Z");
  assert.deepEqual(countdownAt(bus.arrivesAt, observed), { kind: "minutes", minutes: 3 });
  assert.deepEqual(countdownAt(bus.arrivesAt, new Date(observed.getTime() + 60_000)), {
    kind: "minutes",
    minutes: 2,
  });
  assert.deepEqual(countdownAt(bus.arrivesAt, new Date(observed.getTime() + 120_000)), {
    kind: "minutes",
    minutes: 1,
  });
  assert.deepEqual(countdownAt(bus.arrivesAt, new Date(observed.getTime() + 180_000)), {
    kind: "soon",
  });
  assert.deepEqual(countdownAt(bus.arrivesAt, new Date(observed.getTime() + 200_000)), {
    kind: "soon",
  });
  assert.deepEqual(countdownAt(bus.arrivesAt, new Date(observed.getTime() + 180_000 + 60_000)), {
    kind: "past",
  });
});

test("a missing minute count is not given an arrival", () => {
  const [bus] = stampSightings([sighting(null)], new Date("2026-10-13T01:52:00.000Z"));
  assert.equal(bus.arrivesAt, null);
  assert.deepEqual(countdownAt(bus.arrivesAt, new Date()), { kind: "unknown" });
});

test("the basis line uses one clock when both operators agree", () => {
  const sources: SourceStatus[] = [
    { operator: "東急バス", ok: true, message: null, updatedAt: "10:52", observedAt: "2026-10-13T01:52:00.000Z" },
    { operator: "川崎市バス", ok: true, message: null, updatedAt: "10:52", observedAt: "2026-10-13T01:52:00.000Z" },
  ];
  assert.equal(basisCaption(sources), "10:52時点の情報");
});

test("different operator clocks stay visible separately", () => {
  const sources: SourceStatus[] = [
    { operator: "東急バス", ok: true, message: null, updatedAt: "10:52", observedAt: "2026-10-13T01:52:00.000Z" },
    { operator: "川崎市バス", ok: true, message: null, updatedAt: "10:51", observedAt: "2026-10-13T01:51:00.000Z" },
  ];
  assert.equal(basisCaption(sources), "東急バス 10:52時点 · 川崎市バス 10:51時点");
});
