# frozen_string_literal: true

class AiLeadEmployee::OfferConfigurationRevision < ApplicationRecord
  self.table_name = 'offer_configuration_revisions'
  belongs_to :account
  belongs_to :offer, class_name: 'AiLeadEmployee::Offer'

  def readonly?
    persisted?
  end
end
