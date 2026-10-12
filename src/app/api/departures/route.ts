import { loadDepartures } from "@/lib/board";

export const dynamic = "force-dynamic";

export async function GET() {
  const payload = await loadDepartures();
  return Response.json(payload, {
    headers: { "Cache-Control": "no-store" },
  });
}
