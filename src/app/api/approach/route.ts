import { loadApproach } from "@/lib/board";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 60;

export async function GET() {
  const payload = await loadApproach();
  return Response.json(payload, {
    headers: { "Cache-Control": "no-store" },
  });
}
