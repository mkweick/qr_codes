module EventsHelper
  def generation_complete?(event, batch)
    qr_codes_path = Rails.root.join('events', event.to_s, batch.to_s, 'qr_codes.zip')
    export_path = Rails.root.join('events', event.to_s, batch.to_s, 'export', 'export.xls')
    File.exist?(qr_codes_path) && File.exist?(export_path)
  end
end