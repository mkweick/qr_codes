namespace :events do
  desc "Permanently remove deleted events"

  def event_dir?(event_id)
    Dir.exist?(Rails.root.join('events', event_id.to_s))
  end

  def delete_event_dir(event_id)
    FileUtils.remove_dir(Rails.root.join('events', event_id.to_s))
  end

  task clear_deleted_dev: :environment do
    deleted_events = Event.where(status: '3')

    deleted_events.each do |event|
      if event.updated_at < 5.minutes.ago
        if event.destroy
          delete_event_dir(event.id) if event_dir?(event.id)
        end
      end
    end
  end

  task clear_deleted_prod: :environment do
    deleted_events = Event.where(status: '3')

    deleted_events.each do |event|
      if event.updated_at < 3.days.ago
        if event.destroy
          delete_event_dir(event.id) if event_dir?(event.id)
        end
      end
    end
  end
end