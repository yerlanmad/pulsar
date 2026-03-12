Rails.application.config.after_initialize do
  if defined?(Rails::Server) || ENV["SOLID_QUEUE_IN_PUMA"]
    Thread.new do
      sleep 5 # wait for app to fully boot
      Rails.logger.info("Starting AMI listener...")
      Asterisk::AmiListener.new.start
    rescue => e
      Rails.logger.error("AMI listener failed to start: #{e.message}")
    end
  end
end
