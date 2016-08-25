class QrCodesController < ApplicationController
	
	def index
		@events = dir_list('events/active').sort
		@cities = Location.sorted_cities
		@types = EventType.sorted_types
		@years = Time.now.year..(Time.now.year + 2)
	end

	def show
		@event_name = params[:name]
		@batches = dir_list("events/active/#{@event_name}").sort
	end

	def edit
		@event_name = params[:name].strip
		event_name = @event_name.split(' ')
		@city = event_name.shift
		@year = event_name.pop
		@type = event_name.join(' ')
		@cities = Location.sorted_cities
		@types = EventType.sorted_types
		@years = Time.now.year..(Time.now.year + 2)
	end

	def update
		original_event_name = params[:name].strip if params[:name]
		new_event_name = params[:city] + ' ' + params[:type] + ' ' + params[:year]

		if params[:city].blank? || params[:type].blank? || params[:year].blank?
			flash.alert = "Location, Event Type and Year are all <strong>required</strong>."
			redirect_to edit_path(name: original_event_name)
		elsif original_event_name == new_event_name
			flash.notice = "Nothing to update, same name submitted."
			redirect_to event_path(name: original_event_name)
		elsif original_event_name && event_dir?('active', original_event_name)
	    events = dir_list('events/active')
			archives = dir_list('events/archive')

      if events.any? { |event| event.strip.downcase == new_event_name.downcase }
				flash.alert = "Failed to re-activate because an active event " +
											"with the name \"#{new_event_name}\" exists."
				redirect_to event_path(name: original_event_name)
			elsif archives.any? { |event| event.strip.downcase == new_event_name.downcase }
				flash.alert = "Failed to re-activate because an archived event " +
											"with the name \"#{new_event_name}\" exists."
				redirect_to event_path(name: original_event_name)
			else
      	begin
      		update_event_dir(original_event_name, new_event_name)
      		flash.notice = "Event successfully updated to #{new_event_name}."
      		redirect_to event_path(name: new_event_name)
      	rescue
      		flash.alert = "Folder for this event is in use, couldn't update " +
      									"to #{new_event_name}. Contact IT."
      		redirect_to event_path(name: original_event_name)
      	end
      end
		end
	end

	def upload
		events = dir_list('events/active')
		archives = dir_list('events/archive')
		event_name = params[:city] + ' ' + params[:type] + ' ' + params[:year]

		if params[:city].blank? || params[:type].blank? || params[:year].blank?
			flash.alert = "Location, Event Type and Year are all <strong>required</strong>."
		elsif events.any? { |event| event.strip.downcase == event_name.downcase }
			flash.alert = "Already an active event with the name \"#{event_name}\""
		elsif archives.any? { |event| event.strip.downcase == event_name.downcase }
			flash.alert = "Already an archived event with the name \"#{event_name}\""
		else
			if params[:file]
				file = params[:file]
				filename = sanitize(file.original_filename)
				file_extension = filename[-4..-1].downcase

				if file_extension == '.xls'
					make_event_dir(event_name)
					make_batch_dir(event_name, '1')

				  File.open(Rails.root.join('events', 'active', event_name, '1',
				  	filename), 'wb') do |f|
				    f.write(file.read)
				  end
				  flash.notice = "#{event_name} created and file uploaded successfully."
				else
					flash.alert = "File must be <strong>.xls</strong> format."
			  end
			else
				make_event_dir(event_name)
				flash.notice = "#{event_name} created successfully."
			end
		end
		redirect_to root_path
	end

	def upload_batch
		event_name = params[:name] if params[:name]

		if event_name
			if params[:file]
				file = params[:file]
				filename = sanitize(file.original_filename)
				file_extension = filename[-4..-1].downcase

				if file_extension == '.xls'
					batches = dir_list("events/active/#{event_name}")
					
					if batches.any?
						next_batch = batches.map(&:to_i).sort.last.next.to_s
					else
						next_batch = '1'
					end 
					make_batch_dir(event_name, next_batch)

				  File.open(Rails.root.join('events', 'active', event_name, next_batch,
				  	filename), 'wb') do |f|
				    f.write(file.read)
				  end
				  flash.notice = "Batch #{next_batch} created and file uploaded successfully."
				else
					flash.alert = "File must be <strong>.xls</strong> format."
			  end
			else
				flash.alert = "No file was selected for upload."
			end
			redirect_to event_path(name: event_name)
		else
			redirect_to root_path
		end
	end

	def email
		event_name = params[:name]
		batch = params[:batch]
		email = params[:email]

		NotificationMailer.batch_generation_complete_email(event_name, batch, email).deliver_now

		redirect_to event_path(name: event_name)
	end

	def generate
		event_name = params[:name] if params[:name]
		batch = params[:batch] if params[:batch]
		email = params[:email].strip if params[:email]

		if event_name && batch && email
			make_qr_codes_dir(event_name, batch) unless qr_codes_dir?(event_name, batch)
			make_export_dir(event_name, batch) unless export_dir?(event_name, batch)

			export = Spreadsheet::Workbook.new
			sheet1 = export.create_worksheet
			if export_file?(event_name, batch)
				begin
					delete_export_file(event_name, batch)
					export.write(export_file_path(event_name, batch))
				rescue
					flash.alert = "Export file is in use, couldn't complete processing. " +
												"Contact IT."
				end
			else
				export.write(export_file_path(event_name, batch))
			end

			file = original_upload(event_name, batch)
			workbook = Rails.root.join('events', 'active', event_name, batch, file)

			begin
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
							#{row[5]};;", size: 20, level: :h).to_img.resize(375, 375)
				  			.save("events/active/#{event_name}/#{batch}/qr_codes/#{sanitize(row[2])}.png")
				  end
				end

				NotificationMailer.batch_generation_complete_email(event_name, batch, email).deliver_now
				flash.notice = "We'll send you an email once your batch processing is complete."
			rescue
				flash.alert = "Original upload spreadsheet is in use for Batch #{batch}, " +
											"couldn't complete processing. Contact IT."
			end
			redirect_to event_path(name: event_name)
		else
			redirect_to root_path
		end
	end

	def download
		if %w(original qr_codes export).include? params[:type]
			name = params[:name] if params[:name]
			batch = params[:batch] if params[:batch]
			file = params[:file] if params[:file]

			case params[:type]
			when 'original'
				path = Rails.root.join('events', 'active', name, batch, file)
		  	send_file(path, type: 'application/vnd.ms-excel',
		  		:filename => file, disposition: 'attachment')
		  when 'qr_codes'
				path = Rails.root.join('events', 'active', name, batch, 'qr_codes.zip')
		  	send_file(path, type: 'application/zip',
		  		:filename => "QR_CODES_#{name}_BATCH_#{batch}.zip",
		  		disposition: 'attachment')
		  when 'export'
				path = Rails.root.join('events', 'active', name, batch,
					'export', 'export.xls')
		  	send_file(path, type: 'application/vnd.ms-excel',
		  		:filename => "FINAL_#{name}_BATCH_#{batch}.xls",
		  		disposition: 'attachment')
		  end
		else
			redirect_to :back
		end
	end

	def archive
		event_name = params[:name].strip if params[:name]

		if event_name && event_dir?('active', event_name)
			begin
      	move_event_dir('active', 'archive', event_name)
      	flash.notice = "#{event_name} successfully archived."
      	redirect_to root_path
      rescue
				flash.alert = "Files or folders for this event are in use, " +
											"couldn't archive event. Contact IT."
      	redirect_to event_path(name: event_name)
      end
    else
    	redirect_to root_path
		end
	end

	def show_archives
		@archived_events = dir_list('events/archive')
		@deleted_events = dir_list('events/deleted')
	end

	def activate
		event_name = params[:name].strip if params[:name]
		from_status = params[:from].strip if params[:from]

		if event_name && from_status && event_dir?(from_status, event_name)
      if from_status == 'deleted'
	      events = dir_list('events/active')
				archives = dir_list('events/archive')

	      if events.any? { |event| event.strip.downcase == event_name.downcase }
					flash.alert = "Failed to re-activate because an active event " +
												"with the name \"#{event_name}\" exists."
					redirect_to archives_path
				elsif archives.any? { |event| event.strip.downcase == event_name.downcase }
					flash.alert = "Failed to re-activate because an archived event " +
												"with the name \"#{event_name}\" exists."
					redirect_to archives_path
				else
	      	begin
	      		move_event_dir(from_status, 'active', event_name)
	      		flash.notice = "#{event_name} successfully activated."
	      		redirect_to root_path
	      	rescue
	      		flash.alert = "Files or folders for this event are in use, " +
													"couldn't activate event. Contact IT."
      			redirect_to archives_path
	      	end
	      end
	    else
	    	begin
	    		move_event_dir(from_status, 'active', event_name)
	      	flash.notice = "#{event_name} successfully activated."
	      	redirect_to root_path
	      rescue
	      	flash.alert = "Files or folders for this event are in use, " +
												"couldn't activate event. Contact IT."
      		redirect_to archives_path
	      end
	    end
	  else
	  	redirect_to root_path
		end
	end

	def destroy
		event_name = params[:name].strip if params[:name]

		if event_name && event_dir?('active', event_name)
			begin
				remove_deleted_event_dir(event_name) if event_dir?('deleted', event_name)
      	begin
      		move_event_dir('active', 'deleted', event_name)
      		flash.notice = "#{event_name} successfully deleted. Events are " +
	      							 	 "permanently deleted after 7 days. Go to Archives " +
	      							 	 "to re-activate if this was a mistake."
	      	redirect_to root_path
	      rescue
	      	flash.alert = "#{event_name} has files or folders in use, " +
	    									"couldn't delete event. Contact IT."
	    		redirect_to event_path(name: event_name)
	      end
	    rescue
	    	flash.alert = "Deleted event #{event_name} has files or folders in use, " +
	    								"couldn't remove event. Contact IT."
	    	redirect_to event_path(name: event_name)
	    end
		else
			redirect_to root_path
		end
	end

	def destroy_batch
		event_name = params[:name].strip if params[:name]
		batch = params[:batch] if params[:batch]

		if event_name && batch && batch_dir?(event_name, batch)
			begin
      	remove_batch_dir(event_name, batch)
      	flash.notice = "Batch #{batch} successfully deleted."
	    rescue
	    	flash.alert = "Batch #{batch} has files or folders in use, " +
	    								"couldn't delete batch. Contact IT."
	    end
	    redirect_to event_path(name: event_name)
		else
			redirect_to root_path
		end
	end

	private

	def sanitize(filename)
		filename.gsub(/[\\\/:*"'?<>|]/, '')
	end

	def event_dir?(status, event_name)
		Dir.exist?(Rails.root.join('events', status, event_name))
	end

	def batch_dir?(event_name, batch)
		Dir.exist?(Rails.root.join('events', 'active', event_name, batch))
	end

	def qr_codes_dir?(event_name, batch)
		Dir.exist?(Rails.root.join('events', 'active', event_name, batch, 'qr_codes'))
	end

	def export_dir?(event_name, batch)
		Dir.exist?(Rails.root.join('events', 'active', event_name, batch, 'export'))
	end

	def dir_list(path)
		Dir.entries(path).select { |file| file != '.' && file != '..' }
	end

	def original_upload(event_name, batch)
		Dir.entries("events/active/#{event_name}/#{batch}").select do |file|
			file[-4..-1] == '.xls'
		end.first
	end

	def export_file?(event_name, batch)
		File.exist?(Rails.root.join('events', 'active', event_name,
			batch, 'export', 'export.xls'))
	end

	def export_file_path(event_name, batch)
		Rails.root.join('events', 'active', event_name, batch, 'export', 'export.xls')
	end

	def delete_export_file(event_name, batch)
		File.delete(Rails.root.join('events', 'active', event_name,
			batch, 'export', 'export.xls'))
	end

	def make_event_dir(event_name)
		Dir.mkdir(Rails.root.join('events', 'active', event_name))
	end

	def make_batch_dir(event_name, batch)
		Dir.mkdir(Rails.root.join('events', 'active', event_name, batch))
	end

	def make_qr_codes_dir(event_name, batch)
		Dir.mkdir(Rails.root.join('events', 'active', event_name, batch, 'qr_codes'))
	end

	def make_export_dir(event_name, batch)
		Dir.mkdir(Rails.root.join('events', 'active', event_name, batch, 'export'))
	end

	def move_event_dir(from_status, to_status, event_name)
		FileUtils.mv(Rails.root.join('events', from_status, event_name),
    	Rails.root.join('events', to_status, event_name))
	end

	def update_event_dir(old_event_name, new_event_name)
		FileUtils.mv(Rails.root.join('events', 'active', old_event_name),
    	Rails.root.join('events', 'active', new_event_name))
	end

	def remove_deleted_event_dir(event_name)
		FileUtils.remove_dir(Rails.root.join('events', 'deleted', event_name))
	end

	def remove_batch_dir(event_name, batch)
		FileUtils.remove_dir(Rails.root.join('events', 'active', event_name, batch))
	end
end