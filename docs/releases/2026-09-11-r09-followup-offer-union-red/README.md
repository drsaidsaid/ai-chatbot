# Reviewer Offer-union deadlock regression

ReviewP1 of750bfd identified two individually ordered Offer-lock queries whose
union was unordered. Two actual workers with opposite stale A/B Results
reproduced PostgreSQL deadlock in OfferDeliveryContext.lock_offers!. No prior
race proved this union ordering. This is red source, not a release.
