class SyncAsteriskConfigJob < ApplicationJob
  queue_as :default

  def perform(config_type = :all)
    generator = Asterisk::ConfigGenerator.new

    case config_type.to_sym
    when :pjsip
      generator.generate_pjsip
      reload_asterisk("pjsip")
    when :queues
      generator.generate_queues
      reload_asterisk("queues")
    when :extensions
      generator.generate_extensions
      reload_asterisk("dialplan")
    when :all
      generator.generate_all
      reload_asterisk("all")
    end
  rescue => e
    Rails.logger.error("SyncAsteriskConfigJob failed (#{config_type}): #{e.message}")
  end

  private

  def reload_asterisk(module_name)
    Rails.logger.info("Asterisk reload: #{module_name}")
    Asterisk::AmiCommand.new.reload(module_name)
  end
end
