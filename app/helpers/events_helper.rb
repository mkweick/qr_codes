module EventsHelper
  def generation_complete?(event_id, batch_num)
    qr_codes_path = Rails.root.join('events', event_id.to_s,
      batch_num.to_s, 'qr_codes.zip')
    
    export_path = Rails.root.join('events', event_id.to_s,
      batch_num.to_s, 'export', 'export.xls')

    File.exist?(qr_codes_path) && File.exist?(export_path)
  end
end