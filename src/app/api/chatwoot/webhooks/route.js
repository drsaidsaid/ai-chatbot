import { normalizeChatwootEvent, verifyChatwootWebhook } from "@/lib/chatwoot.js";
import { getRuntime } from "@/lib/runtime.js";

export const runtime = "nodejs";

export async function POST(request) {
  const secret = process.env.CHATWOOT_WEBHOOK_SECRET;
  if (!secret) {
    return Response.json({ error: "CHATWOOT_WEBHOOK_SECRET is not configured" }, { status: 503 });
  }

  const rawBody = await request.text();
  const timestamp = request.headers.get("x-chatwoot-timestamp");
  const signature = request.headers.get("x-chatwoot-signature");

  if (!verifyChatwootWebhook({ secret, rawBody, timestamp, signature })) {
    return Response.json({ error: "Invalid Chatwoot webhook signature" }, { status: 401 });
  }

  let payload;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return Response.json({ error: "Invalid JSON payload" }, { status: 400 });
  }

  try {
    const result = getRuntime().service.ingest(
      normalizeChatwootEvent(payload),
      request.headers.get("x-chatwoot-delivery"),
    );
    return Response.json({ accepted: true, duplicate: result.duplicate });
  } catch (error) {
    return Response.json({ error: error.message }, { status: 422 });
  }
}
