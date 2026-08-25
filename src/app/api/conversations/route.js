import { getRuntime } from "@/lib/runtime.js";

export function GET() {
  const { repository } = getRuntime();
  return Response.json({ conversations: repository.listConversations() });
}
