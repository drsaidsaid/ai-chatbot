class BackfillWhatsappOutboundEvidence < ActiveRecord::Migration[7.2]
  def up
    backfill_deliveries
    publish_evidence
    record_reviews
    mark_outbox_unknown
  end

  def down
    # Evidence survives rollback so a subsequent upgrade cannot replay it.
  end

  private

  def backfill_deliveries
    # A legacy status of "sent" only meant locally created. A provider ID is the
    # only acceptance evidence we can carry forward without replaying history.
    execute <<~SQL.squish
      INSERT INTO whatsapp_outbound_deliveries
        (account_id, conversation_id, message_id, observed_control_version, state,
         provider_message_id, failure_code, created_at, updated_at)
      SELECT m.account_id, m.conversation_id, m.id, c.control_version,
             CASE WHEN NULLIF(m.source_id, '') IS NULL THEN 'unknown' ELSE 'accepted' END,
             NULLIF(m.source_id, ''),
             CASE WHEN NULLIF(m.source_id, '') IS NULL THEN 'legacy_acceptance_unknown' END,
             CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM messages m
      JOIN conversations c ON c.id = m.conversation_id AND c.account_id = m.account_id
      JOIN inboxes i ON i.id = m.inbox_id AND i.id = c.inbox_id AND i.account_id = m.account_id
      WHERE i.channel_type = 'Channel::Whatsapp' AND m.message_type IN (1, 3)
        AND m.private = FALSE AND COALESCE(m.content_attributes->>'external_echo', '') NOT IN ('true', '1')
      ON CONFLICT (message_id) DO NOTHING
    SQL
  end

  def publish_evidence
    execute <<~SQL.squish
      UPDATE messages m
      SET content_attributes = COALESCE(m.content_attributes::jsonb, '{}'::jsonb) ||
          jsonb_build_object('whatsapp_delivery', jsonb_build_object('state', d.state, 'failure_code', d.failure_code))
      FROM whatsapp_outbound_deliveries d WHERE m.id = d.message_id
    SQL
  end

  def record_reviews
    execute <<~SQL.squish
      INSERT INTO human_review_requests
        (account_id, conversation_id, lead_message_id, reason, status, question, created_at, updated_at)
      SELECT account_id, conversation_id, message_id, 9, 0,
             'Legacy delivery outcome unknown. Check provider history before contacting the Lead again.', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM whatsapp_outbound_deliveries WHERE failure_code = 'legacy_acceptance_unknown'
      ON CONFLICT (account_id, conversation_id, lead_message_id, reason) DO NOTHING
    SQL
  end

  def mark_outbox_unknown
    execute <<~SQL.squish
      UPDATE outbox_events e SET state = 4, failure_class = 'legacy_acceptance_unknown', failed_at = CURRENT_TIMESTAMP, delivered_at = NULL
      FROM whatsapp_outbound_deliveries d
      WHERE e.aggregate_type = 'Message' AND e.aggregate_id = d.message_id AND e.account_id = d.account_id
        AND d.failure_code = 'legacy_acceptance_unknown'
    SQL
  end
end
