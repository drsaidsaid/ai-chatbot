# Combined in-app acceptance

Source: uncommitted combined R23/R09 integration tree, final runtime unchanged
since the successful backend checks apart from the evaluation registration guard
verified by11 focused provider tests. Production Vite build:5085 modules,37.70s;
8 frontend tests passed. No Vite dev server was used for this acceptance.

Fresh database: ale_release_r23_combined. Rails preview bound127.0.0.1:5063;
Redis bound127.0.0.1:6463. Test jobs/mail adapters, no worker and no AI provider
connection. WebMock denied non-loopback server requests; refused-loopback proxy
variables were set before Rails started. All users, messages, billing data and
credentials were synthetic. The local WhatsApp fixture had no provider credentials
and its creation-time sync was suppressed only on that synthetic instance.

Desktop1280x720 displayed R23 Synthetic,0used/2remaining,33.3%, one held partial
reply credit and the separately billed Meta/advertising explanation. Clicking the
5-credit top-up button created one pending manual-confirmation request with
synthetic/no-payment instructions; it did not grant credits or take payment.

At390x844 the same meter, held-credit copy and pending request were reachable.
The document width was390 with no horizontal overflow. Screenshots are retained
inline in the coordinator transcript, not as invented local files.

Two authenticated local finance PATCH requests returned200 and the same
released_at timestamp2026-09-12T23:56:12.118Z with partial_failure_closed and
settled_at:null. Retrying the original failed message via the normal WhatsApp
message retry API returned409. Reloading both phone and desktop visibly showed
0used/3remaining,0%, and no held-credit copy. Provider usage and payment
confirmation counts remained0. Browser error log was empty. Phone override was
reset and the temporary tab was closed.

Visual follow-up for the later cross-product polish ticket: format ISO renewal
dates and monetary decimals for ordinary business users. This does not change
verified renewal/credit accounting or introduce another billing workstream.
