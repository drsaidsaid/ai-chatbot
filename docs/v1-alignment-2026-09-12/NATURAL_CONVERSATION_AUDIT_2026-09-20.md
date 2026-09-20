# Natural conversation audit — 20 September 2026

The owner clarified that greetings, discovery, useful answers, qualification and the next step must form a natural conversation. The examples describe adaptable behavior, not a universal script. This is a correction to the already approved product agreement: optional information requirements, suggested wording, skip supplied facts, approved knowledge, business-defined rules and explicit human agreement remain authoritative.

## Verified mismatch

Actual staging bfee0001 and the in-app Offers & qualification screen were inspected. The UI says “Questions are asked in order, one at a time.” SafeConversationReplyService appends qualification_result.next_question to greetings, qualification answers and strategy replies. OfferQualificationService selects missing fields in configured order, prioritizing required questions/group requirements. Local greeting paths use stored prompt wording without the structured-provider localization step. This explains the owner's Habari yako followed by an English revenue question. Updating question wording alone cannot correct this architecture.

Facts already persist as account/contact/Offer-scoped QualificationEvidence JSON values with source messages and typed values. Qualification snapshots, rule results, scores and missing fields exist. Human handover and explicit agreement controls exist. However, live135/136 diagnostics show revenue and business_goal candidates rejected as typed_mismatch; reliable conversational memory has not passed real acceptance. Four paid attempts total USD0.00122655. No claim that a fifth prompt patch fixes it.

The Offer editor currently provides a single next step (answer, enquiry, purchase link, sales call or appointment), not a complete conditional nurture-resource/community policy. Published OPU price currently says quote required, not TZS500000. Existing user examples do not silently publish new commercial facts or invent a resource/group URL.

## Required correction

1. Separate the information/evidence schema from conversational phrasing and order. Owner questions become suggested wording, not mandatory literal utterances. Keep machine-readable deterministic fit/readiness/action rules; let conversational selection use context and unanswered relevant fields.
2. Greet naturally in the Lead's language; never append a financial question merely because an Offer is selected or an earlier question remains unanswered. Use known name/context; ask name only when useful and unknown, not as a prerequisite to receiving information.
3. Answer the current business question from approved information before, or alongside, one useful context-sensitive follow-up. Do not withhold programme details until an interview is completed. Establish business interest and situation before sensitive qualification. Accept volunteered multi-field answers and corrections without re-asking.
4. Maintain one requested conversational language across acknowledgement, explanation and follow-up, including local/provider-free paths. Wording may adapt without changing the owner's required information or claiming unapproved facts.
5. Persist reliable typed observations, source/evidence and uncertainty using existing records. Clarify genuinely ambiguous evidence, not information lost by implementation. Model proposes facts/wording; deterministic approved rules govern eligibility and handover. Avoid opaque model-invented scores.
6. Configure separate outcomes: suitable and ready plus agreement -> team sales-call queue; interested but not currently ready/able to invest -> approved relevant free resource or community invitation if eligible; no relevant business interest -> polite closure, no community invitation or sales chasing. Student/employment status alone is not exclusion: business interest and readiness matter. Financial readiness is separate from business fit.
7. Keep nurturing policy, allowed links, eligibility, prices and suggested wording in editable reviewed business/Offer configuration. Price must come from the published commercial record, not a prompt constant. If a group/video link is absent, do not fabricate one. Human assistance remains separate from sales eligibility.
8. Team view should show business/situation, current revenue separately from desired revenue, obstacle, fit/readiness reasons, unknowns, and explicit agreement. It should explain why to call, rather than expose only a numeric score.

## Pilot acceptance, before claiming readiness

Exercise actual English and Swahili conversations: greeting only; known versus unknown name; asking what the business offers; volunteered business/revenue/goal/obstacle together; correction; interested student with no present budget; uninterested person; ready qualified lead agreeing to a call; unknown business question; stop/human request. Assert one useful question at most, no repeated known facts, no language switching, no invented price/link, and persisted team-visible evidence. Simulations establish mechanics; approved owner-only live tests establish actual response quality. No broader V1 resumption or production launch is implied.

Implementation remains within existing R19/R17 pilot tasks and coordinator integration. Pause further isolated revenue-prompt deployments until this conversation policy and acceptance path are addressed together. Existing security, tenancy, payment, consent, delivery and authority boundaries remain unchanged.

## Setup UI assessment

Step1 — enter Business & offers: usable navigation and account scope are visible, but the first screen starts with revision/name/enabled controls and pricing; the plain-language guided setup is further down. Screenshot: local/ux-audit-20260920/01-offer-setup.png.

Step2 — describe and review: document input and publication history exist (verified from live DOM); they sit within the long Offer editor rather than a clear primary setup progression.

Step3 — configure qualification: live DOM exposes Answer meaning, Answer type, machine-style choices, literal Question to ask, required flags and ordering controls repeatedly. This encourages a fixed interview and contradicts suggested wording. Advanced technical controls should be secondary.

Step4 — preview and publish: Test this setup and commercial preview exist, but separate controls do not clearly demonstrate an entire natural conversation with remembered facts/outcome reasons. Full preview execution was not tested in this read-only assessment.

Strengths: existing CE navigation, clear labels, draft/published distinction and centralized price authority. Accessibility limits: labels/structure inspected, but keyboard navigation, contrast measurements, screen readers and complete responsive interactions were not audited. Repeated identical field labels warrant contextual grouping checks. No WCAG compliance claim.

Correction is tracked in reopened R19 issue45, referencing accepted R09 issue26/R11 issue28 contracts; no duplicate ticket.
