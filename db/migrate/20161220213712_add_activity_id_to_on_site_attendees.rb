class AddActivityIdToOnSiteAttendees < ActiveRecord::Migration[5.0]
  def change
    add_column :on_site_attendees, :activity_id, :string
  end
end
