import { getRuntime } from "@/lib/runtime.js";

const allowedActions = new Set(["ai_handoff", "human_assigned", "manual_pause", "manual_resume", "resolve"]);

export async function POST(request, { params }) {
  const { action } = await request.json();
  if (!allowedActions.has(action)) {
    return Response.json({ error: "Unsupported control action" }, { status: 400 });
  }

  try {
    const conversation = getRuntime().service.changeControl({
      externalConversationId: (await params).conversationId,
      type: action,
    });
    return Response.json({ conversation });
  } catch (error) {
    return Response.json({ error: error.message }, { status: 404 });
  }
}
