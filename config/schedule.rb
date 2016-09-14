set :output, { :error => "log/cron_error_log.log",
               :standard => "log/cron_log.log" }

every '*/5 * * * *' do
  rake "events:clear_deleted_dev", environment: "development"
end

# every '30 4 * * *' do
#   rake "events:clear_deleted_prod", environment: "production"
# end