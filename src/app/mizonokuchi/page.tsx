import { DepartureBoard } from "@/components/departure-board";
import { loadDepartures } from "@/lib/board";
import { KAWASAKI_TIMETABLE_URL } from "@/lib/kawasaki-timetable";
import { TOKYU_TIMETABLE_URL } from "@/lib/tokyu-timetable";

export const dynamic = "force-dynamic";
export const metadata = { title: "溝の口駅南口発" };

export default async function MizonokuchiPage() {
  const data = await loadDepartures();
  return (
    <DepartureBoard
      initial={data}
      links={[
        { label: "東急バス 時刻表", href: TOKYU_TIMETABLE_URL },
        { label: "川崎市バス 時刻表", href: KAWASAKI_TIMETABLE_URL },
      ]}
    />
  );
}
