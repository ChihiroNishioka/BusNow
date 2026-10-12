import { Button } from "@/components/ui/button";
import Link from "next/link";

export default function Home() {
  return (
    <main className="home-board">
      <Button asChild variant="ghost" className="enamel enamel-fuji">
        <Link href="/fujimidai">富士見台発</Link>
      </Button>
      <Button asChild variant="ghost" className="enamel enamel-mizo">
        <Link href="/mizonokuchi">溝の口駅南口発</Link>
      </Button>
    </main>
  );
}
