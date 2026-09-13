# rubocop:disable Metrics/MethodLength, Metrics/AbcSize
class CreateWhatsappTemplateRevisions < ActiveRecord::Migration[7.0]
  def change
    create_table :whatsapp_templates do |t|
      t.references :account, null: false, foreign_key: true
      t.references :channel, null: false, foreign_key: { to_table: :channel_whatsapp }
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.timestamps
    end
    add_index :whatsapp_templates, %i[account_id channel_id name], unique: true

    create_table :whatsapp_template_revisions do |t|
      t.references :whatsapp_template, null: false, foreign_key: true, index: { name: 'idx_whatsapp_template_revisions_template' }
      t.references :account, null: false, foreign_key: true
      t.references :channel, null: false, foreign_key: { to_table: :channel_whatsapp }
      t.references :submitted_by, foreign_key: { to_table: :users }
      t.integer :revision_number, null: false
      t.string :language, null: false
      t.string :category, null: false
      t.text :body, null: false
      t.jsonb :media, null: false, default: {}
      t.jsonb :buttons, null: false, default: []
      t.jsonb :variables, null: false, default: []
      t.integer :status, null: false, default: 0
      t.string :provider_template_id
      t.text :rejection_reason
      t.jsonb :submission_failure, null: false, default: {}
      t.datetime :submitted_at
      t.datetime :status_synced_at
      t.string :submission_key, null: false
      t.string :content_digest, null: false
      t.jsonb :meta_charge_estimate, null: false, default: {}
      t.timestamps
    end
    add_index :whatsapp_template_revisions, %i[whatsapp_template_id revision_number], unique: true, name: 'idx_whatsapp_template_revisions_number'
    add_index :whatsapp_template_revisions, :provider_template_id
    add_index :whatsapp_template_revisions, :submission_key, unique: true
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/AbcSize
