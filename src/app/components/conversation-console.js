"use client";

import { useState } from "react";

const label = {
  ai_handoff: "Request human handoff",
  human_assigned: "Assign human",
  manual_pause: "Pause AI",
  manual_resume: "Resume AI",
  resolve: "Resolve",
};

export function ConversationConsole({ conversation }) {
  const [current, setCurrent] = useState(conversation);
  const [error, setError] = useState(null);

  async function control(action) {
    setError(null);
    const response = await fetch(`/api/conversations/${current.externalConversationId}/control`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action }),
    });
    const body = await response.json();
    if (!response.ok) {
      setError(body.error ?? "Unable to update conversation control");
      return;
    }
    setCurrent(body.conversation);
  }

  return (
    <article className="conversation-card">
      <div className="card-heading">
        <div>
          <p className="eyebrow">Chatwoot conversation {current.externalConversationId}</p>
          <h2>{current.currentOwner === "human_operator" ? "Human controlled" : "AI controlled"}</h2>
        </div>
        <span className={`state ${current.controlState}`}>{current.controlState.replaceAll("_", " ")}</span>
      </div>
      <dl>
        <div><dt>Chatwoot status</dt><dd>{current.chatwootStatus}</dd></div>
        <div><dt>Current owner</dt><dd>{current.currentOwner.replaceAll("_", " ")}</dd></div>
        <div><dt>Control version</dt><dd>{current.controlVersion}</dd></div>
        <div><dt>AI reply queued</dt><dd>{current.aiReplyQueued ? "Yes" : "No"}</dd></div>
      </dl>
      <div className="controls" aria-label="Conversation controls">
        {Object.entries(label).map(([action, text]) => (
          <button key={action} type="button" onClick={() => control(action)}>{text}</button>
        ))}
      </div>
      {error ? <p className="error">{error}</p> : null}
    </article>
  );
}
