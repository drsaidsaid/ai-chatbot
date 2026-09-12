# Middleware and offload audit

- Rack 3.2.6 `Rack::ETag` buffers only bodies responding to `to_ary`; the
  `Rack::TempfileReaper` body proxy around `ActionDispatch::Response::FileBody`
  does not.
- `Rack::TempfileReaper` closes every registered tempfile both when application
  dispatch raises and when its response body proxy closes. The lifecycle spec
  exercises the latter path without consuming the file body, representing an
  aborted client response.
- `config.action_dispatch.x_sendfile_header` is commented out in both
  `config/environments/production.rb` and `config/environments/staging.rb`.
  No web-server offload path bypasses Rack cleanup in the committed runtime.
- The artifact has no persistent URL, is mode `0600`, and the response is
  `private, no-store`.
