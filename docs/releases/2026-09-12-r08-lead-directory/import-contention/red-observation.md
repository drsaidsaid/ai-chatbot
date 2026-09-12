# Intentional red history

Before the table-lock implementation, four targeted examples ran and three new
concurrency examples failed:

- two competing applies both returned completed and created duplicate phone identity;
- apply blocked behind a direct Contact update until the test's eight-second join timeout;
- a slow second insert completed after eight seconds instead of respecting the five-second deadline.

The 101-row preview limit example already passed. The red output was displayed but
not redirected, so this is a contemporaneous observation rather than a verbatim
log. `candidate-green.txt` records the first four-example green run. The final
regular and concurrency logs record 26 and 4 passing examples respectively.

