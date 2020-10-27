module Agents
  class DeleteRecordLinkAgent < Agent

    can_dry_run!
    no_bulk_receive!
    default_schedule "never"

    description do
      <<-MD
        This agent removes RecordLinks generated with the base RecordLinkAgent. This
        should functionally only be run in edge-case scenarios where soft deletes are
        not an option in the linked systems.

        ## Agent Options

          - `dry_run` - When `true`, this agent will print a log detailing what records will be removed.

          ### Filter Options
          - `source_system` - Matches `RecordLink` records where the source record has this `ext_system`
          - `source_type` - Matches `RecordLink` records where the source record has this `model_type`
          - `source_id` - Matches `RecordLink` records where the source record has this `external_id`

          - `target_system` - Matches `RecordLink` records where the target record has this `ext_system`
          - `target_type` - Matches `RecordLink` records where the target record has this `model_type`
          - `target_id` - Matches `RecordLink` records where the target record has this `external_id`

          The filters above can be used in any combination to find and delete records.` If this agent is run
          with no specified filters, then _all record links_ will be deleted.

          **NOTE:** All requests are filtered by the Huginn user's ID
      MD
    end

    event_description <<-MD

      On error, events look like this:

      ```
        {
          "status_code": number,
          "error": {
            scope: string,
            message: string,
            filters: {
              source_system: string,
              source_type: string,
              source_id: string,
              target_system: string,
              target_type: string,
              target_id: string,
            }
            trace: string,
            error
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
        'dry_run' => 'true',
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

      if options.has_key?('emit_events') && boolify(options['emit_events']).nil?
        errors.add(:base, "if provided, emit_events must be true or false")
      end

      if options['output_mode'].present? && !options['output_mode'].to_s.include?('{') && !%[clean merge].include?(options['output_mode'].to_s)
        errors.add(:base, "if provided, output_mode must be 'clean' or 'merge'")
      end

      if options.has_key?('dry_run') && boolify(options['dry_run']).nil?
        errors.add(:base, "if provided, emit_events must be true or false")
      end

      self.validate_filter_params
      else
        # By default, this agent returns ALL record links
        self.validate_all_lookup_params

      end
    end

    def validate_filter_params

      unless options['source_system'].present? && !options['source_system'])
        errors.add(:base, "If provided, `source_system` cannot be an empty string")
      end

      unless options['source_type'].present? && !options['source_type'])
        errors.add(:base, "If provided, `source_type` cannot be an empty string")
      end

      unless options['source_id'].present? && !options['source_id'])
        errors.add(:base, "If provided, `source_id` cannot be an empty string")
      end

      unless options['target_system'].present? && !options['target_system'])
        errors.add(:base, "If provided, `target_system` cannot be an empty string")
      end

      unless options['target_type'].present? && !options['target_type'])
        errors.add(:base, "If provided, `target_type` cannot be an empty string")
      end

      unless options['target_id'].present? && !options['target_id'])
        errors.add(:base, "If provided, `target_id` cannot be an empty string")
      end

    end

    def receive(incoming_events)
      incoming_events.each do |event|

        data = interpolated(event)

        dry_run = data['dry_run']

        source_system = data['source_system']
        source_type = data['source_type']
        source_id = data['source_id']

        target_system = data['target_system']
        target_type = data['target_type']
        target_id = data['target_id']

        records = HuginnRecordLinkAgent.RecordLinkRemover.delete_links(
          user,
          source_system,
          source_type,
          source_id,
          target_system,
          target_type,
          target_id,
          is_dry_run
        )

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
