class QrCodesController < ApplicationController
	def index
		@events = Dir.entries('events/active').map { |file| file if file.length > 2 }.compact
	end

	def show
		@event_name = params[:name]
	end

	def generate
		workbook = Rails.root.join('events', 'active', params[:spreadsheet])

		Spreadsheet.open(workbook) do |book|
		  book.worksheet(0).map { |row| row.to_a }.drop(1).each do |row|
		  	RQRCode::QRCode.new("MATMSG:TO:leads@divalsafety.com;SUB:#{row[13]};BODY:
					______________________
					#{row[2]}
					#{row[3]} / #{row[4]}
					#{row[8]}
					#{row[9]}
					#{row[10]}, #{row[11]} #{row[12]}
					P: #{row[7]}
					E: #{row[6]}
					#{row[5]};;", size: 17, level: :h)
		  			.to_img.resize(375, 375)
		  			.save("events/active/#{sanitize(row[2])}.png")
		  end
		end
	end

	def upload
		events = Dir.entries('events/active').map { |file| file if file.length > 2 }.compact
		archived_events = Dir.entries('events/archive').map { |file| file if file.length > 2 }.compact
		event_name = sanitize(params[:event_name].strip)

		if event_name.size < 3
			flash.alert = "Event Name must be at least 3 characters long."
		elsif events.any? { |event| event.strip.downcase == event_name.downcase }
			flash.alert = "Already an active event with the name \"#{event_name}\""
		elsif archived_events.any? { |event| event.strip.downcase == event_name.downcase }
			flash.alert = "Already an archived event with the name \"#{event_name}\""
		else
			if params[:file]
				file = params[:file]
				filename = sanitize(file.original_filename)
				file_extension = filename[-4..-1].downcase

				if file_extension == '.xls'
					Dir.mkdir(Rails.root.join('events', 'active', event_name))

				  File.open(Rails.root.join('events', 'active', event_name, filename), 'wb') do |f|
				    f.write(file.read)
				  end
				else
					flash.alert = "File must be <strong>.xls</strong> format."
			  end
			else
				Dir.mkdir(Rails.root.join('events', 'active', event_name))
			end
		end
		redirect_to root_path
	end

	def archive
		if params[:name]
			event_name = params[:name].strip
			if Dir.exist?(Rails.root.join("events", 'active', event_name))
      	FileUtils.mv(Rails.root.join("events", 'active', event_name),
      		Rails.root.join("events", 'archive', event_name))

      	flash.notice = "#{event_name} successfully archived."
      end
		end
		redirect_to root_path
	end

	def show_archives
		@archived_events = Dir.entries('events/archive').map { |file| file if file.length > 2 }.compact
	end

	def activate
		if params[:name]
			event_name = params[:name].strip
			if Dir.exist?(Rails.root.join("events", 'archive', event_name))
      	FileUtils.mv(Rails.root.join("events", 'archive', event_name),
      		Rails.root.join("events", 'active', event_name))

      	flash.notice = "#{event_name} successfully activated."
      end
		end
		redirect_to root_path
	end

	def destroy

	end

	private

	def sanitize(filename)
		filename.gsub(/[\\\/:*"'?<>|]/, '')
	end
end