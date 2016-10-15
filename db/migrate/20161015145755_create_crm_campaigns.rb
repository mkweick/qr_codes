class CreateCrmCampaigns < ActiveRecord::Migration[5.0]
  def change
    create_table :crm_campaigns do |t|
      t.string :event_id, null: false
      t.string :code,     null: false
      t.string :name,     null: false
      t.timestamps        null: false
    end
  end
end
