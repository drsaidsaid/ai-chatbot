# frozen_string_literal: true

class Api::V1::Accounts::Conversations::QualificationOffersController < Api::V1::Accounts::Conversations::BaseController
  def update
    conversation.with_lock('FOR NO KEY UPDATE') do
      authorize conversation, :select_offer?
      selected_id = params[:offer_id].presence
      selected = lock_offer_selection!(selected_id)

      conversation.update!(offer: selected)
      render json: { offer_id: selected&.id, offer_name: selected&.name, version: selected&.configuration_version,
                     selection_version: conversation.offer_selection_version }
    end
  end

  private

  def lock_offer_selection!(selected_id)
    selected = Current.account.qualification_offers.find(selected_id) if selected_id
    Current.account.qualification_offers.where(id: [conversation.offer_id, selected_id].compact)
           .order(:id).lock('FOR NO KEY UPDATE').load
    raise ActiveRecord::RecordNotFound if selected && !selected.reload.enabled?

    selected
  end
end
