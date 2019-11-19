class HuginnRecordLinkAgent::Record < ActiveRecord::Base

  self.table_name = "hrla_records"

  # AVAILABLE FIELDS
  # system
  # model_type
  # external_id (external id)

  validates_presence_of :user_id, :ext_system, :model_type, :external_id
  validates :user_id, uniqueness: {scope: [:ext_system, :model_type, :external_id]}

  has_one :user

  has_many :source_links, class_name: 'HuginnRecordLinkAgent::RecordLink', foreign_key: :target_record_id
  has_many :source_records, through: :source_links

  has_many :target_links, class_name: 'HuginnRecordLinkAgent::RecordLink', foreign_key: :source_record_id
  has_many :target_records, through: :target_links

  def all_records
    return HuginnRecordLinkAgent::RecordLink.where("source_record_id = ? OR target_record_id = ?", self.id, self.id)
  end
end
