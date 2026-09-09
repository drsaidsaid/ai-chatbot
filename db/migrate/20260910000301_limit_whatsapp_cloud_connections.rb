class LimitWhatsappCloudConnections < ActiveRecord::Migration[7.1]
  def change
    add_index :channel_whatsapp, :account_id, unique: true,
                                              where: "provider = 'whatsapp_cloud'", name: 'index_whatsapp_cloud_one_per_account'
  end
end
