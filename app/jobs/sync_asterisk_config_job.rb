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
  end

  private

  def reload_asterisk(module_name)
    Rails.logger.info("Asterisk reload requested: #{module_name}")
    # TODO: send AMI reload command when Asterisk is connected
    # Asterisk::AmiClient.new.reload(module_name)
  end
end
