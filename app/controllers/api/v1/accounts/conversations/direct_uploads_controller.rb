class Api::V1::Accounts::Conversations::DirectUploadsController < ActiveStorage::DirectUploadsController
  include DeviseTokenAuth::Concerns::SetUserByToken
  include RequestExceptionHandler
  include AccessTokenAuthHelper
  include EnsureCurrentAccountHelper

  skip_before_action :verify_authenticity_token, if: :authenticate_by_access_token?

  around_action :handle_with_exception
  before_action :authenticate_access_token!, if: :authenticate_by_access_token?
  before_action :validate_bot_access_token!, if: :authenticate_by_access_token?
  before_action :authenticate_user!, unless: :authenticate_by_access_token?
  before_action :current_account
  before_action :validate_token_api_access, if: :authenticate_by_access_token?
  before_action :conversation

  def create
    return if @conversation.nil? || @current_account.nil?

    super
  end

  private

  def authenticate_by_access_token?
    request.headers[:api_access_token].present? || request.headers[:HTTP_API_ACCESS_TOKEN].present?
  end

  def validate_token_api_access
    return if Current.account.api_and_webhooks_enabled?

    render json: { error: 'API access is not enabled for this account' }, status: :forbidden
  end

  def conversation
    @conversation ||= AiLeadEmployee::AccessScope.new(account: Current.account, user: current_user)
                                                 .conversations.find_by!(display_id: params[:conversation_id])
  end

  def blob_args
    super.tap do |args|
      args[:metadata] = (args[:metadata] || {}).merge(
        'r06_account_id' => Current.account.id, 'r06_user_id' => current_user.id, 'r06_conversation_id' => @conversation.id
      )
    end
  end
end
