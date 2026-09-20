# Natural setup UI: local acceptance

Candidate 763f1d6c, integrated with conversation-policy baseline 82a2ddfd.
Six sections follow the same visual, DOM and keyboard order. Technical question controls and score/rule controls use native disclosures; ordinary meaning, suggested wording, purpose, Enabled and Remove remain approachable. Price/source publication authority and serialization remain unchanged. Copy explicitly says multi-turn preview and response customization are not available yet.

Validation: focused OfferConfigurationPanel Vitest 23/23, including actual section DOM order; ESLint zero errors and 14 existing warnings; normal candidate hooks. Production Vite build passed in 70 seconds, with existing chunk-size/Browserslist warnings.

Coordinator used Codex in-app browser against loopback port3220, synthetic database ale_owner_preview_20260919 and WebMock blocking external network. At desktop1280x900, added an information requirement, saved an empty prompt and observed the visible validation alert. Corrected wording, saved and reloaded: wording persisted and revision increased2→3. At390x844, document width remained390, all six headings followed agreed order, disclosures defaulted closed; Enter opened per-question technical controls and Tab moved into its input. Viewport reset and temporary tab closed. No paid provider call or customer send.

Browser review caught stale directional price-help copy; replaced with a section-name reference. Final production build is recorded in coordinator execution state. This accepts the UI organization slice only; adaptive conversation, conditional nurture outcomes and actual response-quality acceptance remain open. Not deployed by this acceptance.
