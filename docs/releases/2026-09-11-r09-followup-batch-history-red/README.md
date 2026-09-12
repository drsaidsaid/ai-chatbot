# Batch cancellation and historical migration regressions

Lifecycle implementation development source:33 focused checks and17 committed
worker interleavings passed. Additional regression tests failed:1 historical
migration case misclassified empty provider source ID as accepted;1 real
multi-Conversation opt-out worker held Delivery1 while waiting for Attempt2.
This source is not releasable. Frozen red reproduction follows.
