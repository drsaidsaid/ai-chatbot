# Red observations

A deliberately matching `ActiveRecord::LockWaitTimeout` from `after_commit` was
translated to `import_retry_later` despite the Contact being durable. A separate
100-row preview made 100 Contact identity queries. The two focused examples
failed before correction and are retained in the red log.
