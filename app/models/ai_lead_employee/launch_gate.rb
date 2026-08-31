# frozen_string_literal: true

# == Schema Information
#
# Table name: ai_lead_employee_launch_gates
#
#  id                                 :bigint           not null, primary key
#  approval_notes                     :text
#  approved_at                        :datetime
#  pilot_conversations_reviewed_count :integer          default(0), not null
#  report                             :jsonb            not null
#  team_roleplay_completed            :boolean          default(FALSE), not null
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  account_id                         :bigint           not null
#  approved_by_id                     :bigint
#
# Indexes
#
#  index_ai_lead_employee_launch_gates_on_account_id      (account_id) UNIQUE
#  index_ai_lead_employee_launch_gates_on_approved_by_id  (approved_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (approved_by_id => users.id)
#
class AiLeadEmployee::LaunchGate < ApplicationRecord
  self.table_name = 'ai_lead_employee_launch_gates'

  REQUIRED_PILOT_REVIEWS = 3
  MINIMUM_QUALIFICATION_ACCURACY = 0.85

  belongs_to :account
  belongs_to :approved_by, class_name: 'User', optional: true

  validates :account_id, uniqueness: true
  validates :pilot_conversations_reviewed_count, numericality: { greater_than_or_equal_to: 0 }

  def self.for(account)
    find_or_create_by!(account: account)
  end

  def self.live_ai_enabled?(account)
    gate = find_by(account: account)
    return false unless gate&.approved?

    AiLeadEmployee::Evaluation::LaunchGateEvaluator.new(account: account).approval_ready?
  end

  def approved?
    approved_at.present?
  end

  def approve!(user:, report:)
    update!(
      approved_by: user,
      approved_at: Time.current,
      report: report,
      approval_notes: report['approval_notes'].presence || approval_notes
    )
  end
end
