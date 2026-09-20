# Integrated pilot controls acceptance

R17 pilot subset candidate `a431cd30` merged with accepted R19 alternative requirements as `b15dc3b8`. The merge was clean; the shared handoff service retains grouped qualification checks and explicit suppression of unapproved external pilot alerts.

Coordinator ran the union of the R17 model, activation, metered admission, dispatch, intake, handoff and PostgreSQL concurrency specs plus R19 requirement-group and business-source request specs on the integrated tree: **126 examples, 0 failures**, 44.05 seconds. Synthetic local database only, no provider HTTP or WhatsApp sends. Normal commit hooks passed; R17-exclusive runtime/spec/schema files match the reviewed candidate exactly.

The new pilot-specific test uses two real PostgreSQL connections competing for the last attempt. Explicit operator stops survive provider failure cleanup; unknown provider cost does not grant new admission. The provider-side limit is a risk control, not a guarantee against provider overshoot.

R19 browser/build acceptance remains valid: no frontend file changed in this integration. Use its verified assets from candidate84941d51; do not run Vite on the shared VPS.

This accepts only local pilot-control code. No active authorization or permissions were seeded, no payment/credits were fabricated, and the general launch gate remains paused. Full R17/R18 and parent issues stay open. Staging is still0ce119da until a separately verified update; live response quality and concrete spending authorization remain outstanding.
