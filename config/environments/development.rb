Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join('tmp', 'caching-dev.txt').exist?
    config.action_controller.perform_caching = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options)
  #config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  config.log_level = ENV.fetch('RAILS_LOG_LEVEL') { 'debug' }.to_sym

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker
  config.paperclip_defaults = {
    storage: :s3,
    s3_protocol: :https,
    s3_credentials: {
      bucket: ENV.fetch('LINEAR_S3_BUCKET') { 'sg-web-products' },
      access_key_id: ENV.fetch('LINEAR_S3_ACCESS_KEY_ID') { 'AKIAZOPCTGAN3KJGHNU7' },
      secret_access_key: ENV.fetch('LINEAR_S3_SECRET_ACCESS_KEY') { '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' },
      s3_region: ENV.fetch('LINEAR_S3_REGION') { 'sa-east-1' },
      s3_host_name: ENV.fetch('LINEAR_S3_HOST_NAME') { 's3-sa-east-1.amazonaws.com' }
    }
  }

  config.rabbitmq = {
    host: ENV.fetch('LINEAR_RABBITMQ_HOST') { 'dev.erplinear.com.br' },
    user: ENV.fetch('LINEAR_RABBITMQ_USER') { 'master' },
    password: ENV.fetch('LINEAR_RABBITMQ_PASSWORD') { 'master-dev' },
    port: ENV.fetch('LINEAR_RABBITMQ_PORT') { '30672' }
  }

  config.download_xml_bucket_name = ENV.fetch('LINEAR_DOWNLOAD_XML_BUCKET_NAME') { 'sg-web-development-tmp' }
  config.download_xml_tmp_storage = ENV.fetch('LINEAR_DOWNLOAD_XML_TMP_STORAGE') { '/Users/deivisson/downloadxml/' }
end
