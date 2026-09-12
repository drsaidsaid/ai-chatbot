# Red observations

The earlier `send_file` response exposed `to_path`, permitting Rack::Sendfile to
select offload before Rack::TempfileReaper deleted the private temporary file.
Export queries also populated 22 query-cache entries in a five-row, three-batch
test. Initial replacement tests produced three failures: the query-cache growth
and two missing pathless-body examples. The complete red log is retained.
