class QrCodesController < ApplicationController

# 	def test
# 		@qr = RQRCode::QRCode.new('MATMSG:TO:leads@divalsafety.com;SUB:VENDOR: ;BODY:
# ______________________
# Aaron Lund
# CUTCO CUTLERY CORPORATION / 01-10160
# 1116 E. STATE STREET

# OLEAN, NY 14760
# P: (716) 372-3111
# E: alund@cutco.com
# Christopher Giese;;', size: 17, level: :h).to_img.resize(375, 375).to_data_url
# 	end

	def index
		@files = Dir.entries('projects/active').map { |file| file if file.length > 3 }.compact
	end

	def show
		workbook = Rails.root.join('projects', 'active', params[:spreadsheet])

		# Spreadsheet.open(workbook) do |book|
		#   @rows = book.worksheet(0).map { |row| row.to_a }.drop(1)
		# end
		Spreadsheet.open(workbook) do |book|
		  book.worksheet(0).map { |row| row.to_a }.drop(1).each do |row|
		  	@qr = RQRCode::QRCode.new("MATMSG:TO:leads@divalsafety.com;SUB:#{row[13]};BODY:
______________________
#{row[2]}
#{row[3]} / #{row[4]}
#{row[8]}
#{row[9]}
#{row[10]}, #{row[11]} #{row[12]}
P: #{row[7]}
E: #{row[6]}
#{row[5]};;", size: 17, level: :h).to_img.resize(375, 375).save("projects/active/#{sanitize(row[2])}.png")
		  end
		end
	end

	def generate
		workbook = Rails.root.join('projects', 'active', params[:spreadsheet])

		Spreadsheet.open(workbook) do |book|
		  book.worksheet(0).map { |row| row.to_a }.drop(1).each do |row|
		  	@qr = RQRCode::QRCode.new("MATMSG:TO:leads@divalsafety.com;SUB:#{row[13]};BODY:
______________________
#{row[2]}
#{row[3]} / #{row[4]}
#{row[8]}
#{row[9]}
#{row[10]}, #{row[11]} #{row[12]}
P: #{row[7]}
E: #{row[6]}
#{row[5]};;", size: 15, level: :h).to_img.resize(375, 375).to_data_url
		  end
		end
	end

	def upload
		if params[:spreadsheet]
			excel_io = params[:spreadsheet]
		  File.open(Rails.root.join('projects', 'active', excel_io.original_filename), 'wb') do |file|
		    file.write(excel_io.read)
		  end
		end

		redirect_to root_path
	end

	private

	def sanitize(filename)
		filename.gsub(/[\\\/:*"'?<>|]/, '')
	end
end