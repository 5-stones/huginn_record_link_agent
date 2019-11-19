class HuginnRecordLinkAgent::RecordLink < ActiveRecord::Base
  self.table_name = "hrla_record_links"

  # AVAILABLE FIELDS
  # user / user_id
  # source_type
  # source_id
  # target_type
  # target_id

  belongs_to :source_record, class_name: 'HuginnRecordLinkAgent::ExternalRecordRef', foreign_key: :source_record_id
  belongs_to :target_record, class_name: 'HuginnRecordLinkAgent::ExternalRecordRef', foreign_key: :target_record_id

  validates_presence_of :source_record_id, :target_record_id
  validates :source_record_id, uniqueness: {scope: [:target_record_id]}
end
