class AddRecordLinkTable < ActiveRecord::Migration[4.2]
  def change
    create_table :hrla_record_links do |t|
      # TODO: add a huginn user scope
      # TODO: add indexing
      # TODO: add uniqueness contstraint on user, namespace, inbound_id, outbound_id (composite key?)
      # TODO: make note of how namespacing works
      # TODO: none of these fields can be null

      t.references :source_record, null: false, index: true
      t.references :target_record, null: false, index: true

      t.index [:source_record_id, :target_record_id], unique: true, name: 'link_constraint'
    end
  end
end
