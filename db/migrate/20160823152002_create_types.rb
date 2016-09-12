class CreateTypes < ActiveRecord::Migration
  def change
    create_table :types do |t|
    	t.string :name,                 null: false
      t.boolean :multiple_locations,  null: false
      t.timestamps                    null: false
    end
  end
end
