set :output, { :error => "log/cron_error_log.log",
               :standard => "log/cron_log.log" }

# DEVELOPMENT CRONJOBS
# every '*/30 * * * *' do
#   rake "events:clear_deleted_dev", environment: "development"
# end

# every :reboot do
#   command "cd /home/rails/qr_codes && RAILS_ENV=development ruby bin/delayed_job restart",
#     environment: "development"
# end


# PRODUCTION CRONJOBS
every '30 4 * * *' do
  rake "events:clear_deleted_prod", environment: "production"
end

every :reboot do
  command "cd /home/dival/qr_codes && RAILS_ENV=production ruby bin/delayed_job restart",
    environment: "production"
end