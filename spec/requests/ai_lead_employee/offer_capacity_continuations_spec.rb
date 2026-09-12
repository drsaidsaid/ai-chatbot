# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Offer qualification from complete capacity statements', type: :request do
  include_context 'with Offer qualification requests'

  [
    ['USD', '1000.00', 'I need more leads now. I am the owner of the agency.', 'I can spend $2500, but my loan must be approved.'],
    ['USD', '1000.00', 'I need more leads now. I am the owner of the agency.', 'I can spend $2500, but this money is only for groceries.'],
    ['USD', '1000.00', 'I need more leads now. I am the owner of the agency.', 'I can spend $2500. But, only if my loan is approved.'],
    ['TZS', '500000.00', 'Nahitaji wateja haraka. Mimi ni mmiliki.', 'Ninaweza kutumia TZS 600000, lakini mkopo wangu lazima uidhinishwe.'],
    ['TZS', '500000.00', 'Nahitaji wateja haraka. Mimi ni mmiliki.', 'Ninaweza kutumia TZS 600000, lakini pesa hizi ni za chakula tu.'],
    ['TZS', '500000.00', 'Nahitaji wateja haraka. Mimi ni mmiliki.', 'Ninaweza kutumia TZS 600000. Lakini, tu kama mkopo wangu utaidhinishwa.'],
    ['USD', '1000.00', 'I need more leads now. I am the owner of the agency.', 'I can spend $2500, but only if my loan is approved.'],
    ['USD', '1000.00', 'I need more leads now. I am the owner of the agency.', 'I can spend $2500, but only on groceries.'],
    ['USD', '1000.00', 'I need more leads now. I am the owner of the agency.', 'I can spend $2500. But only if my loan is approved.'],
    ['USD', '1000.00', 'I need more leads now. I am the owner of the agency.', 'I can spend $2500, but I cannot spend that now.'],
    ['TZS', '500000.00', 'Nahitaji wateja haraka. Mimi ni mmiliki.', 'Ninaweza kutumia TZS 600000, lakini tu kama mkopo wangu utaidhinishwa.'],
    ['TZS', '500000.00', 'Nahitaji wateja haraka. Mimi ni mmiliki.', 'Ninaweza kutumia TZS 600000, lakini kwa chakula tu.'],
    ['TZS', '500000.00', 'Nahitaji wateja haraka. Mimi ni mmiliki.', 'Ninaweza kutumia TZS 600000. Lakini kwa chakula tu.'],
    ['TZS', '500000.00', 'Nahitaji wateja haraka. Mimi ni mmiliki.', 'Ninaweza kutumia TZS 600000, lakini siwezi kutumia pesa hizo sasa.']
  ].each do |currency, minimum, buying_signals, capacity|
    it "does not create HQ or a handoff from the affirmative prefix of #{capacity.inspect}" do
      offer = r09_create_offer(r09_configuration(currency: currency, minimum: minimum))
      conversation = r09_conversation(offer: offer)

      r09_receive(conversation, "#{buying_signals} #{capacity}")
      qualification = r09_qualification(offer)

      expect(qualification).not_to be_highly_qualified
      expect(qualification.evidence_snapshot.dig('budget', 'polarity')).not_to eq('positive')
      expect(qualification.missing_signals).to include('budget')
      expect(LeadHandoff.where(conversation: conversation)).to be_empty
    end
  end

  it 'uses an independently corrected lower amount instead of the earlier sufficient capacity' do
    offer = r09_create_offer(r09_configuration(currency: 'USD', minimum: '1000.00'))
    conversation = r09_conversation(offer: offer)

    incoming, = r09_receive(conversation, 'I need more leads now. I am the owner. I can spend $2500, but my budget is $500.')

    expect(r09_qualification(offer)).to be_unqualified
    expect(r09_qualification(offer).evidence_snapshot.fetch('budget')).to include(
      'polarity' => 'positive', 'amount_minor' => 50_000, 'currency' => 'USD', 'message_id' => incoming.id
    )
    expect(LeadHandoff.where(conversation: conversation)).to be_empty
  end

  it 'still qualifies unconditional Swahili capacity with supported buying signals' do
    offer = r09_create_offer(r09_configuration(currency: 'TZS', minimum: '500000.00'))
    conversation = r09_conversation(offer: offer)

    incoming, = r09_receive(conversation, 'Nahitaji wateja haraka. Mimi ni mmiliki. Ninaweza kutumia TZS 600000 kwa huduma hii.')

    expect(r09_qualification(offer)).to be_highly_qualified
    expect(r09_qualification(offer).evidence_snapshot.fetch('budget')).to include('basis' => 'capacity', 'message_id' => incoming.id)
  end

  it 'keeps budget capacity while independently retaining unknown authority' do
    offer = r09_create_offer(r09_configuration(currency: 'USD', minimum: '1000.00'))
    conversation = r09_conversation(offer: offer)

    incoming, = r09_receive(conversation, 'I need more leads now. I can spend $2500, but I am not sure who decides.')

    expect(r09_qualification(offer)).not_to be_highly_qualified
    expect(r09_qualification(offer).evidence_snapshot.fetch('budget')).to include(
      'polarity' => 'positive', 'amount_minor' => 250_000, 'message_id' => incoming.id
    )
    expect(r09_qualification(offer).evidence_snapshot.fetch('decision_authority')).to include('polarity' => 'unknown')
  end
end
