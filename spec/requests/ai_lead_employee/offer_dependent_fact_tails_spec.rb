# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dependent financial tails cannot create buying facts', type: :request do
  include_context 'with Offer qualification requests'

  [
    ['USD', '1000.00', 'I want to start now. I am the owner.', 'I can spend $2500, but I need it for groceries.'],
    ['USD', '1000.00', 'I want to start now. I am the owner.', 'I can spend $2500, but I need the bank to approve it.'],
    ['TZS', '500000.00', 'Nataka kuanza leo. Mimi ni mmiliki.', 'Ninaweza kutumia TZS 600000, lakini nahitaji hizo kwa chakula.'],
    ['TZS', '500000.00', 'Nataka kuanza leo. Mimi ni mmiliki.', 'Ninaweza kutumia TZS 600000, lakini nahitaji benki iidhinishe.']
  ].each do |currency, minimum, other_signals, statement|
    it "preserves the financial dependency during pure extraction: #{statement}" do
      facts = AiLeadEmployee::QualificationEvidenceExtractor.new(statement).observations

      expect(facts.dig('budget', 'polarity')).not_to eq('positive')
      expect(facts).not_to have_key('problem')
      expect(facts).not_to have_key('decision_authority')
    end

    it "cannot create HQ or a false problem from a dependent incoming statement: #{statement}" do
      offer = r09_create_offer(r09_configuration(currency: currency, minimum: minimum))
      conversation = r09_conversation(offer: offer)
      r09_receive(conversation, "#{other_signals} #{statement}")
      qualification = r09_qualification(offer)

      expect(qualification).not_to be_highly_qualified
      expect(qualification.missing_signals).to include('budget', 'problem')
      expect(qualification.evidence_snapshot).not_to have_key('problem')
      expect(LeadHandoff.where(conversation: conversation)).to be_empty
    end
  end

  [
    ['USD', '1000.00', 'I can spend $2500, but I need more leads.'],
    ['TZS', '500000.00', 'Ninaweza kutumia TZS 600000, lakini nahitaji wateja zaidi.']
  ].each do |currency, minimum, statement|
    it "retains a concretely independent business need: #{statement}" do
      facts = AiLeadEmployee::QualificationEvidenceExtractor.new(statement).observations
      expect(facts.dig('budget', 'polarity')).to eq('positive')
      expect(facts.dig('problem', 'polarity')).to eq('positive')

      offer = r09_create_offer(r09_configuration(currency: currency, minimum: minimum))
      conversation = r09_conversation(offer: offer)
      incoming, = r09_receive(conversation, statement)
      snapshot = r09_qualification(offer).evidence_snapshot
      expect(snapshot.fetch('budget')).to include('polarity' => 'positive', 'message_id' => incoming.id)
      expect(snapshot.fetch('problem')).to include('polarity' => 'positive', 'message_id' => incoming.id)
    end
  end

  it 'still records a complete explicit replacement budget instead of retaining the earlier amount' do
    statement = 'I can spend $2500, but my budget is $500.'
    expect(AiLeadEmployee::QualificationEvidenceExtractor.new(statement).observations.fetch('budget')).to include('amount_minor' => 50_000)
    offer = r09_create_offer(r09_configuration(currency: 'USD', minimum: '1000.00'))
    conversation = r09_conversation(offer: offer)
    r09_receive(conversation, statement)

    expect(r09_qualification(offer)).to be_unqualified
    expect(r09_qualification(offer).evidence_snapshot.fetch('budget')).to include('amount_minor' => 50_000)
  end
end
