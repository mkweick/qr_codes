class QrCodesController < ApplicationController
	before_action :require_user, except: [:download]
	before_action :require_admin, except: [:download, :on_site_badge,
		:crm_contact, :on_demand, :generate_crm]

	def generate
		batch = params[:batch] if params[:batch]
		# email = session[:email]
		email = 'mweick@provident.com'

		if @event_name && batch && email
			GenerateQrCodesExportJob.perform_later(@event_name, batch, email)
			flash.notice = "We'll send you an email once Batch #{batch} processing is complete."
			redirect_to event_path(name: @event_name)
		else
			redirect_to root_path
		end
	end

	def download
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

			if last_name || account_name
				db = TinyTds::Client.new( host: '10.220.0.252', database: 'DiValSafety1_MSCRM',
					username: 'sa', password: 'CRMadmin#')

				@results = []
			end

			if last_name
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
						"#{"\n" + contact[3] if contact[3]};;", level: :q).to_img.resize(375, 375)

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

	def event_dir?(status, event_name)
		Dir.exist?(Rails.root.join('events', status, event_name))
	end

	def dir_list(path)
		Dir.entries(path).select { |file| file != '.' && file != '..' && file != '.gitignore' }
	end

	def walk_in_crm_dir?(event_name)
		Dir.exist?(Rails.root.join('events', 'active', event_name, 'Walk In CRM'))
	end

	def make_walk_in_crm_dir(event_name)
		Dir.mkdir(Rails.root.join('events', 'active', event_name, 'Walk In CRM'))
	end
end