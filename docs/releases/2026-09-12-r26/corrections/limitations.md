# Remaining correction evidence work

1. One final browser retry was mistakenly started without the loopback provider
   override and reached Meta's default hostname with a synthetic token. Meta
   rejected it immediately for invalid authentication; it created no template
   and no customer message. The corrected rerun used the controlled loopback
   provider, and `Message.count` remained zero.
2. The browser path used synthetic account, inbox, user, and template records;
   it is evidence of application behavior against the controlled boundary, not
   evidence of a live provider approval.
3. The evidence is focused on R26 and is not a whole-repository test or lint
   claim.

The original parent evidence remains an immutable record of the earlier frozen
candidate and its then-known limitations.
