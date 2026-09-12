# R09 Offer-switch operation ownership

Source `feffb5b897661246d16d361b76be52b09813a7e7`; prior test cleanup evidence `f2afdc50f6bc3cfe7d0bd1796c171ff7bd309562`.

On an Offer change, synchronously invalidate both operation tokens and clear export/re-consent flags. A new Offer can immediately start its own operation even while the previous request is unresolved. Old completion cannot clear the new busy flag or apply its response/error.

Red source `858c1c71f18553c8f83f38f0953e270de6e6553c`: 21 tests, four expected failures at the still-pending old-request boundary. Green source above: 52 tests passing across nine frontend files. Both operations exercise old resolution and rejection, start the new request before settling the old one, verify the new operation stays busy, then complete it. Existing account-switch coverage remains. Focused ESLint passes. Every run has exact whole-tree before/after evidence. No backend source changes or broad backend/build rerun for this JS-only group.

Source delta contains only LeadsDirectoryPage.vue and its spec. Browser acceptance and coordinator review remain outstanding; no normal-hook commit or deployment.
