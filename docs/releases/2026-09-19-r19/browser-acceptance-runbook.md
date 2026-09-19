# R19 guarded browser acceptance runbook

This runbook is for a synthetic local account in the in-app browser. It does not
authorize a live provider call, WhatsApp send, deployment, paid action, or use of
customer data. Use the staged R19 tree and the task-owned database only.

## Guard checks

Before starting, record the staged tree, database name, server PID/URL and that
the account is synthetic. Confirm the inbox is an API/evaluation inbox or a
WhatsApp test inbox whose outbound provider is stubbed. Confirm Test Center uses
the evaluation purpose, rollback transaction and `enqueue_deliveries: false`.
Stop if a Meta client, `SendReplyJob`, live recipient or customer record would be
used.

## Synthetic setups

Create these as editable setup notes and review the proposal before publishing:

1. **Online Profits coaching (English):** qualification enabled; sales call only
   after approved fit/readiness and explicit agreement. State that current prices
   are unconfirmed. The preview must show the missing current price and must not
   quote one.
2. **Duka la bidhaa (Kiswahili):** qualification not configured; purchase-link
   next step with an approved HTTPS purchase URL and a currently effective price
   in the authoritative price editor. Use: “Tunauza bidhaa za nyumbani. Bei ipo kwenye kiungo cha
   ununuzi. Hakuna maswali ya ustahiki.” The preview must remain in plain language
   and must not introduce default qualification questions or a call.
3. **Bookkeeping service (English):** qualification enabled; enquiry next step;
   current registration number is a distinct fit requirement. It must not reuse
   Online Profits rules.

Prices and promotions must remain in the existing authoritative Offer price
editor. A price sentence in setup notes may create an R20 review proposal, but
must not appear in published runtime Knowledge or become quotable before that
proposal is reviewed and the commercial revision is explicitly published.

## Desktop path

At a desktop width, open Settings → Offers and qualification.

- Paste each source and choose **Review proposed setup**.
- Verify facts, fit rules and missing details are visibly separated and the page
  states that nothing is live yet.
- Correct one source and verify its source version/history changes while the
  Offer revision does not.
- Reload the page, reopen the persisted proposed source and save another
  correction. Verify obsolete source-generated requirements are replaced while
  independently configured questions/rules remain.
- Verify prose fit requirements produce typed proposed questions/rules and prose
  next-step language produces a typed next step before publication.
- In a second session, change the same Offer; publishing the old preview must
  show a conflict and preserve the draft.
- Publish a freshly reviewed source and record the displayed source version and
  published Offer revision.
- Publish a corrected setup and verify the prior Knowledge Document is archived;
  both normal inbound retrieval and Test Center must use the corrected answer.
- Enter a real customer question under **Test this setup**. Verify the completed Evaluation Run records
  the same source ID/version and Offer revision.
- Change the Offer after publication and retry the old source. It must be
  rejected as stale before orchestration.

## Phone path

Repeat review, correction, conflict recovery and publication at a phone width.
Controls must remain readable without horizontal scrolling; the proposed facts,
rules, unknowns and publication state must remain understandable without relying
on hover behavior.

## Conversation outcomes

Use only the authorized Test Center runtime:

- Ask an approved English buying question for Online Profits. Unconfirmed price
  stays withheld.
- Ask the Swahili product question. It receives an approved answer and purchase
  next step without qualification questions.
- Try “Bei ni elfu hamsini” and “Gharama ni laki mbili” in an unpublished
  source. They may create R20 proposals but must never appear in retrieved
  Knowledge before authoritative price publication.
- Verify “No sales call required” does not enable qualification or a call, while
  “Enquiries need a current business registration number” proposes an enquiry
  and a typed fit requirement.
- Ask the bookkeeping fit question. Only that Offer's registration requirement
  is used.
- Correct a Lead fact and verify the new evidence is used without mutating the
  published setup.
- Request basic human help. It creates/uses the human-help route without forcing
  qualification, promising an owner call, or producing a live send.
- Ask an unknown relevant question. It truthfully records Review; it does not
  invent a callback time.

## Evidence to capture

Record desktop and phone screenshots for proposal, correction, conflict,
publication and Test Center result. Record the account ID, Offer ID, setup source
ID/version, published Offer revision and Evaluation Run ID. Confirm no persisted
simulation Message, Outbox Event or Review Request remains after rollback and no
delivery job/provider client was invoked. Note every limitation or mismatch;
do not mark browser acceptance complete until all three setups and human help are
demonstrated.
