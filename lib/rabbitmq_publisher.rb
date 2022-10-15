# frozen_string_literal: true

module RabbitmqPublisher
  def to_queue(name, queue_arguments = {})
    @queue_name = name
    @arguments  = queue_arguments
  end

  def deliver!(payload)
    conn = Bunny.new(Rails.application.config.rabbitmq)
    conn.start

    channel   = conn.create_channel
    queue     = channel.queue(@queue_name, { durable: true }.merge(@arguments))
    exchange  = channel.default_exchange

    payload = [payload] unless payload.is_a? Array
    payload.each do |item|
      exchange.publish(item.to_json, routing_key: queue.name, persistent: true)
    end
  ensure
    conn.close
  end
end
