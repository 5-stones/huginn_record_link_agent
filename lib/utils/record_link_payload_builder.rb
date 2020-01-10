class HuginnRecordLinkAgent::RecordLinkPayloadBuilder

  # This is a utility class for managing the construction of event payloads for
  # RecordLink lookups. As there are cases in which these links may need to be
  # fetched in batch, the process has been isolated from the Agent to make things
  # easier to maintain

  def self.build_payloads(query_results, emit_each = false, require_all = true)
    # Errors and links are tracked separately so that errors can be reported
    # even if the link is successful.
    #
    # An error status of 404 will be considered a soft failure (unless require_all is true)
    # In this case, a success event will still be emiited, and the error will be emitted
    # separately.
    #
    # An error status of 500 will be considered a hard failure In this case, the agent will
    # fail as it implies an unexpected error occurred.
    errors = []
    record_links = []

    have_critical_errors = false

    query_results.each do |result|
      if (result[:link_status] != 200)
        errors << create_error_payload(result[:link_status], result[:link_error])
        have_critical_errors = true if (result[:link_status] == 500)
      else
        result = process_result(result[:lookup_record], result[:sources], result[:targets], emit_each)

        if emit_each
          result.each do |record_link|
            record_links << create_link_payload(record_link[:source_record], record_link[:target_record])
          end
        else
          record_links << result
        end
      end
    end

    payloads = []

    if errors.any?
      # In the case of critical errors, only return a single event for better reporting/debugging support
      if !have_critical_errors && emit_each
        payloads.concat(errors) # Append the error events to the payloads array
      else
        payloads << { link_status: have_critical_errors ? 500 : 404, errors: errors }
      end

      # Exit early if we hit critical errors
      return payloads if (require_all || have_critical_errors)
    end

    if emit_each
      payloads.concat(record_links)
    else
      payloads << { link_status: 200, record_links: record_links }
    end

    return payloads
  end

  #---------------  UTILITY METHODS  ---------------#
  def self.process_result(lookup_record, source_records, target_records, emit_each)
    # if emit_each is true, this will return an array of processed RecordLink relationships
    # otherwise, this will return a single payload representing the lookup_record and all its links

    if emit_each
      # if emit_each is true, build an array of link objects
      # containing :source_record and :target_record links
      # Return the assembled array
      links = []

      source_records.each do |s|
        links << { source_record: s, target_record: lookup_record }
      end

      target_records.each do |t|
        links << { source_record: lookup_record, target_record: t }
      end

      return links
    else
      # if emit_each is false, build a single hash represening
      # the lookup_record and all its linksed sources/targets
      link = {
        system: lookup_record.ext_system,
        type: lookup_record.model_type,
        record_id: lookup_record.external_id
      }

      sources = []
      source_records.each do |s|
        sources << { source_system: s.ext_system, source_type: s.model_type, source_id: s.external_id }
      end

      targets = []
      target_records.each do |t|
        targets << { target_system: t.ext_system, target_type: t.model_type, target_id: t.external_id }
      end
    end

    link = link.merge({ sources: sources, targets: targets })

    return link
  end

  def self.create_link_payload(source_record, target_record)
    return {
      link_status: 200,
      source_system: source_record.ext_system,
      source_type: source_record.model_type,
      source_id: source_record.external_id,
      target_system: target_record.ext_system,
      target_type: target_record.model_type,
      target_id: target_record.external_id
    }
  end

  def self.create_error_payload(link_status, link_error)
    return { link_status: link_status, error_detail: link_error }
  end

end
