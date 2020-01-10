require_relative '../models/record_link'
require_relative '../models/record'

class HuginnRecordLinkAgent::RecordLinkBuilder

  # This is a utility class for managing the creation of RecordLink instances.
  # As there are cases in which these links may need to be created in batch, the
  # process has been isolated from the Agent to make things easier to maintain

  def self.create_links(user, source_system, source_type, source_id, target_system, target_type, target_id)
    # Ensure that the ID parameters are an array to simplify link creation
    source_ids = source_id.respond_to?('each') ? source_id : [source_id]
    target_ids = target_id.respond_to?('each') ? target_id : [target_id]

    begin
      record_links = []
      ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
        # Wrap link creation in a transaction so we can ensure that ALL links are created successfully

        source_ids.each do |sid|
          # Create a link to each target for each source
          target_ids.each do |tid|
            rl = create_link(user, source_system, source_type, sid, target_system, target_type, tid)

            if rl
              record_links << {
                source_system: source_system,
                source_type: source_type,
                source_id: sid,
                target_system: target_system,
                target_type: target_type,
                target_id: tid
              }
            else
              raise "Failed to create RecordLink instance from #{source_system} #{source_type} #{sid} to #{target_system} #{target_type} #{tid}"
            end
          end
        end

      end

      return { link_status: 200, links: record_links }

    rescue => e
      link_error = {
        scope: 'HuginnRecordLinkAgent::RecordLinkBuilder',
        message: "Failed to create RecordLinks: #{e.message}",
        source_system: source_system,
        source_type: source_type,
        source_id: source_id,
        target_system: target_system,
        target_type: target_type,
        target_id: target_id,
        error: e,
        trace: e.backtrace.join('\n')
      }
      Rails.logger.error(link_error)

      return { link_status: 500, error_detail: link_error }
    end
  end

  def self.create_link(user, source_system, source_type, source_id, target_system, target_type, target_id)
    # Ensure Source Record exists
    source_record = HuginnRecordLinkAgent::Record.find_or_create_by(
      user_id: user.id,
      ext_system: source_system,
      model_type: source_type,
      external_id: source_id
    )

    # Ensure Target Record exists
    target_record = HuginnRecordLinkAgent::Record.find_or_create_by(
      user_id: user.id,
      ext_system: target_system,
      model_type: target_type,
      external_id: target_id
    )

    return HuginnRecordLinkAgent::RecordLink.find_or_create_by(source_record_id: source_record.id, target_record_id: target_record.id)
  end

end
