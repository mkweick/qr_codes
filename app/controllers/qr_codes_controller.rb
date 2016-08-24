class QrCodesController < ApplicationController
	def download
		path = Rails.root.join('events', 'active', params[:name],
			params[:batch], params[:file])
	  send_file(path, :filename => params[:file])
	end

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
      	update_event_dir(original_event_name, new_event_name)
      	flash.notice = "#{original_event_name} successfully updated to #{new_event_name}."
      	redirect_to event_path(name: new_event_name)
      end
		end
	end

	def generate
		workbook = Rails.root.join('events', 'active', params[:file])

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
				else
					flash.alert = "File must be <strong>.xls</strong> format."
			  end
			else
				make_event_dir(event_name)
			end
		end
		redirect_to root_path
	end

	def upload_batch

	end

	def archive
		event_name = params[:name].strip if params[:name]

		if event_name && event_dir?('active', event_name)
      move_event_dir('active', 'archive', event_name)
      flash.notice = "#{event_name} successfully archived."
		end
		redirect_to root_path
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
				elsif archives.any? { |event| event.strip.downcase == event_name.downcase }
					flash.alert = "Failed to re-activate because an archived event " +
												"with the name \"#{event_name}\" exists."
				else
	      	move_event_dir(from_status, 'active', event_name)
	      	flash.notice = "#{event_name} successfully activated."
	      end
	    else
	    	move_event_dir(from_status, 'active', event_name)
	      flash.notice = "#{event_name} successfully activated."
	    end
		end
		redirect_to root_path
	end

	def destroy
		event_name = params[:name].strip if params[:name]

		if event_name && event_dir?('active', event_name)
			remove_deleted_event_dir(event_name) if event_dir?('deleted', event_name)
      
      move_event_dir('active', 'deleted', event_name)
      flash.notice = "#{event_name} successfully deleted. Events will " +
	      						 "be permanently deleted after 7 days. Go to Archives " +
	      						 "to re-activate if this was a mistake."
		end
		redirect_to root_path
	end

	# Delete Events after 7 Days
	# event_name = params[:name].strip if params[:name]
	# if event_name && event_dir?('active', event_name)
  # 	remove_event_dir(event_name)
  # 	flash.notice = "#{event_name} successfully deleted."
	# end

	private

	def sanitize(filename)
		filename.gsub(/[\\\/:*"'?<>|]/, '')
	end

	def event_dir?(status, event_name)
		Dir.exist?(Rails.root.join('events', status, event_name))
	end

	def dir_list(path)
		Dir.entries(path).map { |file| file unless file == '.' || file == '..' }.compact
	end

	def make_event_dir(event_name)
		Dir.mkdir(Rails.root.join('events', 'active', event_name))
	end

	def make_batch_dir(event_name, batch)
		Dir.mkdir(Rails.root.join('events', 'active', event_name, batch))
	end

	def move_event_dir(from_status, to_status, event_name)
		FileUtils.mv(Rails.root.join('events', from_status, event_name),
    	Rails.root.join('events', to_status, event_name), force: true)
	end

	def update_event_dir(old_event_name, new_event_name)
		FileUtils.mv(Rails.root.join('events', 'active', old_event_name),
    	Rails.root.join('events', 'active', new_event_name), force: true)
	end

	def remove_event_dir(event_name)
		FileUtils.remove_dir(Rails.root.join('events', 'active', event_name), true)
	end

	def remove_deleted_event_dir(event_name)
		FileUtils.remove_dir(Rails.root.join('events', 'deleted', event_name), true)
	end

	def remove_batch_dir(event_name, batch)
		FileUtils.remove_dir(Rails.root.join('events', 'active', event_name, batch), true)
	end
end