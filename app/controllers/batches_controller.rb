class BatchesController < ApplicationController
  before_action :require_user
  before_action :require_admin
  before_action :set_event
  before_action :require_active_event
  before_action :set_batch, except: [:create]

  def create
    file = params[:batch][:file] if params[:batch][:file]

    if file && file.original_filename[-4..-1].downcase == '.xls'
      batches = @event.batches.pluck(:number)
      next_batch = batches.any? ? batches.map(&:to_i).sort.last.next.to_s : '1'
      
      @batch = @event.batches.new(batch_params.merge(number: next_batch))

      if @batch.save
        make_batch_dir(@event.id, @batch.number)

        filename = sanitize(file.original_filename)
        File.open(Rails.root.join('events', @event.id.to_s, @batch.number.to_s, filename), 'wb') do |f|
          f.write(file.read)
        end

        if @batch.batch_type == '1'
          if attendee_upload_has_errors?(@event.id.to_s, @batch.number.to_s, filename)
            delete_batch_dir(@event.id, @batch.number)
            @batch.destroy
          else
            flash.notice = "Batch created."
          end
        elsif @batch.batch_type == '2'
          if employee_upload_has_errors?(@event.id.to_s, @batch.number.to_s, filename)
            delete_batch_dir(@event.id, @batch.number)
            @batch.destroy
          else
            flash.notice = "Batch created."
          end
        end

        redirect_to event_path(@event)
      else
        set_event_info
        render 'events/show'
      end
    else
      flash.alert = "Upload file must be <strong>.xls</strong> format."
      redirect_to event_path(@event)
    end
  end

  def edit
    set_batch_form_info
  end

  def update
    if @batch.update(batch_params)
      flash.notice = "Batch #{@batch.number} updated."
      redirect_to event_path(@event)
    else
      @event.reload
      @batch.reload
      set_batch_form_info
      render 'edit'
    end
  end

  def destroy
    if @batch.destroy
      delete_batch_dir(@event.id, @batch.number)
      flash.notice = "Batch deleted."
      redirect_to event_path(@event)
    else
      @batch = @event.batches.new
      set_event_info
      flash.now.alert = "Unable to delete batch."
      render 'events/show'
    end
  end

  def generate
    email = session[:email] if session[:email]
    batch_path = Rails.root.join('events', @event.id.to_s, @batch.number.to_s)
    upload_file = Dir.entries(batch_path).select { |f| f[-4..-1] == '.xls' }.first

    if upload_file
      @batch.update(processing_status: '2')

      if @batch.batch_type == '1'
        GenerateAttendeeQrCodesExportJob.perform_later(@event, @batch, email)
      elsif @batch.batch_type == '2'
        GenerateEmployeeQrCodesExportJob.perform_later(@event, @batch, email)
      end

      flash.notice = "Batch submitted.<br /> You'll receive an email when " +
          "Batch #{@batch.number} processing is complete."
    else
      flash.alert = "Upload file not found on server. Processing won't complete."
    end
    
    redirect_to event_path(@event)
  end

  def download
    type = params[:type] if params[:type]
    batch_path = Rails.root.join('events', @event.id.to_s, @batch.number.to_s)

    case type
    when 'original'
      original_file = Dir.entries(batch_path).select { |f| f[-4..-1] == '.xls' }.first

      if original_file
        original_upload = Rails.root.join(batch_path, original_file)
        send_file(original_upload, type: 'application/vnd.ms-excel',
          filename: original_file)
      else
        flash.alert = "Original upload file can't be found."
        redirect_to event_path(@event)
      end
    when 'qr_codes'
      zip_file = Rails.root.join(batch_path, 'qr_codes.zip')

      if File.exist?(zip_file)
        if @batch.batch_type == '1'
          send_file(zip_file, type: 'application/zip',
            filename: "QR_CODES_#{@event.name}" + 
              "#{'_' + @batch.location if @batch.location}_" +
              "BATCH_#{@batch.number}_Attendees.zip")
        elsif @batch.batch_type == '2'
          send_file(zip_file, type: 'application/zip',
            filename: "QR_CODES_#{@event.name}_BATCH_#{@batch.number}_" +
              "Employees.zip")
        end
      else
        flash.alert = "QR Codes zip file can't be found."
        redirect_to event_path(@event)
      end
    when 'export'
      export_file = Rails.root.join(batch_path, 'export', 'export.xls')

      if File.exist?(export_file)
        if @batch.batch_type == '1'
          send_file(export_file, type: 'application/vnd.ms-excel',
            filename: "FINAL_#{@event.name}" +
              "#{'_' + @batch.location if @batch.location}_" +
              "BATCH_#{@batch.number}_Attendees.xls")
        elsif @batch.batch_type == '2'
          send_file(export_file, type: 'application/vnd.ms-excel',
            filename: "FINAL_#{@event.name}_BATCH_#{@batch.number}_" +
              "Employees.xls")
        end
      else
        flash.alert = "Export file can't be found."
        redirect_to event_path(@event)
      end
    else
      flash.alert = "Invalid download link."
      redirect_to event_path(@event)
    end
  end

  private

  def batch_params
    params.require(:batch).permit(:location, :description, :batch_type)
  end

  def set_event
    @event = Event.find(params[:event_id]) if params[:event_id]
  end

  def set_batch
    @batch = Batch.find(params[:id]) if params[:id]
  end

  def set_batch_form_info
    @locations = Location.sorted_locations.pluck(:name) if @event.multiple_locations
  end

  def set_event_info
    @batches = @event.batches.order(:created_at)
    @locations = Location.sorted_locations.pluck(:name) if @event.multiple_locations
  end

  def make_batch_dir(event_id, batch_num)
    batch_path = Rails.root.join('events', event_id.to_s, batch_num.to_s)
    export_path = Rails.root.join('events', event_id.to_s, batch_num.to_s, 'export')

    FileUtils.remove_dir(batch_path) if Dir.exist?(batch_path)
    FileUtils.mkdir_p(batch_path)
    FileUtils.mkdir(export_path)
  end

  def delete_batch_dir(event_id, batch_num)
    batch_path = Rails.root.join('events', event_id.to_s, batch_num.to_s)
    FileUtils.remove_dir(batch_path) if Dir.exist?(batch_path)
  end

  def attendee_upload_has_errors?(event_id, batch_num, filename)
    duplicates = []
    blank_names = []
    column_count = 0
    workbook = Rails.root.join('events', event_id, batch_num, filename)

    Spreadsheet.open(workbook) do |book|
      sheet = book.worksheet(0)
      column_count = sheet.column_count

      attendees_with_row = sheet.map.with_index do |row, idx|
        if row[2].blank? && row.any? { |cell| cell.present? }
          blank_names << (idx + 1).to_s
        end

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

    if column_count == 13
      if duplicates.any?
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
        return true
      elsif blank_names.any?
        error_msg = "Upload failed. Contact Name is blank at rows:<br /><ul>"
        
        blank_names.each do |row|
          last_index = row.size - 1
          increment = 1
          lines = "<li>#{row[0]}"

          while increment <= last_index
            lines += " / #{row[increment]}"
            increment += 1
          end
          lines += "</li>"
          error_msg += lines
        end
        error_msg += "</ul>"

        flash.alert = error_msg
        return true
      else
        return false
      end
    else
      flash.alert = "Spreadsheet has #{column_count} columns. Must have 13 Columns for attendees." +
        "<br />#{view_context.link_to 'Download Attendee Template',
        download_attendee_template_event_path(@event), data: { turbolinks: false }}"
      return true
    end
  end

  def employee_upload_has_errors?(event_id, batch_num, filename)
    column_count = 0
    workbook = Rails.root.join('events', event_id, batch_num, filename)

    Spreadsheet.open(workbook) do |book|
      sheet = book.worksheet(0)
      column_count = sheet.column_count
    end

    if column_count == 10
      return false
    else
      flash.alert = "Spreadsheet has #{column_count} columns. Must have 10 Columns for employees." +
        "<br />#{view_context.link_to 'Download Employee Template',
        download_employee_template_event_path(@event), data: { turbolinks: false }}"
      return true
    end
  end
end