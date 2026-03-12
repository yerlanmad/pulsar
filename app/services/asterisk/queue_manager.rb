module Asterisk
  class QueueManager
    def initialize
      @ami = AmiCommand.new
    end

    def add_member(queue_config, agent)
      queue_name = queue_name_for(queue_config)
      interface = "PJSIP/#{sip_ext(agent)}"
      membership = agent.queue_memberships.find_by(queue_config: queue_config)
      penalty = membership&.priority || 0

      @ami.queue_add(queue_name, interface, penalty: penalty)
      Rails.logger.info("Added #{interface} to queue #{queue_name}")
    end

    def remove_member(queue_config, agent)
      queue_name = queue_name_for(queue_config)
      interface = "PJSIP/#{sip_ext(agent)}"

      @ami.queue_remove(queue_name, interface)
      Rails.logger.info("Removed #{interface} from queue #{queue_name}")
    end

    def pause_member(queue_config, agent, paused: true)
      queue_name = queue_name_for(queue_config)
      interface = "PJSIP/#{sip_ext(agent)}"

      @ami.queue_pause(queue_name, interface, paused: paused)
      Rails.logger.info("#{paused ? 'Paused' : 'Unpaused'} #{interface} in #{queue_name}")
    end

    private

    def queue_name_for(queue_config)
      queue_config.name.downcase.gsub(/\s+/, "_")
    end

    def sip_ext(agent)
      agent.sip_account.delete_prefix("SIP/").delete_prefix("PJSIP/")
    end
  end
end
