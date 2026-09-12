# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::LeadExportCsv do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  it 'resolves fresh account membership only when lazy enumeration begins' do
    export = described_class.new(account_id: account.id, user_id: admin.id, params: {})
    account.account_users.find_by!(user: admin).destroy!
    Current.reset

    expect { export.each_line.to_a }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'yields a header and every filtered row as separate CSV lines' do
    create(:contact, :with_phone_number, account: account, name: 'Included Lead')
    create(:contact, :with_phone_number, account: account, name: 'Excluded Lead')
    export = described_class.new(account_id: account.id, user_id: admin.id, params: { q: 'Included' })

    lines = export.each_line.to_a

    expect(lines.length).to eq(2)
    expect(CSV.parse(lines.join, headers: true).pluck('name')).to eq(['Included Lead'])
  end
end
