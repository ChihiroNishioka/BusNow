import { ApproachBoard } from "@/components/approach-board";
import { loadApproach } from "@/lib/board";
import { kawasakiApproachUrl } from "@/lib/kawasaki-approach";
import { TOKYU_FUJIMIDAI_URL } from "@/lib/tokyu-approach";

export const dynamic = "force-dynamic";
export const metadata = { title: "富士見台発" };

export default async function FujimidaiPage() {
  const data = await loadApproach();
  return (
    <ApproachBoard
      initial={data}
      links={[
        { label: "東急バスナビ", href: TOKYU_FUJIMIDAI_URL },
        { label: "川崎市バスナビ", href: kawasakiApproachUrl() },
      ]}
    />
  );
}
