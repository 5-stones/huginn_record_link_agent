class AddRecordReferenceTable < ActiveRecord::Migration[4.2]
  def change
    create_table :hrla_record_references do |t|

      t.references :user, null: false, index: true
      t.string :ext_system, null: false
      t.string :model_type, null: false
      t.string :uid, null: false
      t.timestamps null: false

      t.index [:user_id, :system, :model_type, :uid], unique: true, name: 'record_constraint'
    end
  end
end
