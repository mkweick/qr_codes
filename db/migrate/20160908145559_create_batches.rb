class CreateBatches < ActiveRecord::Migration[5.0]
  def change
    create_table :batches do |t|
      t.string :event_id,         null: false
      t.string :number,           null: false
      t.string :location
      t.string :description,      null: false
      t.string :batch_type,       null: false
      t.timestamps null: false
    end
  end
end
