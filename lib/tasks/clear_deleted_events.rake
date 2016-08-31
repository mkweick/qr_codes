namespace :events do
  desc "Clear deleted events"

  def deleted_events
    path = Rails.root.join('events', 'deleted')
    Dir.entries(path).select { |file| file != '.' && file != '..' && file != '.gitignore' }
  end

  def event_deleted_time(event_name)
    Rails.root.join('events', 'deleted', event_name).ctime
  end

  def permanently_delete(event_name)
    FileUtils.remove_dir(Rails.root.join('events', 'deleted', event_name))
  end

  task clear_deleted_dev: :environment do
    deleted_events.each do |event_name|
      if event_deleted_time(event_name) < 1.minutes.ago
        permanently_delete(event_name)
      end
    end
  end

  task clear_deleted_prod: :environment do
    deleted_events.each do |event_name|
      if event_deleted_time(event_name) < 7.days.ago
        permanently_delete(event_name)
      end
    end
  end
end