class QrCodesController < ApplicationController

	def test
		@qrcode_h = RQRCode::QRCode.new('MATMSG:TO:leads@divalsafety.com;SUB:VENDOR: ;BODY:
______________________
Aaron Lund
CUTCO CUTLERY CORPORATION / 01-10160
1116 E. STATE STREET

OLEAN, NY 14760
P: (716) 372-3111
E: alund@cutco.com
Christopher Giese;;', size: 16, level: :h).to_img.resize(375, 375).to_data_url

		@qrcode_l = RQRCode::QRCode.new('MATMSG:TO:leads@divalsafety.com;SUB:VENDOR: ;BODY:
______________________
Aaron Lund
CUTCO CUTLERY CORPORATION / 01-10160
1116 E. STATE STREET

OLEAN, NY 14760
P: (716) 372-3111
E: alund@cutco.com
Christopher Giese;;', size: 15, level: :l).to_img.resize(375, 375).to_data_url

		@qrcode_m = RQRCode::QRCode.new('MATMSG:TO:leads@divalsafety.com;SUB:VENDOR: ;BODY:
______________________
Aaron Lund
CUTCO CUTLERY CORPORATION / 01-10160
1116 E. STATE STREET

OLEAN, NY 14760
P: (716) 372-3111
E: alund@cutco.com
Christopher Giese;;', size: 15, level: :m).to_img.resize(375, 375).to_data_url

		@qrcode_q = RQRCode::QRCode.new('MATMSG:TO:leads@divalsafety.com;SUB:VENDOR: ;BODY:
______________________
Aaron Lund
CUTCO CUTLERY CORPORATION / 01-10160
1116 E. STATE STREET

OLEAN, NY 14760
P: (716) 372-3111
E: alund@cutco.com
Christopher Giese;;', size: 15, level: :q).to_img.resize(375, 375).to_data_url
	end

	def index
		@files = Dir.entries('public/uploads').map { |file| file if file.length > 3 }.compact
	end

	def show
		workbook = Rails.root.join('public', 'uploads', params[:spreadsheet])

		Spreadsheet.open(workbook) do |book|
		  @rows = book.worksheet(0).map { |row| row }[1]
		end
	end

	def upload
		if params[:spreadsheet]
			excel_io = params[:spreadsheet]
		  File.open(Rails.root.join('public', 'uploads', excel_io.original_filename), 'wb') do |file|
		    file.write(excel_io.read)
		  end
		end

		redirect_to root_path
	end
end