module Agents
  class RecordLinkAgent < Agent
    include EventHeadersConcern
    include WebRequestConcern
    include FileHandling

    consumes_file_pointer!

    MIME_RE = /\A\w+\/.+\z/

    can_dry_run!
    no_bulk_receive!
    default_schedule "never"

    description do
      <<-MD
        This agent manages bi-directional links between systems that lack viable support for external ID fields.

        ## Agent Options

          - `create_link` - When `true`, this agent will create a link between a source and target record.
          - `lookup_type` - One of `source`, `target`, `both`. Determines which link type to retrieve
          - `emit_each` - When `true`, each linked record will be emitted as a single event
          - `emit_events` - Setting this to `true` will result in the generated RecordLink being emitted as an Event which can be subsequently consumed by another agent
          - `output_mode` - Setting this value to `merge` will result in the emitted Event being merged into the original contents of the received Event. Setting it to `clean` will result in no merge.

        ###Create Record Link

        **Required Options:**
          - `source_system` - The source/authority for the record in question
          - `source_type` - The record type in the source system
          - `source_id` - The record ID from the source system
          - `target_system` - The system the source record is being sent to
          - `target_type` - The record type in the target system
          - `target_id` - The record ID in the target system
          - `create_link` - Set to `true`

        ###Find Target Record Links

        **Required Options:**

          - `source_system` - The source/authority for the record in question
          - `source_type` - The record type in the source system
          - `source_id` - The record ID from the source system

        **Optional Filters:**
          - `target_system` - Only return matches from the specified system
          - `target_type` - Only return matches of the specified type (**Note:** When set, `target_system` is required)
          - `create_link` - Set to `false`

        ###Find Source Record Links

        **Required Options:**

          - `target_system` - The system the record was sent to
          - `target_type` - The record type in the target system
          - `target_id` - The record ID from the target system

        **Optional Filters
          - `source_system` - Only return matches from the specified system
          - `source_type` - Only return matches of the specified type (**Note:** When set, `target_system` is required)
          - `create_link` - Set to `false`

        ###Find All Record Links

        **Required Options:**

          - `record_system` - The system containing the record
          - `record_type` - The record type in the specified system
          - `record_id` - The ID of the record
          - `create_link` - Set to `false`

        **Optional Filters:**

          - `system_filter` - Only return links to or from the specified system
          - `type_filter` - Only return links to or from the specified type


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
      base_event = data['output_mode'].to_s == 'merge' ? event.payload.dup : {} if boolify(options['emit_events'])

      begin
        record_link = create_link(source_system, source_type, source_id, target_system, target_type, target_id)
      rescue => e

        if boolify(options['emit_events'])
          payload = base_event.merge({
            record_link: {
              link_status: "500",
              link_errors: [
                {
                  message: "Failed to create RecordLink: #{e.message}",
                  source_system: source_system,
                  source_type: source_type,
                  source_id: source_id,
                  target_system: target_system,
                  target_type: target_type,
                  target_id: target_id,
                  trace: e.backtrace.join("\n"),
                  error: e
                }
              ]
            }
          })
        end
      end

      if boolify(options['emit_events'])
        payload = base_event.merge({
          record_link: {
            link_status: "200",
            source_system: source_system,
            source_type: source_type,
            source_id: source_id,
            target_system: target_system,
            target_type: target_type,
            target_id: target_id
          }
        })

        create_event payload: payload
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

      record = get_record_reference(target_system, target_type, target_id)

      if (record.nil?)
        base_event = data['output_mode'].to_s == 'merge' ? event.payload.dup : {} if boolify(options['emit_events'])

        payload = base_event.merge({
          record_link: {
            link_status: "500",
            link_errors: [
              {
                message: "Unable to locate lookup record",
                target_system: target_system,
                target_type: target_type,
                target_id: target_id,
                source_system: source_system,
                source_type: source_type
              }
            ]
          }
        })

        create_event(payload: payload) if boolify(options['emit_events'])
      else
        source_records = record.source_records

        source_records = source_records.where(ext_system: source_system) unless source_system.blank?
        source_records = source_records.where(model_type: source_type) unless source_type.blank?

        if source_records.any?
          build_events(event, data, record, source_records) if boolify(options['emit_events'])
        else
          base_event = data['output_mode'].to_s == 'merge' ? event.payload.dup : {} if boolify(options['emit_events'])

          payload = base_event.merge({
            record_link: {
              link_status: "404",
              link_errors: [
                {
                  message: "No match",
                  target_system: target_system,
                  target_type: target_type,
                  target_id: target_id,
                  source_system: source_system,
                  source_type: source_type
                }
              ]
            }
          })

          create_event(payload: payload) if boolify(options['emit_events'])
        end
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

      record = get_record_reference(source_system, source_type, source_id)

      if (record.nil?)
        base_event = data['output_mode'].to_s == 'merge' ? event.payload.dup : {} if boolify(options['emit_events'])

        payload = base_event.merge({
          record_link: {
            link_status: "500",
            link_errors: [
              {
                message: "Unable to locate lookup record",
                source_system: source_system,
                source_type: source_type,
                source_id: source_id,
                target_system: target_system,
                target_type: target_type
              }
            ]
          }
        })

        create_event(payload: payload) if boolify(options['emit_events'])
      else
        target_records = record.target_records

        target_records = target_records.where(ext_system: target_system) unless target_system.blank?
        target_records = target_records.where(model_type: target_type) unless target_type.blank?

        if target_records.any?
          build_events(event, data, record, nil, target_records) if boolify(options['emit_events'])
        else
          base_event = data['output_mode'].to_s == 'merge' ? event.payload.dup : {} if boolify(options['emit_events'])

          payload = base_event.merge({
            record_link: {
              link_status: "404",
              link_errors: [
                {
                  message: "No match",
                  source_system: source_system,
                  source_type: source_type,
                  source_id: source_id,
                  target_system: target_system,
                  target_type: target_type,
                }
              ]
            }
          })

          create_event(payload: payload) if boolify(options['emit_events'])
        end
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

      record = get_record_reference(record_system, record_type, record_id)

      if (record.nil?)
        base_event = data['output_mode'].to_s == 'merge' ? event.payload.dup : {} if boolify(options['emit_events'])

        payload = base_event.merge({
          record_link: {
            link_status: "500",
            link_errors: [
              {
                message: "Unable to locate lookup record",
                system: record_system,
                type: record_type,
                record_id: record_id,
                filter_system: filter_system,
                filter_type: filter_type
              }
            ]
          }
        })

        create_event(payload: payload) if boolify(options['emit_events'])
      else
        source_records = record.source_records
        source_records = source_records.where(ext_system: filter_system) unless filter_system.blank?
        source_records = source_records.where(model_type: filter_type) unless filter_type.blank?

        target_records = record.target_records
        target_records = target_records.where(ext_system: filter_system) unless filter_system.blank?
        target_records = target_records.where(model_type: filter_type) unless filter_type.blank?

        if source_records.any? || target_records.any?
          build_events(event, data, record, source_records, target_records) if boolify(options['emit_events'])
        else
          base_event = data['output_mode'].to_s == 'merge' ? event.payload.dup : {} if boolify(options['emit_events'])

          payload = base_event.merge({
            record_link: {
              link_status: "404",
              link_errors: [
                {
                  message: "No match",
                  system: record_system,
                  type: record_type,
                  record_id: record_id,
                  filter_system: filter_system,
                  filter_type: filter_type
                }
              ]
            }
          })

          create_event(payload: payload) if boolify(options['emit_events'])
        end
      end
    end

    def get_record_reference(system, type, id)
      return HuginnRecordLinkAgent::ExternalRecordRef.find_or_create_by(user_id: self.user.id, ext_system: system, model_type: type, uid: id)
    end

    def build_events(event, data, lookup_record, source_records = nil, target_records = nil)
      sources = []
      if (source_records.present?)
        source_records.each do |s|
          sources << { system: s.ext_system, type: s.model_type, uid: s.uid }
        end
      end

      targets = []
      if (target_records.present?)
        target_records.each do |t|
          targets << { system: t.ext_system, type: t.model_type, uid: t.uid }
        end
      end

      base_event = data['output_mode'].to_s == 'merge' ? event.payload.dup : {}

      if boolify(options['emit_each'])
        # Emit each event individually

        sources.each do |s|
          payload = base_event.merge({
            record_link: {
              link_status: "200",
              source_system: s[:system],
              source_type: s[:type],
              source_id: s[:uid],
              target_system: lookup_record.ext_system,
              target_type: lookup_record.model_type,
              target_id: lookup_record.uid
            }
          })

          create_event payload: payload
        end

        targets.each do |t|
          payload = base_event.merge({
            record_link: {
              link_status: "200",
              source_system: lookup_record.ext_system,
              source_type: lookup_record.model_type,
              source_id: lookup_record.uid,
              target_system: t[:system],
              target_type: t[:type],
              target_id: t[:uid]
            }
          })

          create_event payload: payload
        end

      else
        # Return all the fetched record links
        payload = base_event.merge({
          record_link: {
            link_status: '200',
            system: lookup_record.ext_system,
            type: lookup_record.model_type,
            record_id: lookup_record.uid,
            targets: targets,
            sources: sources
          }
        })
        create_event payload: payload
      end

    end

    def create_link(source_system, source_type, source_id, target_system, target_type, target_id)
      ActiveRecord::Base.transaction do
        # Ensure Source Record exists
        source_record = HuginnRecordLinkAgent::ExternalRecordRef.find_or_create_by(
          user_id: user.id,
          ext_system: source_system,
          model_type: source_type,
          uid: source_id
        )

        # Ensure Target Record exists
        target_record = HuginnRecordLinkAgent::ExternalRecordRef.find_or_create_by(
          user_id: user.id,
          ext_system: target_system,
          model_type: target_type,
          uid: target_id
        )

        return HuginnRecordLinkAgent::RecordLink.find_or_create_by(source_record_id: source_record.id, target_record_id: target_record.id)
      end
    end

  end
end
