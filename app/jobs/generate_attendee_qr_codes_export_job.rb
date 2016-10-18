class GenerateAttendeeQrCodesExportJob < ActiveJob::Base
  queue_as :default

  def perform(event, batch, email)
  	batch_path = Rails.root.join('events', event.id.to_s, batch.number.to_s)

		make_batch_dir(batch_path, 'qr_codes') unless batch_dir?(batch_path, 'qr_codes')
		make_batch_dir(batch_path, 'export') unless batch_dir?(batch_path, 'export')
		delete_export_file(batch_path) if export_file?(batch_path)

		bold_format = Spreadsheet::Format.new :weight => :bold
		header_row = ['Event', 'Registration Type', 'First Name', 'Last Name',
			'Company', 'Sales Rep', 'QR Code']
		export = Spreadsheet::Workbook.new
		sheet = export.create_worksheet name: event.name
		sheet.insert_row(0, header_row)
		sheet.row(0).default_format = bold_format
		sheet.column(0).width = 35
		sheet.column(1).width = 19
		sheet.column(2).width = 26
		sheet.column(3).width = 30
		sheet.column(4).width = 38
		sheet.column(5).width = 20
		sheet.column(6).width = 34

		qr_codes_path = qr_codes_file_path(batch_path)

		upload_file = original_upload(batch_path)
		workbook = Rails.root.join(batch_path, upload_file)

		Spreadsheet.open(workbook) do |book|
		  book.worksheet(0).map { |row| row.to_a }.drop(1).each do |row|
		  	next if row[2].blank?

		  	qr_code_filename = "#{sanitize(row[2])}.png"

		  	dups = sheet.column(6).drop(1).select do |filename|
		  		qr_code_filename == filename.gsub(/-{1}\d+/, '')
		  	end

		  	if dups.any?
		  		last_number = dups.last[-5]
		  		if last_number =~ /\d/
		  			incrementer = (last_number.to_i + 1).to_s
		  			qr_code_filename.insert(-5, "-#{incrementer}")
		  		else
		  			qr_code_filename.insert(-5, '-1')
		  		end
		  	end


		  	RQRCode::QRCode.new(
		  		"MATMSG:TO:leads@divalsafety.com;SUB:#{event.qr_code_email_subject};BODY:" +
					"\n\n\n______________________" +
					"\n" + row[2] +
					"\n" + row[3] + "#{' / ' + row[4] if row[4]}" +
					"#{"\n" + row[8] if row[8]}" +
					"#{"\n" + row[9] if row[9]}" +
					"#{"\n" + row[10] if row[10]}" +
					"#{"\n" if !row[10] && (row[11] || row[12])}" +
					"#{', ' if row[10] && row[11]}" +
					"#{row[11] if row[11]} #{row[12]  if row[12]}" +
					"#{"\n" + 'E: ' + row[6] if row[6]}" +
					"#{"\n" + 'P: ' + row[7] if row[7]}" +
					"#{"\n" + row[5] if row[5]};;", level: :q
				).to_img.resize(375, 375).save("#{qr_codes_path}/#{qr_code_filename}")

		  	full_name = row[2].split(' ', 2)
		  	attendee_row = [row[0], row[1], full_name[0], full_name[1],
		  									row[3], row[5], qr_code_filename]						
		  	new_row_index = sheet.last_row_index + 1
		  	
		  	sheet.insert_row(new_row_index, attendee_row)
		  end
		end

		export.write(export_file_path(batch_path))

		input_filenames = qr_code_filenames(qr_codes_path)
		zip_path_filename = qr_codes_zip_path(batch_path)

		Zip::File.open(zip_path_filename, Zip::File::CREATE) do |zipfile|
		  input_filenames.each do |filename|
		    zipfile.add(filename, qr_codes_path + '/' + filename)
		  end
		  zipfile.get_output_stream('') { |batch_dir| batch_dir.write '' }
		end

		delete_qr_codes_dir(batch_path)

		batch.update(processing_status: '3')

		NotificationMailer.batch_generation_complete_email(event, batch, email).deliver_now
  end

  private

  def sanitize(filename)
		filename.gsub(/[\\\/:*"'?<>|]/, '')
	end

	def batch_dir?(batch_path, folder)
		Dir.exist?(Rails.root.join(batch_path, folder))
	end

	def make_batch_dir(batch_path, folder)
		Dir.mkdir(Rails.root.join(batch_path, folder))
	end

	def export_file?(batch_path)
		File.exist?(Rails.root.join(batch_path, 'export', 'export.xls'))
	end

	def export_file_path(batch_path)
		Rails.root.join(batch_path, 'export', 'export.xls')
	end

	def delete_export_file(batch_path)
		File.delete(Rails.root.join(batch_path, 'export', 'export.xls'))
	end

	def qr_codes_file_path(batch_path)
		Rails.root.join(batch_path, 'qr_codes').to_s
	end

	def qr_codes_zip_path(batch_path)
		Rails.root.join(batch_path, 'qr_codes.zip').to_s
	end

	def qr_code_filenames(path)
		Dir.entries(path).select { |file| file[-4..-1] == '.png' }
	end

	def delete_qr_codes_dir(batch_path)
		FileUtils.remove_dir(Rails.root.join(batch_path, 'qr_codes'))
	end

	def original_upload(batch_path)
		Dir.entries(batch_path).select { |file| file[-4..-1] == '.xls' }.first
	end
end
