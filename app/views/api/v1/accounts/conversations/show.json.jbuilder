json.partial! 'api/v1/conversations/partials/conversation',
              formats: [:json],
              conversation: @conversation,
              include_control_events: true
