# AI Provider Connection

AI Lead Employee uses one server-side AI provider connection per Business
Account. The connection is OpenAI-compatible and provider-neutral; OpenRouter is
the initial adapter.

Administrators can use the account-scoped API to configure, rotate, disable,
and health-check the connection:

- `GET /api/v1/accounts/:account_id/ai_provider_connection`
- `PATCH /api/v1/accounts/:account_id/ai_provider_connection`
- `DELETE /api/v1/accounts/:account_id/ai_provider_connection`
- `POST /api/v1/accounts/:account_id/ai_provider_connection/health_check`

The update request accepts `provider`, `model`, and `api_key`. Supplying a new
`api_key` rotates the credential. Disabling the connection clears the usable
credential and marks the connection disabled.

The API never returns a raw credential. Responses include only provider, model,
status, disabled timestamp, and redacted health metadata. Team members are not
authorized to read, configure, health-check, or infer whether credentials exist.

Credentials are stored in the `ai_provider_connections` table with Rails Active
Record encryption. If encryption is not configured, the application rejects
credential writes instead of storing plaintext in `Account.settings` or another
unencrypted field.

Health checks make a minimal provider request through the configured adapter.
Failures are stored and returned by class only: timeout, authentication, rate
limit, invalid response, safety refusal, disabled, or transport. Provider
failures must create safe orchestration outcomes and must not produce
lead-facing fallback text.
