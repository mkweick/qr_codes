class CreateBatches < ActiveRecord::Migration[5.0]
  def change
    create_table :batches do |t|
      t.string :event_id,         null: false
      t.string :number,           null: false
      t.string :location
      t.string :description,      null: false
      t.string :uploaded_file_id
      t.string :qr_codes_id
      t.string :final_export_id
      t.timestamps null: false
    end
  end
end
