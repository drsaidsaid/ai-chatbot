# frozen_string_literal: true

module OwnedStorageAccess
  extend ActiveSupport::Concern

  included do
    before_action :private_media_cache
    before_action :authorize_owned_blob
    after_action :private_media_cache
  end

  private

  def authorize_owned_blob
    blob = requested_blob
    return if blob.nil?

    if AiLeadEmployee::BlobAccess.new(blob: blob, user: AiLeadEmployee::BrowserSession.user(cookies)).allowed?
      redirect_legacy_download(blob)
      return
    end

    head :forbidden
  end

  def requested_blob
    signed_id = params[:signed_blob_id].presence || params[:signed_id]
    return ActiveStorage::Blob.find_signed(signed_id) if signed_id
    return unless params[:encoded_key]

    key = ActiveStorage.verifier.verified(params[:encoded_key], purpose: :blob_key)
    return unless key

    original_key = key[:key].to_s.delete_prefix('variants/').split('/').first
    ActiveStorage::Blob.find_by!(key: original_key)
  end

  def private_media_cache
    response.headers['Cache-Control'] = 'private, no-store'
  end

  # ActiveStorage's proxy helper otherwise commits public headers while the
  # body is still streaming, before an after_action can replace them.
  def http_cache_forever(**_options)
    private_media_cache
    yield
  end

  def redirect_legacy_download(blob)
    return unless is_a?(ActiveStorage::Blobs::RedirectController) || is_a?(ActiveStorage::Representations::RedirectController)

    resource = params[:variation_key] ? blob.representation(params[:variation_key]) : blob
    redirect_to Rails.application.routes.url_helpers.rails_storage_proxy_path(resource, disposition: params[:disposition])
  end
end
