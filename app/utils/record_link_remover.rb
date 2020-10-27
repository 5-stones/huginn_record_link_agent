class HuginnRecordLinkAgent::RecordLinkRemover

  # This is a utility class that will remove record link entried from the system.
  # The goal here is to manage links between systems where soft deletes are not an
  # option. Conventionally, this process should only be run in edge cases.
  #
  # Additionally, it is important to note that this simply deletes the RecordLink
  # instances. The `Record` instances are retained

  def self.delete_links(
    user,
    source_system,
    source_type,
    source_id,
    target_system,
    target_type,
    target_id,
    is_dry_run
  )

    filters = {
      source_system: source_system,
      source_type: source_type,
      source_id: source_id,
      target_system: target_system,
      target_type: target_type,
      target_id: target_id
    }

    begin

      records = HuginnRecordLinkAgent::RecordLink
        .joins('LEFT JOIN hrla_records source_record ON source_record.id = hrla_record_link.source_record_id')
        .joins('LEFT JOIN hrla_records target_record ON target_record.id = hrla_record_link.target_record_id')
        .where('source_record.user_id = ?', user.id)
        .where('target_record.user_id = ?', user.id)

      records = build_where_clause('source_record.ext_system = ?', source_system)
      records = build_where_clause('source_record.model_type = ?', source_type)
      records = build_where_clause('source_record.ext_id = ?', source_id)

      records = build_where_clause('target_record.ext_system = ?', target_system)
      records = build_where_clause('target_record.model_type = ?', target_type)
      records = build_where_clause('target_record.ext_id = ?', target_id)

      Rails.logger.info({
        scope: 'RecordLinkRemover',
        process: 'Delete record links',
        message: "#{records.count} will be deleted with the specified filters",
        filters: filters,
        user: user
      })

      unless (is_dry_run)
        records.delete_all
      end

    rescue => e
      delete_error = {
        scope: 'HuginnRecordLinkAgent::RecordLinkRemover',
        message: "Failed to delete record links",
        filters: filters,
        error: e,
        trace: e.backtrace.join('\n')
      }
      Rails.logger.error(delete_error)

      return { link_status: 500, error_detail: link_error }
    end
  end

  def self.build_where_clause(query, condition, value)
    if (value)
      return query.where(condition, value)
    else
      return query
    end
  end

end
