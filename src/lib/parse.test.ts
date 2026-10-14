import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import snapshot from "../data/tokyu-mizonokuchi.json";
import { decodePage } from "./http";
import { parseKawasakiApproach } from "./kawasaki-approach";
import { parseKawasakiTimetableHtml } from "./kawasaki-timetable";
import { parseNavitimeDiagram } from "./navitime";
import { compactRoute } from "./text";
import { dayKind, isHoliday } from "./tokyo-time";
import { parseTokyuApproach } from "./tokyu-approach";
import { selectUpcoming } from "./upcoming";

const fixtureDir = dirname(fileURLToPath(import.meta.url));

test("holidays for the 2026 calendar the timetable uses", () => {
  assert.equal(dayKind("2026-10-12"), "holiday");
  assert.equal(isHoliday("2026-10-12"), true);
  assert.equal(dayKind("2026-10-13"), "weekday");
  assert.equal(dayKind("2026-10-17"), "saturday");
  assert.equal(isHoliday("2026-03-20"), true);
  assert.equal(isHoliday("2026-09-23"), true);
  assert.equal(isHoliday("2026-09-22"), true);
  assert.equal(dayKind("2026-05-06"), "holiday");
  assert.equal(isHoliday("2026-05-06"), true);
});

test("navitime diagram cells become clock times", () => {
  const html = `
    <table>
      <tr><th>時</th><th>平日</th><th>土曜</th><th>休日</th></tr>
      <tr>
        <td>6</td>
        <td>02<br>2分はつ 溝22</td>
        <td>10 10分はつ</td>
        <td>09 9分はつ 25 25分はつ</td>
      </tr>
    </table>`;
  const columns = parseNavitimeDiagram(html);
  assert.deepEqual(columns.weekday, ["06:02"]);
  assert.deepEqual(columns.saturday, ["06:10"]);
  assert.deepEqual(columns.holiday, ["06:09", "06:25"]);
});

test("tokyu approach text, including an empty cell", () => {
  const html = `
    <title>バス接近情報｜富士見台（高津区）→溝の口駅南口</title>
    <div>23:03 <span>時点の情報</span></div>
    <table class="sekkinListTbl">
      <tr><td class="businfo">溝２２ 蟹ヶ谷行【09分待ち】</td></tr>
      <tr><td class="businfo">&nbsp;</td></tr>
      <tr><td class="colmsg">溝22 まもなく</td></tr>
    </table>`;
  const parsed = parseTokyuApproach(html);
  assert.equal(parsed.pageError, null);
  assert.equal(parsed.updatedAt, "23:03");
  assert.equal(parsed.buses.length, 2);
  assert.equal(parsed.buses[0].route, "溝22");
  assert.equal(parsed.buses[0].minutes, 9);
  assert.equal(parsed.buses[0].destination, "蟹ヶ谷行");
  assert.equal(parsed.buses[1].minutes, 0);
  assert.equal(parsed.buses[1].status, "まもなく");
});

test("tokyu route diagram keeps every bus still coming to 溝の口, including a short-turn", () => {
  const html = `
    <title>東急バスナビ｜ＰＣ版・路線別運行情報(位置情報)｜溝22</title>
    <div>09:51 <span>時点の情報</span></div>
    <table class="routeListTbl">
      <tr>
        <td class="balloonL"><dd>(折)蟹ヶ谷行 <em></em></dd></td>
        <td class="balloonR">&nbsp;</td>
      </tr>
      <tr>
        <td class="balloonL">&nbsp;</td>
        <td class="balloonR"><dd>蟹ヶ谷行 <em>02分待ち</em></dd></td>
      </tr>
      <tr>
        <td class="balloonL"><dd>溝口南行 <em>04分待ち</em></dd></td>
        <td class="stopName">洗足学園前</td>
      </tr>
      <tr><td class="stopName">富士見台</td><td class="balloonL">&nbsp;</td></tr>
      <tr>
        <td class="balloonL"><dd>溝口南行 <em>06分待ち</em></dd></td>
        <td class="balloonR">&nbsp;</td>
      </tr>
      <tr>
        <td class="balloonL">&nbsp;</td>
        <td class="balloonR"><dd>蟹ヶ谷行 <em>03分待ち</em></dd></td>
      </tr>
      <tr>
        <td class="balloonL"><dd>(折)溝口南行 <em>15分待ち</em></dd></td>
      </tr>
      <tr>
        <td class="balloonL"><dd>溝口南行 <em>まもなく</em></dd></td>
      </tr>
    </table>`;
  const parsed = parseTokyuApproach(html);
  assert.equal(parsed.pageError, null);
  assert.equal(parsed.updatedAt, "09:51");
  assert.deepEqual(
    parsed.buses.map((bus) => `${bus.route} ${bus.destination} ${bus.minutes}`),
    ["溝22 溝口南行 6", "溝22 (折)溝口南行 15", "溝22 溝口南行 0"],
  );
  assert.equal(parsed.buses[2].status, "まもなく");
});

