class AddRecordLinkAgentTables < ActiveRecord::Migration[4.2]
  def change

    create_table :hrla_records do |t|

      t.references :user, null: false, index: true
      t.string :ext_system, null: false
      t.string :model_type, null: false
      t.string :external_id, null: false
      t.timestamps null: false

      t.index [:user_id, :ext_system, :model_type, :external_id], unique: true, name: 'record_constraint'
    end

    create_table :hrla_record_links do |t|

      t.references :source_record, null: false, index: true
      t.references :target_record, null: false, index: true

      t.index [:source_record_id, :target_record_id], unique: true, name: 'link_constraint'
    end
  end
end
