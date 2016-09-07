Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Email Settings
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.raise_delivery_errors = true

  # Exchange Settings
  config.action_mailer.default_url_options = {
    host: 'webdev.divalsafety.com',
    port: 3000
  }
  config.action_mailer.smtp_settings = {
    address: 'mail-rails.divalsafety.com',
    port: 25,
    authentication: :login,
    user_name: 'rails-mailer',
    password: 'Tdot1721#',
    domain: 'mainoffice.dival.com',
    enable_starttls_auto: true,
    openssl_verify_mode: 'none'
  }

  # Gmail Settings
  # config.action_mailer.default_url_options = {
  #   host: 'webdev.com',
  #   port: 3000
  # }
  # config.action_mailer.smtp_settings = {
  #   address: 'smtp.gmail.com',
  #   port: 587,
  #   authentication: 'plain',
  #   user_name: 'mkweick@gmail.com',
  #   password: 'HHockey18!',
  #   enable_starttls_auto: true
  # }

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true
end
