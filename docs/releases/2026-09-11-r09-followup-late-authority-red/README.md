# Late authority discovery regression

After a prefix observed no membership/provider connection, two actual delivery
workers accepted replies using newly inserted authority rows discovered after
entering the suffix. That would acquire a previously unowned R after A/F/D/M/E.
The required fix must use only prefix-owned authority records (including absence),
preserving all existing provider configuration/day/allowance checks.
Initial run4/2:both late-authority cases fail; both concurrent review-rejection
orders pass. This is not a releasable checkpoint.
