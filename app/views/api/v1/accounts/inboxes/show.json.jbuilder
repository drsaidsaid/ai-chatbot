inbox_template = Current.account_user&.administrator? ? 'api/v1/models/inbox' : 'api/v1/models/inbox_member'
json.partial! inbox_template, formats: [:json], resource: @inbox, with_branded_email_layout: true
