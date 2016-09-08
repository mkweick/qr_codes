class GenerateQrCodesExportJob < ActiveJob::Base
  queue_as :default

  def perform(event_name, batch, email)
    event_name = event_name
		batch = batch
		email = email.strip

		make_qr_codes_dir(event_name, batch) unless qr_codes_dir?(event_name, batch)
		make_export_dir(event_name, batch) unless export_dir?(event_name, batch)
		delete_export_file(event_name, batch) if export_file?(event_name, batch)

		bold_format = Spreadsheet::Format.new :weight => :bold
		header_row = ['Event', 'Registration Type', 'Attendee', 'Company',
									'Sales Rep', 'QR Code']
		export = Spreadsheet::Workbook.new
		sheet = export.create_worksheet name: event_name
		sheet.insert_row(0, header_row)
		sheet.row(0).default_format = bold_format
		sheet.column(0).width = 35
		sheet.column(1).width = 19
		sheet.column(2).width = 26
		sheet.column(3).width = 30
		sheet.column(4).width = 38
		sheet.column(5).width = 20
		sheet.column(6).width = 34

		qr_codes_path = qr_codes_file_path(event_name, batch)
		file = original_upload(event_name, batch)
		workbook = Rails.root.join('events', 'active', event_name, batch, file)

		Spreadsheet.open(workbook) do |book|
		  book.worksheet(0).map { |row| row.to_a }.drop(1).each do |row|
		  	next if row[2].blank?
		  	qr_code_filename = "#{sanitize(row[2])}.png"

		  	RQRCode::QRCode.new("MATMSG:TO:leads@divalsafety.com;SUB:#{row[13]};BODY:" +
					"\n______________________" +
					"#{"\n" + row[2]}" +
					"#{"\n" + row[3]}#{' / ' + row[4] if row[4]}" +
					"#{"\n" + row[8] if row[8]}" +
					"#{"\n" + row[9] if row[9]}" +
					"#{"\n" + row[10] if row[10]}" +
					"#{"\n" if !row[10] && (row[11] || row[12])}" +
					"#{', ' if row[10] && row[11]}" +
					"#{row[11] if row[11]} #{row[12]  if row[12]}" +
					"#{"\n" + 'E: ' + row[6] if row[6]}" +
					"#{"\n" + 'P: ' + row[7] if row[7]}" +
					"#{"\n" + row[5] if row[5]};;", level: :q)
		  		.to_img.resize(375, 375).save("#{qr_codes_path}/#{qr_code_filename}"
		  	)

		  	full_name = row[2].split(' ', 2)
		  	attendee_row = [row[0], row[1], full_name[0], full_name[1],
		  									row[3], row[5], qr_code_filename]						
		  	new_row_index = sheet.last_row_index + 1
		  	
		  	sheet.insert_row(new_row_index, attendee_row)
		  end
		end

		export.write(export_file_path(event_name, batch))

		input_filenames = dir_list(qr_codes_path)
		zip_path_filename = qr_codes_zip_path(event_name, batch)

		Zip::File.open(zip_path_filename, Zip::File::CREATE) do |zipfile|
		  input_filenames.each do |filename|
		    zipfile.add(filename, qr_codes_path + '/' + filename)
		  end
		  zipfile.get_output_stream('') { |batch_dir| batch_dir.write '' }
		end

		delete_qr_codes_dir(event_name, batch)
		NotificationMailer.batch_generation_complete_email(event_name, batch, email).deliver_now
  end

  private

  def sanitize(filename)
		filename.gsub(/[\\\/:*"'?<>|]/, '')
	end

  def dir_list(path)
		Dir.entries(path).select { |file| file != '.' && file != '..' && file != '.DS_Store' }
	end

  def qr_codes_dir?(event_name, batch)
		Dir.exist?(Rails.root.join('events', 'active', event_name, batch, 'qr_codes'))
	end

	def make_qr_codes_dir(event_name, batch)
		Dir.mkdir(Rails.root.join('events', 'active', event_name, batch, 'qr_codes'))
	end

	def export_dir?(event_name, batch)
		Dir.exist?(Rails.root.join('events', 'active', event_name, batch, 'export'))
	end

	def make_export_dir(event_name, batch)
		Dir.mkdir(Rails.root.join('events', 'active', event_name, batch, 'export'))
	end

	def export_file?(event_name, batch)
		File.exist?(Rails.root.join('events', 'active', event_name,
			batch, 'export', 'export.xls'))
	end

	def export_file_path(event_name, batch)
		Rails.root.join('events', 'active', event_name, batch, 'export', 'export.xls')
	end

	def qr_codes_file_path(event_name, batch)
		Rails.root.join('events', 'active', event_name, batch, 'qr_codes').to_s
	end

	def qr_codes_zip_path(event_name, batch)
		Rails.root.join('events', 'active', event_name, batch, 'qr_codes.zip').to_s
	end

	def original_upload(event_name, batch)
		Dir.entries("events/active/#{event_name}/#{batch}").select do |file|
			file[-4..-1] == '.xls'
		end.first
	end

	def delete_export_file(event_name, batch)
		File.delete(Rails.root.join('events', 'active', event_name,
			batch, 'export', 'export.xls'))
	end

	def delete_qr_codes_dir(event_name, batch)
		FileUtils.remove_dir(Rails.root.join('events', 'active', event_name, batch, 'qr_codes'))
	end
end
