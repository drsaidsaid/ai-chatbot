# Official Meta provider contract used by the correction

Primary sources were restricted to Meta's official WhatsApp Business Platform
Postman workspace:

- [Create and manage message templates](https://www.postman.com/meta/whatsapp-business-platform/documentation/3kru5r6/moved-whatsapp-business-management-api?entity=request-13382743-daf94851-9bbe-45d4-8475-35b2fc567c1c)
- [Edit template](https://www.postman.com/meta/whatsapp-business-platform/request/t5tggj5/edit-template)
- [Delete template by ID, which also links the template endpoint reference](https://www.postman.com/meta/whatsapp-business-platform/request/watn41b/delete-template-by-id)

The implemented contract is:

1. Create with `POST /{WABA-ID}/message_templates`, including `name`,
   `language`, `category`, and `components`.
2. Encode BODY samples as `example.body_text`, media HEADER samples as
   `example.header_handle`, and buttons with type-specific fields.
3. Edit an existing provider template with `POST /{TEMPLATE-ID}`, sending only
   editable `category` and `components`; do not present inbox, name, or language
   as editable identity.
4. Treat an edit response of `{ "success": true }` as retaining the same
   provider template ID.
5. Reconcile by known provider ID (when available), name, language, category,
   and semantic components. A result with another ID, another language, an old
   category, or older content cannot resolve the current local revision.

The application uses its existing configurable `WHATSAPP_API_VERSION` setting
with the repository default `v22.0`; the correction removes the template
service's isolated hard-coded `v14.0` value.

No provider price was copied into product code or fixtures as a product claim.
A known estimate is accepted only with amount, currency, market, effective
date, external source, and an explicit confirmation by the authenticated
Business Account admin. The server records admin authority, user ID, and
verification time. Otherwise the charge remains `unknown`, never zero.
