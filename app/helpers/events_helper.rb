module EventsHelper
  def batch_qr_codes_and_export?(event, batch)
    File.exist?(Rails.root.join('events', event.to_s, batch.to_s, 'qr_codes.zip')) &&
    File.exist?(Rails.root.join('events', event.to_s, batch.to_s, 'export', 'export.xls'))
  end
end