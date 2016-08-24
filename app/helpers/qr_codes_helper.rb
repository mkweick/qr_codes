module QrCodesHelper
	def batch_created_date(event_name, batch)
		File.ctime("events/active/#{event_name}/#{batch}").strftime('%b %d, %Y -%l:%M %p')
	end

	def batch_upload_filename(event_name, batch)
		Dir.entries("events/active/#{@event_name}/#{batch}").map do |file|
			file if file[-4..-1] == '.xls'
		end.compact.first
	end
end
