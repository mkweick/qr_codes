module QrCodesHelper
	def batch_created_date(event_name, batch)
		File.ctime("events/active/#{event_name}/#{batch}")
				.strftime('%b %d, %Y -%l:%M %p')
	end

	def batch_upload_filename(event_name, batch)
		Dir.entries("events/active/#{@event_name}/#{batch}").select do |file|
			file[-4..-1] == '.xls'
		end.first
	end

	def batch_qr_codes?(event_name, batch)
		File.exist?(Rails.root.join('events', 'active', event_name, batch,
			'qr_codes.zip'))
	end

	def batch_export?(event_name, batch)
		File.exist?(Rails.root.join('events', 'active', event_name, batch,
			'export', 'export.xls'))
	end
end
