class CreateOnSiteAttendees < ActiveRecord::Migration[5.0]
  def change
    create_table :on_site_attendees do |t|
      t.string :event_id,       null: false
      t.string :first_name,     null: false
      t.string :last_name,      null: false
      t.string :account_name,   null: false
      t.string :account_number
      t.string :street1,        null: false
      t.string :street2
      t.string :city,           null: false
      t.string :state,          null: false
      t.string :zip_code,       null: false
      t.string :email,          null: false
      t.string :phone,          null: false
      t.string :salesrep
      t.string :badge_type,     null: false
      t.boolean :contact_in_crm
      t.timestamps              null: false
    end
  end
end
