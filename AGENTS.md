<!-- BEGIN:nextjs-agent-rules -->

# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->

# AI Lead Employee Agent Guide

## Architecture

Before changing inbox, authentication, WhatsApp, data, or AI workflow code, read
`docs/adr/0002-owned-inbox-fork.md`. AI Lead Employee is an owned product built
from the Community Edition source; its deployed application, database, user
accounts, branding, APIs, and AI workflow belong to this repository. Meta is the
WhatsApp provider. Preserve the Community Edition MIT notice and exclude
unlicensed enterprise code.

## Delivery Flow

For the owned-fork migration and every multi-session feature:

1. Update `CONTEXT.md`, the PRD, technical design, and ADRs until the current
   decision is unambiguous.
2. Update `docs/issues/` as tracer-bullet tickets with explicit blockers.
3. Work blockers first. Keep one ticket branch focused on one demonstrable path.
4. Drive each behavior test-first, run the relevant tests and build, review the
   diff against the ticket, then commit.
5. Record any hard-to-reverse decision as an ADR before building on it.

Read `docs/OWNED_INBOX_DELIVERY_PATH.md` when planning or starting an owned-inbox
migration ticket. Read `CONTEXT.md` before naming domain concepts.
