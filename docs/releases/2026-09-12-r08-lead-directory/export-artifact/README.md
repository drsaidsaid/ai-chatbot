# R08 private export artifact correction

- Source commit: `efa2d1b17feff5d8f1a311ec0a7891b2e84224ae`
- Parent: `e8503f1730c763928aea8ee1cd7d2fea0eed52e5`
- Source tree: `17cfa4a55f285dc4a6c731e7ee927b552bc8a02b`

The export is fully generated into a mode `0600` temporary file before response
headers are committed. Generation runs in a repeatable-read snapshot, uses
bounded directory batches, preloads booking assignees per batch, and performs a
fresh administrator-membership check both before and after generation.

The controller registers the artifact with `Rack::RACK_TEMPFILES`, serves it
through Rails `send_file`, and marks the response `private, no-store`. The real
`Rack::TempfileReaper` body proxy removes the artifact when a completed or
aborted response body closes. `Rack::ETag` does not materialize the file body.

The five source-tree artifacts partition the complete committed Git tree.
`source.diff.gz.base64` is the complete parent-to-source diff. Validation decodes
and compares both artifacts with Git. Browser acceptance remains pending because
the Mac is locked.
