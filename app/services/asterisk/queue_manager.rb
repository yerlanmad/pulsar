module Asterisk
  class QueueManager
    def initialize
      @ari = AriClient.new
    end

    def sync_queue(queue_config)
      # Generate Asterisk queue configuration from DB
      config = generate_queue_config(queue_config)
      Rails.logger.info("Syncing queue config: #{queue_config.name}")
      config
    end

    def add_member(queue_name, sip_account)
      # AMI action to add queue member
      Rails.logger.info("Adding #{sip_account} to queue #{queue_name}")
    end

    def remove_member(queue_name, sip_account)
      # AMI action to remove queue member
      Rails.logger.info("Removing #{sip_account} from queue #{queue_name}")
    end

    def pause_member(queue_name, sip_account, paused: true)
      Rails.logger.info("#{paused ? 'Pausing' : 'Unpausing'} #{sip_account} in queue #{queue_name}")
    end

    private

    def generate_queue_config(queue_config)
      {
        name: queue_config.name,
        strategy: queue_config.strategy,
        timeout: queue_config.timeout,
        maxwait: queue_config.max_wait_time,
        members: queue_config.agents.map(&:sip_account)
      }
    end
  end
end
