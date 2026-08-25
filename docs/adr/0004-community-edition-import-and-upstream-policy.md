---
status: accepted
---

# Import Community Edition into the owned product root and review upstream updates

The pinned Chatwoot Community Edition release `v4.17.0`
(`b34f5b71a4d7f41fa87cf2b32260e2c887817e54`) becomes the source baseline for
AI Lead Employee. Its source will be imported into this repository's root on a
dedicated baseline commit, with the Community Edition MIT license and copyright
notice retained. The current prototype remains recoverable from repository
history and is not a production foundation.

The Rails/Vue dashboard, inbox layout, component system, Tailwind conventions,
and interaction patterns remain the product foundation. AI Lead Employee
features should be integrated as native-feeling Community Edition-derived
surfaces, not as a visually or technically separate application shell.

The upstream repository is retained as a read-only `upstream-chatwoot` remote.
It is not deployed as a separate service and it is not a runtime dependency.
The upstream `enterprise/` directory is never imported into the owned baseline.

Product-specific code lives in clearly owned modules, migrations, and branded
frontend areas that follow Community Edition conventions. Upstream updates are
adopted deliberately:

1. Review upstream release notes and security advisories.
2. Bring selected Community Edition commits into a dedicated update branch.
3. Resolve conflicts in favor of the documented AI Lead Employee domain model.
4. Run the full owned-product test suite and a staging WhatsApp smoke test.
5. Record the upstream release and any material conflict decision in the merge
   commit or a new ADR.

Routine feature work must not modify vendored Enterprise code, rely on upstream
cloud configuration, or introduce Chatwoot credentials.

## Consequences

- The deployed product has one application repository and one owned runtime.
- Source upgrades are controlled maintenance work rather than invisible package
  updates.
- The import ticket must replace the prototype runtime with the Community
  Edition Rails and Vue foundation before any production feature ticket starts.
