Current result: this development checkpoint is superseded by [final combined acceptance](final-acceptance/README.md). The historical checkpoint below is preserved for provenance.

# Final R04/R06 source refresh checkpoint

This is a development checkpoint, not final combined acceptance or a V1 release. The accepted integration remains f2b184e1. R04/R06 issues stay open until the final broad suite and integration checks pass.

R04 final source 089def2 was merged at b9082ca. R06 final correction and evidence 7ea41ec replaces the earlier 842ef46 merge. Its runtime dd49ef9 uses Account FOR NO KEY UPDATE so membership cleanup remains serialized while allowing the real HumanReviewRequest Account foreign key. Independent Standards and Spec reviews found no issues. The actual two-connection deadlock was reproduced before the fix; the R06 correction suite passed20examples.

Combined fixture reconciliation uses a real authorized administrator stream and the actual dashboard payload string keys. It does not weaken runtime broadcast authorization. The original focused run recorded59examples/4failures; the corrected two files plus3membership-concurrency cases passed62examples/0failures in312seconds plus23.88seconds load. Two-file strict Ruby lint passed after six formatting-only corrections. Independent Standards and Spec fixture reviews reported zero findings before the formatting-only adjustment.

The final frontend selection passed71tests across9files. The production build exited0 after2324.5seconds, on staged tree f2dc31d4bf678ae5b8ac049f08c7b7a42b2149ec. Subsequent changes are Ruby, Ruby specs and documentation only; no additional frontend changes or build are claimed.

The earlier partial broad run is not accepted: it encountered two invitation-mail assertions, an incorrect disposable test database suffix, and host-contention timeouts. The fresh root database is ale_release_combined_final_20260910_spec. It preserves the test database guards. A final broad run, with invitation isolation checked first, remains required.

Focused post-format source hashes:

- `spec/jobs/action_cable_broadcast_job_spec.rb`: `cbe24e7402b3de1d552f76d76eb795fbe61a5981d5255f538567892242749a4b`
- `spec/requests/whatsapp_outbound_delivery_spec.rb`: `11795ded2615533d20d9e5c47ddbdd71ad439ea60fcab9a52f12a6b342584ea6`