test("tokyu phone diagram uses the upward column after 富士見台", () => {
  const html = `
    <title>東急バスナビ｜路線別運行情報(位置情報)｜溝22</title>
    <div>09:51時点の情報</div>
    <table>
      <tr><td><div class="label-u">溝口南行<br /><span class="waittm">01分待ち</span></div></td></tr>
      <tr class="stopline selectedstopline"><td class="stopnm" id="selectStop"><span>富士見台</span></td></tr>
      <tr><td><div class="label-u">溝口南行<br /><span class="waittm">06分待ち</span></div></td></tr>
      <tr><td><div class="label-d">蟹ヶ谷行<br /><span class="waittm">02分待ち</span></div></td></tr>
      <tr><td><div class="label-u">(折)溝口南行<br /><span class="waittm">15分待ち</span></div></td></tr>
    </table>`;
  const parsed = parseTokyuApproach(html);
  assert.deepEqual(
    parsed.buses.map((bus) => `${bus.destination} ${bus.minutes}`),
    ["溝口南行 6", "(折)溝口南行 15"],
  );
});

test("kawasaki approach cards and the empty night notice", () => {
  const live = `
    <title>川崎市 市バスナビ</title>
    <li><i class="fa fa-clock-o"></i>18:12</li>
    <div id="errInfo"></div>
    <div id="buslist">
      <div class="route_box">
        <font style="color: blue;">溝２１</font>
        有馬第二団地前 行き
        約&nbsp;<font size="4">6</font>分で発車します
      </div>
      <div class="route_box">
        <font color="blue">溝23</font>
        梶ヶ谷駅 行き
        まもなく
      </div>
    </div>`;
  const parsed = parseKawasakiApproach(live);
  assert.equal(parsed.pageError, null);
  assert.equal(parsed.updatedAt, "18:12");
  assert.equal(parsed.buses.length, 2);
  assert.equal(parsed.buses[0].route, "溝21");
  assert.equal(parsed.buses[0].minutes, 6);
  assert.equal(parsed.buses[0].destination, "有馬第二団地前行き");
  assert.equal(parsed.buses[1].minutes, 0);
  assert.equal(parsed.buses[1].status, "まもなく");

  const empty = `
    <title>川崎市 市バスナビ</title>
    <li><i class="fa fa-clock-o"></i>23:05</li>
    <div id="errInfo"><b>60分以内に接近しているバスはありません。</b></div>
    <div id="buslist"></div>`;
  const night = parseKawasakiApproach(empty);
  assert.equal(night.buses.length, 0);
  assert.match(night.message ?? "", /接近しているバスはありません/);
  assert.equal(night.updatedAt, "23:05");
});

test("kawasaki timetable html keeps the hour with the nested minutes", () => {
  const html = readFileSync(
    join(fixtureDir, "fixtures/kawasaki-mizo21-weekday.html"),
    "utf8",
  );
  const times = parseKawasakiTimetableHtml(html);
  assert.deepEqual(times.slice(0, 3), ["06:08", "06:52", "07:28"]);
  assert.equal(times.some((time) => time.startsWith("05:")), false);
});

test("combined rollsign collapses a line break into a middle dot", () => {
  assert.equal(compactRoute("溝15<br>溝18"), "溝15・溝18");
});

test("shift_jis pages decode when the meta tag says so", () => {
  const prefix = new TextEncoder().encode('<meta charset="shift_jis">');
  const bytes = new Uint8Array(prefix.length + 2);
  bytes.set(prefix, 0);
  bytes.set([0x8a, 0x4f], prefix.length);
  assert.match(decodePage(bytes), /外/);
});

test("after the last bus, the next three are tomorrow morning", () => {
  const now = new Date("2026-10-12T14:30:00Z");
  const trips = [
    ...snapshot.weekday.slice(0, 3).map((time) => ({
      operator: "東急バス" as const,
      route: "溝22",
      destination: "蟹ヶ谷行き",
      dayKind: "weekday" as const,
      time,
    })),
    {
      operator: "川崎市バス" as const,
      route: "溝21",
      destination: "有馬第二団地前行き",
      dayKind: "weekday" as const,
      time: "06:08",
    },
    ...snapshot.holiday.slice(0, 2).map((time) => ({
      operator: "東急バス" as const,
      route: "溝22",
      destination: "蟹ヶ谷行き",
      dayKind: "holiday" as const,
      time,
    })),
  ];
  const result = selectUpcoming(now, trips, 3);
  assert.equal(result.today, "2026-10-12");
  assert.equal(result.serviceFinishedToday, true);
  assert.deepEqual(
    result.departures.map((item) => `${item.time} ${item.operator}`),
    ["06:02 東急バス", "06:08 川崎市バス", "06:11 東急バス"],
  );
  assert.equal(result.departures[0].whenLabel, "明日");
  assert.equal(result.departures[0].dayLabel, "平日");
});

test("a holiday morning stays on the holiday column", () => {
  const now = new Date("2026-10-12T00:00:00Z");
  const trips = snapshot.holiday.map((time) => ({
    operator: "東急バス" as const,
    route: "溝22",
    destination: "蟹ヶ谷行き",
    dayKind: "holiday" as const,
    time,
  }));
  const result = selectUpcoming(now, trips, 3);
  assert.equal(result.serviceFinishedToday, false);
  assert.equal(result.departures.length, 3);
  for (const departure of result.departures) {
    assert.equal(departure.dayLabel, "休日");
    assert.equal(departure.whenLabel, "今日");
    assert.ok(departure.time >= "09:00");
  }
});
