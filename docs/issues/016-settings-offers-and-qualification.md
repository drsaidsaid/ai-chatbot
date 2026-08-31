# Settings Offers and Qualification

Status: Done

## Completed behavior

- Account administrators can manage the AI provider, offers, qualification questions, and budget ranges inside the owned Chatwoot settings shell.
- Provider credentials remain encrypted and redacted; health checks and disable operations use the account-scoped Rails API.
- Qualification settings use the existing account-scoped controller and preserve tenant authorization.

## Verification

- Live browser QA confirmed both settings routes render without console errors or horizontal overflow.
- AI provider request specs and qualification configuration controller specs pass.

