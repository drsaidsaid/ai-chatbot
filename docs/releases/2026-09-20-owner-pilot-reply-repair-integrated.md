# Owner pilot reply repair — integration evidence

## Problem and change
The first owner test reached staging as inbound116, but outgoing117 was canceled with launch_not_approved before transport because local replies omitted pilot authorization. The repair carries the persisted intent authority and verifies it at locked dispatch, including exact scope, control/provider revisions, active dates, linked intent and persisted outbound decision. Forged local status cannot bypass paid-usage checks; normal non-pilot dispatch does not acquire the added intent lock. Canceled117 is preserved and must not be replayed.

The combined release also includes conservative English/Swahili wellbeing greetings and a correction that routes unavailable commercial prices to human review and a truthful acknowledgment without paid inference. Original pricing refusal is retained on the intent. Existing quote-required published pricing is unchanged.

## Source and review
Greeting commits90acf09a/622b868f; pricing18e380a5. Delivery candidates77318eab15f5d48da943ff69e268bc51b9af87b6 and5190f9f9e4ae3f6286701946d87de2546d5b9bda. Root and independent specification/standards reviews completed; both requested delivery corrections are verified closed. Candidate focused checks: greeting117, pricing38, pilot authority15, exact metadata2 examples passing; scoped lint clean.

## Integrated validation
Combined canonical classifier, account-context, pricing orchestration, R11 orchestration and pilot authority suite: **283 examples, 0 failures in36.06s**. The previously failing commercial-price orchestration examples now pass. Canonical WhatsApp/provider-control request checks: **69 examples,0 failures in83.76s**, run alone with no competing test process; previous cleanup timeouts did not recur. Initial request command had a wrong spec path and ran zero examples; corrected path produced this passing result. This document does not establish deployment or live transport/response quality.

## Release boundary
General LaunchGate remains paused. Preserve the existing owner-only PilotAuthorization1, its approved budget and expiry, current Offer/source/commercial configuration, and all audit records. No full R17/R18 or V1 completion is claimed. Deployment and fresh owner-only WhatsApp verification remain separate gates.
