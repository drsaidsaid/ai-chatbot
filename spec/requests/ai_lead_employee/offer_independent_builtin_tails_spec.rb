# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Independent built-in answers after a capacity statement', type: :request do
  include_context 'with Offer qualification requests'

  [
    ['USD', '1000.00', 'I can spend $2500, but I handle 20 leads.', 'lead_volume', { 'typed_value' => 20 }],
    ['USD', '1000.00', 'I can spend $2500, but I want to start tomorrow.', 'urgency', {}],
    ['TZS', '500000.00', 'Ninaweza kutumia TZS 600000, lakini ninapokea 20 maulizo.', 'lead_volume', { 'typed_value' => 20 }],
    ['TZS', '500000.00', 'Ninaweza kutumia TZS 600000, lakini nataka kuanza kesho.', 'urgency', {}]
  ].each do |currency, minimum, statement, field, typed|
    it "preserves independently asserted #{field} during extraction: #{statement}" do
      facts = AiLeadEmployee::QualificationEvidenceExtractor.new(statement).observations

      expect(facts.fetch('budget')).to include('polarity' => 'positive', 'currency' => currency)
      expect(facts.fetch(field)).to include('polarity' => 'positive', **typed)
    end

    it "stores both capacity and independent #{field} from the actual incoming message: #{statement}" do
      offer = r09_create_offer(r09_configuration(currency: currency, minimum: minimum))
      conversation = r09_conversation(offer: offer)

      incoming, = r09_receive(conversation, statement)
      snapshot = r09_qualification(offer).evidence_snapshot

      expect(snapshot.fetch('budget')).to include('polarity' => 'positive', 'message_id' => incoming.id)
      expect(snapshot.fetch(field)).to include('polarity' => 'positive', 'message_id' => incoming.id, **typed)
    end
  end
end
