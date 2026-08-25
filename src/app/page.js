import { ConversationConsole } from "./components/conversation-console.js";
import { getRuntime } from "@/lib/runtime.js";

export const dynamic = "force-dynamic";

export default function HomePage() {
  const conversations = getRuntime().repository.listConversations();

  return (
    <main>
      <header className="topbar">
        <div>
          <p className="eyebrow">Ticket 001 · operational proof</p>
          <h1>Conversation control</h1>
          <p className="subtitle">AI replies only while it owns a pending Chatwoot conversation.</p>
        </div>
        <span className="environment">Local integration harness</span>
      </header>
      <section className="guide">
        <strong>Waiting for Chatwoot</strong>
        <span>Send a signed AgentBot webhook to populate this view. Every human action cancels queued AI work.</span>
      </section>
      <section className="content" aria-label="Active conversations">
        {conversations.length ? conversations.map((conversation) => (
          <ConversationConsole key={conversation.id} conversation={conversation} />
        )) : <div className="empty">No conversations have been received yet.</div>}
      </section>
    </main>
  );
}
