class QrCodesController < ApplicationController
	before_action :require_user, except: [:index, :upload, :upload_batch, :download]
	before_action :require_admin, except: [:index, :upload, :upload_batch,
		:download, :on_site_badge, :crm_contact, :on_demand, :generate_crm]
	before_action :set_event_name, except: [:update, :upload, :archives]
	skip_before_action :verify_authenticity_token, only: [:upload, :upload_batch]

	def index
		redirect_to login_path unless logged_in?

		@events = dir_list('events/active').sort_by(&:downcase)
		@cities = Location.sorted_cities
		@types = EventType.sorted_types
		@years = Time.now.year..(Time.now.year + 2)
	end

	def show
		if @event_name && event_dir?('active', @event_name)
			batches = dir_list("events/active/#{@event_name}")
			batches.delete('Walk In')
			batches.delete('Walk In CRM')
			@batches = batches.sort
		else
			flash.alert = "Event not found."
			redirect_to root_path
		end
	end

	def edit
		if @event_name
			event_name = @event_name.split(' ')
			@city = event_name.shift
			@year = event_name.pop
			@type = event_name.join(' ')
			@cities = Location.sorted_cities
			@types = EventType.sorted_types
			@years = Time.now.year..(Time.now.year + 2)
		else
			redirect_to root_path
		end
	end

	def update
		original_event_name = params[:name] if params[:name]
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
		if logged_in?
			if admin?
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

							file_error_check(event_name, '1', filename)
						else
							flash.alert = "File must be <strong>.xls</strong> format."
					  end
					else
						make_event_dir(event_name)
						flash.notice = "#{event_name} created successfully."
					end
				end
				redirect_to root_path
			else
				flash.alert = "Admin access is required to do that."
				redirect_to root_path
			end
		else
			flash.alert = "Please log in."
			redirect_to login_path
		end
	end

	def upload_batch
		if logged_in?
			if admin?
				if @event_name
					if params[:file]
						file = params[:file]
						filename = sanitize(file.original_filename)
						file_extension = filename[-4..-1].downcase

						if file_extension == '.xls'
							batches = dir_list("events/active/#{@event_name}")
							batches.delete('Walk In')
							batches.delete('Walk In CRM')
							next_batch = batches.any? ? batches.map(&:to_i).sort.last.next.to_s : '1'
							make_batch_dir(@event_name, next_batch)

						  File.open(Rails.root.join('events', 'active', @event_name, next_batch,
						  	filename), 'wb') do |f|
						    f.write(file.read)
						  end

						  file_error_check(@event_name, next_batch, filename, false)
						else
							flash.alert = "File must be <strong>.xls</strong> format."
					  end
					else
						flash.alert = "No file was selected for upload."
					end
					redirect_to event_path(name: @event_name)
				else
					redirect_to root_path
				end
			else
				flash.alert = "Admin access is required to do that."
				redirect_to root_path
			end
		else
			flash.alert = "Please log in."
			session[:return_to] = event_path(name: @event_name)
			redirect_to login_path
		end
	end

	def generate
		batch = params[:batch] if params[:batch]
		email = params[:email].strip if params[:email]

		if @event_name && batch && email
			GenerateQrCodesExportJob.perform_later(@event_name, batch, email)
			flash.notice = "We'll send you an email once Batch #{batch} processing is complete."
			redirect_to event_path(name: @event_name)
		else
			redirect_to root_path
		end
	end

	def download
		if logged_in?
			if admin?
				if %w(original qr_codes export template).include? params[:type]
					batch = params[:batch] if params[:batch]
					file = params[:file] if params[:file]

					case params[:type]
					when 'original'
						path = Rails.root.join('events', 'active', @event_name, batch, file)
				  	send_file(path, type: 'application/vnd.ms-excel',
				  		filename: file, disposition: 'attachment')
				  when 'qr_codes'
						path = Rails.root.join('events', 'active', @event_name, batch, 'qr_codes.zip')
				  	send_file(path, type: 'application/zip',
				  		filename: "QR_CODES_#{@event_name}_BATCH_#{batch}.zip",
				  		disposition: 'attachment')
				  when 'export'
						path = Rails.root.join('events', 'active', @event_name, batch,
							'export', 'export.xls')
				  	send_file(path, type: 'application/vnd.ms-excel',
				  		filename: "FINAL_#{@event_name}_BATCH_#{batch}.xls",
				  		disposition: 'attachment')
				  when 'template'
				  	path = Rails.root.join('events', 'upload_template',
				  		'QR CODES UPLOAD TEMPLATE.xls')
				  	send_file(path, type: 'application/vnd.ms-excel',
				  		filename: "QR CODES UPLOAD TEMPLATE.xls", disposition: 'attachment')
				  end
				else
					redirect_to :back
				end
			else
				flash.alert = "Admin access is required to do that."
				redirect_to root_path
			end
		else
			flash.alert = "Please log in."
			session[:return_to] = request.referer
			redirect_to login_path
		end
	end

	def archive_event
		if @event_name && event_dir?('active', @event_name)
			begin
      	move_event_dir('active', 'archive', @event_name)
      	flash.notice = "#{@event_name} successfully archived."
      	redirect_to root_path
      rescue
				flash.alert = "Files or folders for this event are in use, " +
											"couldn't archive event. Contact IT."
      	redirect_to event_path(name: @event_name)
      end
    else
    	redirect_to root_path
		end
	end

	def archives
		@archived_events = dir_list('events/archive').sort_by(&:downcase)
		@deleted_events = dir_list('events/deleted').sort_by(&:downcase)
	end

	def activate
		from_status = params[:from] if params[:from]

		if @event_name && from_status && event_dir?(from_status, @event_name)
      if from_status == 'deleted'
	      events = dir_list('events/active')
				archives = dir_list('events/archive')

	      if events.any? { |event| event.strip.downcase == @event_name.downcase }
					flash.alert = "Failed to re-activate because an active event " +
												"with the name \"#{@event_name}\" exists."
					redirect_to archives_path
				elsif archives.any? { |event| event.strip.downcase == @event_name.downcase }
					flash.alert = "Failed to re-activate because an archived event " +
												"with the name \"#{@event_name}\" exists."
					redirect_to archives_path
				else
	      	begin
	      		move_event_dir(from_status, 'active', @event_name)
	      		flash.notice = "#{@event_name} successfully activated."
	      		redirect_to root_path
	      	rescue
	      		flash.alert = "Files or folders for this event are in use, " +
													"couldn't activate event. Contact IT."
      			redirect_to archives_path
	      	end
	      end
	    else
	    	begin
	    		move_event_dir(from_status, 'active', @event_name)
	      	flash.notice = "#{@event_name} successfully activated."
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
		if @event_name && event_dir?('active', @event_name)
			begin
				remove_deleted_event_dir(@event_name) if event_dir?('deleted', @event_name)
      	begin
      		move_event_dir('active', 'deleted', @event_name)
      		flash.notice = "#{@event_name} successfully deleted. Events are " +
	      							 	 "permanently deleted after 7 days. Go to Archives " +
	      							 	 "to re-activate if this was a mistake."
	      	redirect_to root_path
	      rescue
	      	flash.alert = "#{@event_name} has files or folders in use, " +
	    									"couldn't delete event. Contact IT."
	    		redirect_to event_path(name: @event_name)
	      end
	    rescue
	    	flash.alert = "Deleted event #{@event_name} has files or folders in use, " +
	    								"couldn't remove event. Contact IT."
	    	redirect_to event_path(name: @event_name)
	    end
		else
			redirect_to root_path
		end
	end

	def destroy_batch
		batch = params[:batch] if params[:batch]

		if @event_name && batch && batch_dir?(@event_name, batch)
			begin
      	delete_batch_dir(@event_name, batch)
      	flash.notice = "Batch #{batch} successfully deleted."
	    rescue
	    	flash.alert = "Batch #{batch} has files or folders in use, " +
	    								"couldn't delete batch. Contact IT."
	    end
	    redirect_to event_path(name: @event_name)
		else
			redirect_to root_path
		end
	end

	def on_site_badge
		unless @event_name && event_dir?('active', @event_name)
			flash.alert = "Event not found."
			redirect_to root_path
		end
	end

	def crm_contact
		if @event_name && event_dir?('active', @event_name)
			last_name = params[:last_name].strip unless params[:last_name].blank?
			account_name = params[:account_name].strip unless params[:account_name].blank?

			db = TinyTds::Client.new( host: '10.220.0.252', database: 'DiValSafety1_MSCRM',
				username: 'sa', password: 'CRMadmin#')

			@results = []

			if last_name
				if last_name.size > 2
					params.delete(:account_name)

					last_name = db.escape(last_name)
					query = db.execute(
						"SELECT a.ContactId, a.FullName, a.ParentCustomerIdName, b.FullName AS \"SalesRep\"
						 FROM ContactBase AS a
					 	 JOIN SystemUserBase AS b ON a.OwnerId = b.SystemUserId
					 	 WHERE a.LastName = '#{last_name}'
					 	 	 AND a.StateCode = '0'
					 	 ORDER BY a.FullName"
					)
					query.each(symbolize_keys: true) { |row| @results << row }
				else
					flash.now.alert = "Minimum of 3 characters required for last name search."
				end
			elsif account_name 
				if account_name.size > 2
					params.delete(:last_name)

					account_name = db.escape(account_name)
					query = db.execute(
						"SELECT a.ContactId, a.FullName, a.ParentCustomerIdName, b.FullName AS \"SalesRep\"
						 FROM ContactBase AS a
					 	 JOIN SystemUserBase AS b ON a.OwnerId = b.SystemUserId
					 	 WHERE a.ParentCustomerIdName LIKE '%#{account_name}%'
					 	 	 AND a.StateCode = '0'
					 	 ORDER BY a.ParentCustomerIdName, a.FullName"
					)
					query.each(symbolize_keys: true) { |row| @results << row }
				else
					flash.now.alert = "Minimum of 3 characters required for account search."
				end
			end
		else
			flash.alert = "Event not found."
			redirect_to root_path
		end
	end

	def generate_crm
		contact_id = params[:contact_id] if params[:contact_id]

		if @event_name && event_dir?('active', @event_name)
			if contact_id
				make_walk_in_crm_dir(@event_name) unless walk_in_crm_dir?(@event_name)

				db = TinyTds::Client.new( host: '10.220.0.252', database: 'DiValSafety1_MSCRM',
					username: 'sa', password: 'CRMadmin#')

				query = db.execute(
					"SELECT a.FullName, b.Name AS \"AccountName\",
						b.icbcore_ExtAccountID AS \"AccountNumber\",
						c.FullName AS \"SalesRep\", a.EMailAddress1  AS \"Email\",
						a.Telephone1  AS \"Phone\", d.Line1 AS \"Street1\",
						d.Line2 AS \"Street2\", d.City, d.StateOrProvince AS \"State\",
						d.PostalCode AS \"Zip\", 'VENDOR: ' AS \"EmailSubject\"
					 FROM ContactBase AS a
					 JOIN AccountBase AS b ON a.ParentCustomerId = b.AccountId
					 JOIN SystemUserBase AS c ON a.OwnerId = c.SystemUserId
					 JOIN CustomerAddressBase AS d ON a.ContactId = d.ParentId
				 	 WHERE a.ContactId = '#{contact_id}'
				 	 	 AND d.AddressNumber = '1'"
				)
				contact = query.each(as: :array).first

				if contact
					qr_code_path = Rails.root.join('events', 'active', @event_name, 'Walk In CRM')
					qr_code_filename = "#{sanitize(contact[0])}.png"

			  	@qr = RQRCode::QRCode.new("MATMSG:TO:leads@divalsafety.com;SUB:#{contact[11]};BODY:" +
						"\n______________________" +
						"#{"\n" + contact[0]}" +
						"#{"\n" + contact[1]}#{' / ' + contact[2] if contact[2]}" +
						"#{"\n" + contact[6] if contact[6]}" +
						"#{"\n" + contact[7] if contact[7]}" +
						"#{"\n" + contact[8] if contact[8]}" +
						"#{"\n" if !contact[8] && (contact[9] || contact[10])}" +
						"#{', ' if contact[8] && contact[9]}" +
						"#{contact[9] if contact[9]} #{contact[10]  if contact[10]}" +
						"#{"\n" + 'E: ' + contact[4] if contact[4]}" +
						"#{"\n" + 'P: ' + contact[5] if contact[5]}" +
						"#{"\n" + contact[3] if contact[3]};;", size: 20, level: :h).to_img.resize(375, 375)

			  	@qr.save("#{qr_code_path}/#{qr_code_filename}")
				else
					flash.alert = "No contact found."
					redirect_to crm_contact_path(name: @event_name)
				end
			else
				flash.alert = "Contact ID missing."
				redirect_to crm_contact_path(name: @event_name)
			end
		else
			flash.alert = "Event not found."
			redirect_to root_path
		end
	end

	def on_demand

	end

	private

	def set_event_name
		@event_name = params[:name] if params[:name]
	end

	def sanitize(filename)
		filename.gsub(/[\\\/:*"'?<>|]/, '')
	end

	def event_dir?(status, event_name)
		Dir.exist?(Rails.root.join('events', status, event_name))
	end

	def batch_dir?(event_name, batch)
		Dir.exist?(Rails.root.join('events', 'active', event_name, batch))
	end

	def walk_in_crm_dir?(event_name)
		Dir.exist?(Rails.root.join('events', 'active', event_name, 'Walk In CRM'))
	end

	def dir_list(path)
		Dir.entries(path).select { |file| file != '.' && file != '..' && file != '.gitignore' }
	end

	def make_event_dir(event_name)
		Dir.mkdir(Rails.root.join('events', 'active', event_name))
		Dir.mkdir(Rails.root.join('events', 'active', event_name, 'Walk In'))
		Dir.mkdir(Rails.root.join('events', 'active', event_name, 'Walk In CRM'))
	end

	def make_batch_dir(event_name, batch)
		Dir.mkdir(Rails.root.join('events', 'active', event_name, batch))
	end

	def make_walk_in_crm_dir(event_name)
		Dir.mkdir(Rails.root.join('events', 'active', event_name, 'Walk In CRM'))
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

	def delete_event_dir(event_name)
		FileUtils.remove_dir(Rails.root.join('events', 'active', event_name))
	end

	def delete_batch_dir(event_name, batch)
		FileUtils.remove_dir(Rails.root.join('events', 'active', event_name, batch))
	end

	def file_error_check(event_name, batch, filename, first_upload = true)
		duplicates = []
		column_count = 0
		workbook = Rails.root.join('events', 'active', event_name, batch, filename)

		Spreadsheet.open(workbook) do |book|
			sheet = book.worksheet(0)
			column_count = sheet.column_count

			attendees_with_row = sheet.map.with_index do |row, idx|
			  next if row[2].blank?
			  row = row.to_a
			  [row[2], row[3], idx + 1]
			end.compact

			attendees_no_row = attendees_with_row.map { |row| row.take(2) }
			dups = attendees_no_row.select { |row| attendees_no_row.count(row) > 1 }.uniq
			dups.each do |dup|
			  duplicates << attendees_with_row.each_index.map do |idx|
			  								attendees_with_row[idx][2] if attendees_with_row[idx][0..1] == dup
			  							end.compact
			end
		end

		if column_count == 14
			if duplicates.any?
				first_upload ? delete_event_dir(event_name) : delete_batch_dir(event_name, batch)
		  	error_msg = "Upload failed. Duplicates exist at rows:<br /><ul>"
		  	
		  	duplicates.each do |dup|
		  		last_index = dup.size - 1
		  		increment = 1
		  		lines = "<li>#{dup[0]}"

		  		while increment <= last_index
		  			lines += " / #{dup[increment]}"
		  			increment += 1
		  		end
		  		lines += "</li>"
		  		error_msg += lines
		  	end
		  	error_msg += "</ul>"

		  	flash.alert = error_msg
		  else
		  	flash.notice = "#{event_name} created and file uploaded successfully."
		  end
		else
			first_upload ? delete_event_dir(event_name) : delete_batch_dir(event_name, batch)
			flash.alert = "Spreadsheet contained #{column_count} columns. " +
										"Spreadsheet must only have 14 Columns. " +
										"#{view_context.link_to 'DOWNLOAD TEMPLATE',
											download_path(type: 'template'),
											data: { turbolinks: false }}"
		end
	end
end