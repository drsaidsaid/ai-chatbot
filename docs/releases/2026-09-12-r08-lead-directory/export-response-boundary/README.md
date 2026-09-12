# R08 export response boundary

- Source commit: `918d4af0489fc3a00d95d43465155090e29b50c1`
- Parent: `232b38ba8c3d17ab2f2b2137bc96c0c6269a337b`
- Source tree: `41573ff875d32b2520b380d361399c226c87da28`

Export generation remains pre-response, mode `0600`, repeatable-read, freshly
authorized before and after generation, and bounded by directory batches. It now
runs with Active Record query caching disabled so distinct batch results do not
accumulate in a request cache.

Rails prepares its internal file response, then a middleware immediately inside
`Rack::TempfileReaper` replaces the path body with a 16 KiB reader. Outer
`Rack::ETag` and `Rack::Sendfile` therefore see neither `to_ary` nor `to_path`,
including when sendfile selection is configured. TempfileReaper owns cleanup on
normal completion, abort, and dispatch failure.

The five source-tree artifacts partition the complete committed Git tree and the
diff artifact covers the complete parent-to-source change. Browser acceptance
remains pending because the Mac is locked.
