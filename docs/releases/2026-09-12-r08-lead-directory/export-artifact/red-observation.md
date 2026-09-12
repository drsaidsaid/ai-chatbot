# Red observations

The earlier lazy enumerator held its repeatable-read transaction and checked
authorization only when Rack consumed the response body. This allowed a `200`
response to be committed before authorization failure, retained a database
connection across slow or aborted downloads, and exposed the enumerable to
middleware buffering. Booking export rows also loaded assignees one at a time.

The first artifact test run reached the intended new coverage but had two
fixture defects: the revocation test returned the captured path instead of the
Tempfile, and booking times overlapped an existing uniqueness rule. Both defects
were corrected before the final green run; the application behavior did not need
to be relaxed.
