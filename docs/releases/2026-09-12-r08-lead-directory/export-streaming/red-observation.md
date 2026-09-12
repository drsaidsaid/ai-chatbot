# Intentional red history

The first implementation run executed 24 examples. Five failed: both new CSV
service examples raised `ActiveRecord::TransactionIsolationError`, and the three
export requests returned 500 for the same reason. RSpec already wraps these tests
in a transaction, and PostgreSQL cannot change isolation inside a nested
transaction. The final implementation reuses an existing transaction in tests
and opens its own repeatable-read transaction during normal lazy enumeration.

The failing output was displayed but not redirected. This is a contemporaneous
failure record, not a reconstructed verbatim log. `pre-final-green.txt` contains
the subsequent 24-example green run; `final-green.txt` contains the final
25-example run after explicit Team Member refusal coverage.

