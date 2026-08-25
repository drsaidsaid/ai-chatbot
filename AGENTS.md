# AI Lead Employee Agent Guide

## Architecture

Before changing inbox, authentication, WhatsApp, data, or AI workflow code, read
`docs/adr/0002-owned-inbox-fork.md`. AI Lead Employee is an owned product built
from the Community Edition source; its deployed application, database, user
accounts, branding, APIs, and AI workflow belong to this repository. Meta is the
WhatsApp provider. Preserve the Community Edition MIT notice and exclude
unlicensed enterprise code.

## Community Edition Baseline

The active runtime is the pinned Chatwoot Community Edition `v4.17.0` Rails and
Vue source, adapted as one owned product. Product work should fit into the
Community Edition technology stack, layout conventions, routing patterns,
components, Tailwind usage, and inbox interaction model instead of creating a
separate shell beside it.

- Backend changes live in the Rails application and should use existing models,
  controllers, policies, jobs, services, and specs where possible.
- Frontend changes live in the Vue dashboard application and should use the
  existing dashboard routes, stores, components, `components-next/`, i18n, and
  Tailwind conventions.
- V1 should hide unsupported Community Edition surfaces through navigation,
  permissions, policy, or feature gating. Do not delete broad CE source merely
  because a surface is hidden for V1.
- Do not import, run, modify, or distribute the upstream `enterprise/` directory
  unless a separate license decision is recorded.
- Do not add a parallel Next.js app or standalone prototype UI to production
  paths. Use throwaway prototypes only outside the product runtime and fold the
  answer back into the Rails/Vue baseline.

## Local Commands

- Install backend dependencies with `bundle install`.
- Install frontend dependencies with `pnpm install`.
- Run the local stack with `pnpm dev` or `overmind start -f ./Procfile.dev`.
- Run Ruby specs with `bundle exec rspec`.
- Run frontend tests with `pnpm test`.
- Lint Ruby with `bundle exec rubocop`.
- Lint Vue and JavaScript with `pnpm eslint`.

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
