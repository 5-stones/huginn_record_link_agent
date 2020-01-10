require_relative '../models/record_link'
require_relative '../models/record'

class HuginnRecordLinkAgent::RecordLinkLookupTool

  # This is a utility class for managing the lookup of RecordLink instances.
  # As there are cases in which these links may need to be fetched in batch, the
  # process has been isolated from the Agent to make things easier to maintain

  def self.lookup_records(user, lookup_system, lookup_type, lookup_ids, filter_system, filter_type, fetch_type = nil)

    results = []
    lookup_ids.each do |lookup_id|
      results << get_record_links(user, lookup_system, lookup_type, lookup_id, filter_system, filter_type, fetch_type)
    end

    return results
  end

  def self.get_record_links(user, lookup_system, lookup_type, lookup_id, filter_system, filter_type, fetch_type = nil)

    lookup_record = HuginnRecordLinkAgent::Record.find_or_create_by(user_id: user.id, ext_system: lookup_system, model_type: lookup_type, external_id: lookup_id)
    source_records = []
    target_records = []

    if lookup_record.nil?
      link_error = get_link_error(
        "Failed to locate lookup record for #{lookup_system} #{lookup_type} #{lookup_id}",
        lookup_system,
        lookup_type,
        lookup_id,
        filter_system,
        filter_type,
        fetch_type
      )

      return { link_status: 500, link_error: link_error }
    end

    if fetch_type == 'source'
      source_records = filter_links(lookup_record.source_records, filter_system, filter_type)
    elsif fetch_type == 'target'
      target_records = filter_links(lookup_record.target_records, filter_system, filter_type)
    else
      source_records = filter_links(lookup_record.source_records, filter_system, filter_type)
      target_records = filter_links(lookup_record.target_records, filter_system, filter_type)
    end

    if (source_records.any? || target_records.any?)
      return { link_status: 200, lookup_record: lookup_record, targets: target_records, sources: source_records }
    else
      link_error = get_link_error(
        "No matching #{fetch_type == 'source' || fetch_type == 'target' ? fetch_type : ''} records found",
        lookup_system,
        lookup_type,
        lookup_id,
        filter_system,
        filter_type,
        fetch_type
      )

      Rails.logger.error(link_error)
      return { link_status: 404, link_error: link_error }
    end
  end

  #---------------  UTILITY METHODS  ---------------#
  def self.get_link_error(message, lookup_system, lookup_type, lookup_id, filter_system, filter_type, fetch_type = nil)
    return {
      scope: 'HuginnRecordLinkAgent::RecordLinkLookupTool',
      message: message,
      lookup_system: lookup_system,
      lookup_type: lookup_type,
      lookup_id: lookup_id,
      filter_system: filter_system,
      filter_type: filter_type,
      fetch_type: fetch_type.present? ? fetch_type : 'all'
    }
  end

  # Filters the links collection by system/type as provided
  def self.filter_links(links, filter_system, filter_type)
    links = links.where(ext_system: filter_system) unless filter_system.blank?
    links = links.where(model_type: filter_type) unless filter_type.blank?

    return links
  end

end
