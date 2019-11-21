module Agents
  class RecordLinkAgent < Agent

    can_dry_run!
    no_bulk_receive!
    default_schedule "never"

    description do
      <<-MD
        This agent manages bi-directional links between systems that lack viable support for external ID fields.

        ## Agent Options

          - `create_link` - When `true`, this agent will create a link between a source and target record. When false, this agent will simple look for matching record links.
          - `lookup_type` - One of `source`, `target`, `both`. Determines which link type to retrieve
          - `emit_each` - When `true`, each linked record will be emitted as a single event
          - `emit_events` - Setting this to `true` will result in the generated RecordLink being emitted as an Event which can be subsequently consumed by another agent
          - `output_mode` - Setting this value to `merge` will result in the emitted Event being merged into the original contents of the received Event. Setting it to `clean` will result in no merge.

        ###Create Record Link
        Link creation leverages Rails `find_or_create_by` to avoid errors. This allows users to inject a link creation into their existing
        flow without requiring trigger agents that check to see whether a link already exists. In most implementations, this check will have
        run earlier in the flow (prior to upserting records to the external system)

        **Required Options:**
          - `source_system` - The source/authority for the record in question
          - `source_type` - The record type in the source system
          - `source_id` - The record ID (or an array of IDs) from the source system
          - `target_system` - The system the source record is being sent to
          - `target_type` - The record type in the target system
          - `target_id` - The record ID (or array of IDs) in the target system
          - `create_link` - Set to `true`

        **Additional Notes:**
        `target_id` and `source_id` can be set to an array in order to link multiple records together in a single execution.
        In such cases, link creation will be wrapped in a transaction. The agent will only emit a successful event if all links
        are created without error. If any of the links fail, a failure status will be emitted.

        If _both_ `target_id` and `source_id` are arrays, then _all_ provided source records will be linked to _all_ provided targets

        ###Find Target Record Links

        **Required Options:**

          - `source_system` - The source/authority for the record in question
          - `source_type` - The record type in the source system
          - `source_id` - The record ID(or array of IDs) from the source system

        **Optional Filters/Settings:**
          - `target_system` - Only return matches from the specified system
          - `target_type` - Only return matches of the specified type (**Note:** When set, `target_system` is required)
          - `create_link` - Set to `false`. This value defaults to `false` if not provided
          - `require_all` - If `true`, this Agent will only emit a successful event if a matching target is found for all provided source_id values

        **Additional Notes:**
        If `source_id` is an array and `require_all` is `true`, this Agent will ensure that at least one matching target exists for each
        provided source. If any source is missing a target, then a 404 - Links Missing event will be emitted.

        ###Find Source Record Links

        **Required Options:**

          - `target_system` - The system the record was sent to
          - `target_type` - The record type in the target system
          - `target_id` - The record ID (or array of IDs) from the target system

        **Optional Filters/Options:**
          - `source_system` - Only return matches from the specified system
          - `source_type` - Only return matches of the specified type (**Note:** When set, `target_system` is required)
          - `create_link` - Set to `false`. This value defaults to `false` if not provided
          - `require_all` - If `true`, this Agent will only emit a successful event if a matching source is found for all provided target_id values

        **Additional Notes:**
        If `target_id` is an array and `require_all` is `true`, this Agent will ensure that at least one matching source exists for each
        provided target. If any source is missing a target, then a 404 - Links Missing event will be emitted.

        ###Find All Record Links

        **Required Options:**

          - `record_system` - The system containing the record
          - `record_type` - The record type in the specified system
          - `record_id` - The ID of the record
          - `create_link` - Set to `false`. This value defaults to `false` if not provided

        **Optional Filters:**

          - `system_filter` - Only return links to or from the specified system
          - `type_filter` - Only return links to or from the specified type

        ###Hard Errors vs Soft Errors
        This agent issues two distinct error statuses: `404` and `500`.

        A `404` is treated like a soft error. These errors will be reported for
        debugging purposes, but they will not result in a task failure unless the
        `require_all` parameter is set to true.

        If `emit_each` is set to `true`, and `emit_events` is `true`, soft errors
        will be emitted individually with a `link_status` of `404`. If `emit_each`
        is false, a single error will be emitted with a `link_status` of `404` and
        an array of each individua error.

        A `500` status is considered a critical failure and is only issued when
        unexpected errors are encountered during processing (usually related to
        database interactions) If a critical error is encountered, this will always
        result in a task failure.

        When a 500 error occurs, if `emit_events` is `true`, then all errors
        encountered during processing will be consolidated in to a single `link_error`
        payload with a `link_status` of `500`.

        **NOTE:** If `emit_each` is `true`, the option
        is ignored when a 500 error occurs.

        ### Recommended Usage

        Traditionally bi-directional relationships work because one knows both endpoints in
        the relationship, and associated tables are defined accordingly, but in this case,
        the endpoints are unknwon. As a result, some sense of direction must be maintained
        in order to accurately identify what the link represents.

        When linking records together with this agent, it is up to the user to maintain
        knowledge of that direction. As a general rule of thumb, it is recommended that the
        `source` fields be defined as the authority/origin point of the data and the `target`
        fields be identified as the destination of the data.

        In the case of an integration between an eCommerce platform and an external product
        catalog, the product catalog would be considered the `source` for product and category
        information as it is likely the authority on all product/category information.

        **Regarding require_all:**
        When looking up source or target records, if `require_all` is set to `true`, it is recommended that `emit_each` be omitted
        (or explicitly set to `false`) so that further operations can be performed on the entire batch of matched records.
      MD
    end

    event_description <<-MD

      When `emit_each` is set to `true`, events look like this:

        {
          record_link {
            link_status: "200",
            source_system: "source_system",
            source_type: "source_type",
            source_id: 123,
            target_system: "target_system",
            target_type: "target_type",
            target_id: "target_id"
          }
        }

      When `emit_each` is set to `false`, events look like this:

      ```
        {
          "record_link": {
            "link_status": "200",
            "system": "system",
            "type": "type",
            "record_id": 123,
            "targets": [
              {
                "target_system": "system",
                "target_type": "type",
                "target_id": 123
              },
              { ... }
            ],
            "sources": [
              {
                "source_system": "system",
                "source_type": "type",
                "source_id": 123
              },
              { ... }
            ]
          }
        }

      On error, events look like this:

        {
          "record_link": {
            "link_status": "...",
            "link_errors": [...]
          }
        }

      ```
      Original event contents will be merged when `output_mode` is set to `merge`.
    MD

    def default_options
      {
        'expected_receive_period_in_days' => '1',
        'source_system' => 'Target System',
        'source_type' => 'Target Model',
        'source_id' => '123',
        'target_system' => 'Target System',
        'target_type' => 'Target Type',
        'target_id' => '123',
        'create_link' => 'true',
        'emit_each' => 'true',
        'emit_events' => 'true',
        'output_mode' => 'clean',
      }
    end

    def working?
      return false if recent_error_logs?

      if interpolated['expected_receive_period_in_days'].present?
        return false unless last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago
      end

      true
    end

    def validate_options

      if options.has_key?('emit_each') && boolify(options['emit_each']).nil?
        errors.add(:base, 'when provided, `emit_each` bust be either true or false')
      end

      if options.has_key?('emit_events') && boolify(options['emit_events']).nil?
        errors.add(:base, "if provided, emit_events must be true or false")
      end

      if options['output_mode'].present? && !options['output_mode'].to_s.include?('{') && !%[clean merge].include?(options['output_mode'].to_s)
        errors.add(:base, "if provided, output_mode must be 'clean' or 'merge'")
      end

      if options.has_key?('create_link') && boolify(options['create_link'])
        self.validate_create_params

      elsif options.has_key?('lookup_type')
        if options['lookup_type'] == 'source'
          self.validate_source_lookup_params

        elsif options['lookup_type'] == 'target'
          self.validate_target_lookup_params

        elsif options['lookup_type'] == 'all'
          self.validate_all_lookup_params

        else
          errors.add(:base, "when provided, `lookup_type` must be one of `source`, `target` or `all`")
        end

      else
        # By default, this agent returns ALL record links
        self.validate_all_lookup_params

      end
    end

    def validate_create_params

      if options.has_key?('emit_each') && !boolify(options['emit_each'])
        errors.add(:base, "when `create_link` is true, `emit_each` must be true if provided")
      end

      unless options['source_system'].present?
        errors.add(:base, "when creating record links `source_system` is a required field")
      end

      unless options['source_type'].present?
        errors.add(:base, "when creating record links `source_type` is a required field")
      end

      unless options['source_id'].present?
        errors.add(:base, "when creating record links `source_id` is a required field")
      end

      unless options['target_system'].present?
        errors.add(:base, "when creating record links `target_system` is a required field")
      end

      unless options['target_type'].present?
        errors.add(:base, "when creating record links `target_type` is a required field")
      end

      unless options['target_id'].present?
        errors.add(:base, "when creating record links `target_id` is a required field")
      end
    end

    def validate_target_lookup_params
      unless options['source_system'].present?
        errors.add(:base, "when fetching target links `source_system` is a required field")
      end

      unless options['source_type'].present?
        errors.add(:base, "when fetching target links `source_type` is a required field")
      end

      unless options['source_id'].present?
        errors.add(:base, "when fetching target links `source_id` is a required field")
      end

      if options.has_key?('target_type')
        unless options.has_key?('target_system')
          errors.add(:base, "when looking up linked target records, if `target_type` is provided, `target_system` is required")
        end
      end
    end

    def validate_source_lookup_params
      unless options['target_system'].present?
        errors.add(:base, "when fetching source links `target_system` is a required field")
      end

      unless options['target_type'].present?
        errors.add(:base, "when fetching source links `target_type` is a required field")
      end

      unless options['target_id'].present?
        errors.add(:base, "when fetching source links `target_id` is a required field")
      end

      if options.has_key?('source_type')
        unless options.has_key?('source_system')
          errors.add(:base, "when looking up linked source records, if `source_type` is provided, `source_system` is required")
        end
      end
    end

    def validate_all_lookup_params
      unless options['record_system'].present?
        errors.add(:base, "when fetching all record links `record_system` is a required field")
      end

      unless options['record_type'].present?
        errors.add(:base, "when fetching all record links `record_type` is a required field")
      end

      unless options['record_id'].present?
        errors.add(:base, "when fetching all record links `record_id` is a required field")
      end

      if options.has_key?('filter_type')
        unless options.has_key?('filter_system')
          errors.add(:base, "If `filter_type` is provided, `filter_system` is required")
        end
      end
    end

    def receive(incoming_events)
      incoming_events.each do |event|

        data = interpolated(event)

        if boolify(data['create_link'])
          create_record_link(event, data)

        elsif (data['lookup_type'] == 'source')
          find_source_links(event, data)

        elsif(data['lookup_type'] == 'target')
          find_target_links(event, data)

        else
          find_all_links(event, data)
        end

      end
    end

    def create_record_link(event, data)
      source_system = data['source_system']
      source_type = data['source_type']
      source_id = data['source_id']

      target_system = data['target_system']
      target_type = data['target_type']
      target_id = data['target_id']

      log("Creating RecordLink from #{source_system} #{source_type} #{source_id} to #{target_system} #{target_type} #{target_id}")
      results = HuginnRecordLinkAgent::RecordLinkBuilder.create_links(user, source_system, source_type, source_id, target_system, target_type, target_id)

      if results[:link_status] == 200
        if boolify(options['emit_each']) || results[:links].length == 1
          results[:links].each do |record_link|
            payload = { link_status: results[:link_status] }.merge(record_link)
            emit(data, event, payload) if boolify(options['emit_events'])
          end
        else
          # :results will be a hash object with :link_status and :links keys
          payload = results
          emit(data, event, payload) if boolify(options['emit_events'])
        end

      else
        # :results will be a hash object with :link_status and :error_detail keys
        payload = results
        emit(data, event, payload) if boolify(options['emit_events'])
      end

    end

    def find_source_links(event, data)
      # Required Params
      target_system = data['target_system']
      target_type = data['target_type']
      target_id = data['target_id']

      # Optional Filters
      source_system = data['source_system']
      source_type = data['source_type']

      # Ensure we have an array for iteration purposes
      lookup_ids = target_id.respond_to?('each') ? target_id : [target_id]
      results = HuginnRecordLinkAgent::RecordLinkLookupTool.lookup_records(user, target_system, target_type, lookup_ids, source_system, source_type, 'source')

      payloads = HuginnRecordLinkAgent::RecordLinkPayloadBuilder.build_payloads(results, boolify(options['emit_each']), boolify(options['require_all']))
      payloads.each do |payload|
        emit(data, event, payload) if boolify(options['emit_events'])
      end
    end

    def find_target_links(event, data)
      # Required Params
      source_system = data['source_system']
      source_type = data['source_type']
      source_id = data['source_id']
      # Optional Filters
      target_system = data['target_system']
      target_type = data['target_type']

      # Ensure we have an array for iteration purposes
      lookup_ids = source_id.respond_to?('each') ? source_id : [source_id]
      results = HuginnRecordLinkAgent::RecordLinkLookupTool.lookup_records(user, source_system, source_type, lookup_ids, target_system, target_type, 'target')
      log(results.inspect)

      payloads = HuginnRecordLinkAgent::RecordLinkPayloadBuilder.build_payloads(results, boolify(options['emit_each']), boolify(options['require_all']))
      log(payloads.inspect)
      payloads.each do |payload|
        emit(data, event, payload) if boolify(options['emit_events'])
      end
    end

    def find_all_links(event, data)
      # Required Params
      record_system = data['record_system']
      record_type = data['record_type']
      record_id = data['record_id']

      # Optional Filters
      filter_system = data['filter_system']
      filter_type = data['filter_type']

      # Ensure we have an array for iteration purposes
      lookup_ids = record_id.respond_to?('each') ? lookup_id : [lookup_id]
      results = HuginnRecordLinkAgent::RecordLinkLookupTool.lookup_records(user, record_system, record_type, record_ids, filter_system, filter_type)

      payloads = HuginnRecordLinkAgent::RecordLinkPayloadBuilder.build_payloads(results, boolify(options['emit_each']), boolify(options['require_all']))
      payloads.each do |payload|
        emit(data, event, payload) if boolify(options['emit_events'])
      end
    end


    #---------------  UTILITY METHODS  ---------------#
    def emit(data, event, payload)

      if (payload[:link_status] == 200)
        payload = { record_link: payload }
      else
        payload = { link_error: payload }
      end

      base_event = data['output_mode'].to_s == 'merge' ? event.payload.dup : {}
      payload = base_event.merge(payload)

      create_event(payload: payload)
    end

  end
end
