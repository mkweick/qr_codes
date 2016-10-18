class AddProcessingStatusToBatches < ActiveRecord::Migration[5.0]
  def change
    add_column :batches, :processing_status, :string, null: false, default: '1'
  end
end
