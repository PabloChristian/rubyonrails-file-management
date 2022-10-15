# frozen_string_literal: true

require 'sneakers'
require 'sneakers/handlers/maxretry'

Sneakers.configure(
  # RabbitMQ Connections
  connection: Bunny.new(Rails.application.config.rabbitmq),
  vhost: '/',
  heartbeat: 580,
  exchange_type: :direct,

  # Daemon
  daemonize: Rails.env.production?,
  start_worker_delay: 0.2,
  workers: 4,
  pid_path: 'sneakers.pid',
  log: 'sneakers.log',

  # Workers
  timeout_job_after: 0,
  prefetch: 10,
  threads: 10,
  env: Rails.env,
  durable: true,
  ack: true,
  exchange: 'linear',

  # Other
  retry_exchange: 'download.xml-retry',
  retry_error_exchange: 'download.xml-error',
  retry_requeue_exchange: 'download.xml-retry-requeue',
  handler: Sneakers::Handlers::Maxretry,
  hooks: {
    before_fork: -> {
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Base.connection_pool.disconnect!
        Sneakers.logger.warn('Disconnected from ActiveRecord!')
      end
    },
    after_fork: -> {
      def count_pool_size
        workers              = ::Sneakers::Worker::Classes
        default_threads_size = ::Sneakers.const_get(:CONFIG)[:threads]
        base_pool_size       = 3 + workers.size * 3

        if Sneakers.const_get(:CONFIG)[:share_threads]
          base_pool_size + default_threads_size
        else
          base_pool_size + connections_per_worker(workers, default_threads_size)
        end
      end

      def connections_per_worker(classes, default)
        classes.inject(0) do |sum, worker_class|
          sum + (worker_class.queue_opts[:threads] || default)
        end
      end

      def reconfig?
        Rails.env.production?
      end

      ActiveSupport.on_load(:active_record) do
        config = Rails.application.config.database_configuration[Rails.env]
        config.merge!('pool' => count_pool_size) if reconfig?
        ActiveRecord::Base.establish_connection(config)
        Sneakers.logger.warn("Connected to ActiveRecord! Config: #{config}")
      end
    }
  }
)

Sneakers.logger.level = Logger::ERROR
