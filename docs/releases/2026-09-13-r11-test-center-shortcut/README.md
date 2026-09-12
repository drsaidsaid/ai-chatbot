# R11 Test Center shortcut correction evidence

This record is separate from, and does not replace, the historical evidence in
`docs/releases/2026-09-13-r11-grounded-conversation/`.

## Source correction

- Source commit: `04eb40328c0328afed449d6d161bcf11a4e0f110`
- Parent evidence commit: `8af6a2ec40df763459e0c140bc6cc94c14550bea`

The Knowledge workspace's **Try this answer** action now opens the existing
owned Test Center scenario route with `tab=scenarios` and the selected
`knowledge_document_id`. It no longer invokes `KnowledgeDocumentsAPI.test` or
renders an independent inline result in the Knowledge workspace.

## Verification

- `pnpm test app/javascript/dashboard/routes/dashboard/owned/specs/KnowledgeItemsPanel.spec.js`
  passed: 1 file, 6 tests, 0 failures.
- Targeted ESLint completed with 0 errors and 29 pre-existing style warnings in
  `KnowledgeItemsPanel.vue`.
- `git diff --check HEAD^ HEAD` passed.

The correction was limited to the Knowledge workspace and its focused test. No
browser run, broad frontend build, provider action, or live customer action was
performed.
