# Existing Attempt ID ordering regression

An actual scheduler worker locked historical attempt_number1 (higher row ID)
while waiting for attempt_number2 (lower row ID), because create_or_find_by!
implicitly locked conflicts before the explicit ordered query. Historical
backfill does not promise attempt-number/ID order. A second worker's NOWAIT
probe reproduces the inversion. No new product behavior; this completes the
accepted all-A-before-F and ascending-ID lock contract.
