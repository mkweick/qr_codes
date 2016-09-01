set :output, { :error => "log/cron_error_log.log",
               :standard => "log/cron_log.log" }

every '* * * * *' do
  rake "events:clear_deleted_dev", environment: "development"
end

# every '0 4 * * *' do
#   rake "events:clear_deleted_prod", environment: "production"
# end