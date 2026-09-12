# Legacy WhatsApp concurrency failure provenance

The retained failure is `spec/requests/whatsapp_concurrency_spec.rb:125`, where
the fixture calls `LaunchGateEvaluator#approve!`. It fails with missing passing
reviews and qualification accuracy below 85%.

Evidence from the source history:

- The failing example is from `cf83fd9b` (`feat: verify and recover owned WhatsApp receiving`), before R21.
- `ReportBuilder#latest_reviewed_run_for` gained the provider-connection guard and configuration-version filter in `4c8423ad` (`fix: close AI provider control races`), also before R21.
- The R21 runtime delta from `e8c974ec^` to `e8c974ec` changes only account scoping in `MeteredClient` and `RuntimeControl`; it does not change the evaluator, report builder, launch-gate code, or the failing request spec.
- The failing example creates reviewed evaluation runs and updates the launch gate, but does not create an `ai_provider_connection` for the account. Consequently `ReportBuilder` returns no reviewed runs, producing the recorded blocking reasons.

This establishes that the candidate diff does not causally alter the failing path. A
baseline execution of this legacy example was not rerun during this evidence
window, so the claim that the failure reproduces on baseline remains unverified.
The failure is excluded from the accepted R21 spec set; its raw output is retained
in `raw/rails-whatsapp-concurrency-example.log`.
