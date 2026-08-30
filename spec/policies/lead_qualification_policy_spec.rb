# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LeadQualificationPolicy, type: :policy do
  subject(:policy) { described_class }

  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:team_member) { create(:user, account: account, role: :agent) }
  let(:admin_context) { { user: admin, account: account, account_user: admin.account_users.find_by(account: account) } }
  let(:team_member_context) { { user: team_member, account: account, account_user: team_member.account_users.find_by(account: account) } }
  let(:qualification) { create(:lead_qualification, account: account) }
  let(:other_qualification) { create(:lead_qualification, account: other_account) }

  permissions :show?, :evidence? do
    it 'allows an admin to use a Lead Qualification inside the resolved Business Account' do
      expect(policy).to permit(admin_context, qualification)
    end

    it 'allows a team member to use a Lead Qualification inside the resolved Business Account' do
      expect(policy).to permit(team_member_context, qualification)
    end

    it 'denies an admin when the Lead Qualification belongs to another Business Account' do
      expect(policy).not_to permit(admin_context, other_qualification)
    end

    it 'denies a team member when the Lead Qualification belongs to another Business Account' do
      expect(policy).not_to permit(team_member_context, other_qualification)
    end
  end

  describe LeadQualificationPolicy::Scope do
    it 'returns only Lead Qualifications inside the resolved Business Account' do
      qualification
      other_qualification

      resolved = described_class.new(admin_context, LeadQualification).resolve

      expect(resolved).to contain_exactly(qualification)
    end

    it 'returns only Lead Qualifications inside the team members resolved Business Account' do
      qualification
      other_qualification

      resolved = described_class.new(team_member_context, LeadQualification).resolve

      expect(resolved).to contain_exactly(qualification)
    end

    it 'returns no Lead Qualifications when there is no Business Account membership' do
      outsider_context = { user: create(:user), account: account, account_user: nil }

      resolved = described_class.new(outsider_context, LeadQualification).resolve

      expect(resolved).to be_empty
    end
  end
end
