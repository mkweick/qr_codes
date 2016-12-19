class AddColumnsToCrmCampaign < ActiveRecord::Migration[5.0]
  def change
    add_column :crm_campaigns, :event_start_date, :date
    add_column :crm_campaigns, :event_end_date, :date
    add_column :crm_campaigns, :campaign_id, :string
  end
end
