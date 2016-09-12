class CreateEvents < ActiveRecord::Migration[5.0]
  def change
    create_table :events do |t|
      t.string :name,                 null: false
      t.boolean :multiple_locations,  null: false
      t.string :status,               null: false, default: "1"
      t.timestamps                    null: false
    end
  end
end
