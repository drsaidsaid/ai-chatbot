# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::LeadExportCsv do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  it 'resolves fresh account membership before creating an artifact' do
    export = described_class.new(account_id: account.id, user_id: admin.id, params: {})
    account.account_users.find_by!(user: admin).destroy!
    Current.reset

    expect(Tempfile).not_to receive(:new)
    expect { export.build }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'rechecks permission after generation and deletes the artifact when membership changed' do
    export = described_class.new(account_id: account.id, user_id: admin.id, params: {})
    artifact = nil
    artifact_path = nil
    allow(Tempfile).to receive(:new).and_wrap_original do |method, *arguments|
      artifact = method.call(*arguments)
      artifact_path = artifact.path
      artifact
    end
    allow(export).to receive(:with_export_snapshot).and_wrap_original do |method, &block|
      method.call(&block).tap { account.account_users.find_by!(user: admin).destroy! }
    end

    expect { export.build }.to raise_error(ActiveRecord::RecordNotFound)
    expect(File).not_to exist(artifact_path)
  end

  it 'writes a header and every filtered row to a disk artifact' do
    create(:contact, :with_phone_number, account: account, name: 'Included Lead')
    create(:contact, :with_phone_number, account: account, name: 'Excluded Lead')
    export = described_class.new(account_id: account.id, user_id: admin.id, params: { q: 'Included' })

    artifact = export.build
    csv = CSV.parse(artifact.read, headers: true)

    expect(csv.length).to eq(1)
    expect(csv.pluck('name')).to eq(['Included Lead'])
  ensure
    artifact&.close!
  end
end
