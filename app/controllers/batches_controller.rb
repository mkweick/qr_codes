class BatchesController < ApplicationController
  before_action :require_user
  before_action :require_admin
  before_action :set_event
  before_action :require_active_event
  before_action :set_batch, except: [:create]

  def create
    file = params[:batch][:file] if params[:batch][:file]
    filename = file.original_filename if file

    redirect_to event_path(@event) and return if invalid_filetype?(filename)

    @batch = @event.batches.new(batch_params.merge(number: next_batch_number))
    if @batch.save
      make_batch_dir
      save_upload_file(file, filename)
      upload_file_error_check(filename)
      redirect_to event_path(@event)
    else
      set_event_info
      render 'events/show'
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
      delete_batch_dir
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

    if upload_filename
      if @batch.batch_type == '1'
        GenerateAttendeeQrCodesExportJob.perform_later(@event, @batch, email)
      elsif @batch.batch_type == '2'
        GenerateEmployeeQrCodesExportJob.perform_later(@event, @batch, email)
      end

      @batch.update(processing_status: '2')
      flash.notice = "Batch submitted. You'll receive an email when complete."
    else
      flash.alert = "Upload file not found on server."
    end
    
    redirect_to event_path(@event)
  end

  def download
    type = params[:type] if params[:type]

    case type
    when 'upload' then send_upload_file
    when 'qr_codes' then send_qr_codes_zip_file
    when 'export' then send_export_file
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

  def batch_path
    Rails.root.join('events', @event.id.to_s, @batch.number.to_s)
  end

  def export_path
    Rails.root.join(batch_path, 'export')
  end

  def invalid_filetype?(filename)
    extension = filename[-4..-1].downcase if filename

    if extension != '.xls'
      flash.alert = "Upload file must be <strong>.xls</strong> format."
      return true
    else
      return false
    end
  end

  def make_batch_dir
    FileUtils.remove_dir(batch_path) if Dir.exist?(batch_path)
    FileUtils.mkdir_p(batch_path)
    FileUtils.mkdir(export_path)
  end

  def next_batch_number
    batches = @event.batches.pluck(:number)
    batches.any? ? batches.map(&:to_i).sort.last.next.to_s : '1'
  end

  def save_upload_file(file, filename)
    file_path = Rails.root.join(batch_path, sanitize(filename)) 
    File.open(file_path, 'wb') { |f| f.write(file.read) }
  end

  def upload_file_error_check(filename)
    if @batch.batch_type == '1'
      errors = attendee_upload_errors?(filename)
    elsif @batch.batch_type == '2'
      errors = employee_upload_errors?(filename)
    end

    if errors
      delete_batch_dir
      @batch.destroy
    end
  end

  def delete_batch_dir
    FileUtils.remove_dir(batch_path) if Dir.exist?(batch_path)
  end

  def attendee_upload_errors?(filename)
    workbook = Rails.root.join(batch_path, filename)
    column_count = 0
    duplicate_rows = []
    blank_name_rows = []

    Spreadsheet.open(workbook) do |book|
      sheet = book.worksheet(0)
      column_count = sheet.column_count
      attendees_with_row = []

      sheet.each_with_index do |row, idx|
        row_num = (idx + 1).to_s
        blank_name_rows << row_num if missing_attendee_name?(row)
        next if row[2].blank?
        row = row.to_a
        attendees_with_row << [row[2], row[3], row_num]
      end

      attendees = attendees_with_row.map { |row| row.take(2) }
      dups = attendees.select { |row| attendees.count(row) > 1 }.uniq

      dups.each do |dup|
        rows = []
        attendees_with_row.each { |row| rows << row[2] if row.take(2) == dup }
        duplicate_rows << rows
      end
    end

    return attendee_errors?(column_count, duplicate_rows, blank_name_rows)
  end

  def missing_attendee_name?(row)
    row[2].blank? && row.any? { |cell| cell.present? }
  end

  def attendee_errors?(column_count, dups, blanks)
    if column_count != 13
      flash.alert = column_count_attendee_error_msg(column_count)
      return true
    elsif dups.any?
      flash.alert = duplicates_attendee_error_msg(dups)
      return true
    elsif blanks.any?
      flash.alert = blank_names_attendee_error_msg(blanks)
      return true
    else
      return false
    end
  end

  def column_count_attendee_error_msg(count)
    "Upload failed. Spreadsheet has #{count} columns. " +
    "Must have 13 Columns for attendees."
  end

  def duplicates_attendee_error_msg(dups)
    msg = "Upload failed. Duplicates exist at rows:<br /><ul>"

    dups.each do |row_nums|
      msg += "<li>"
      row_nums.each_with_index do |row_num, idx|
        msg += idx == 0 ? row_num : " / #{row_num}"
      end
      msg += "</li>"
    end

    msg += "</ul>"
  end

  def blank_names_attendee_error_msg(blank_rows)
    msg = "Upload failed. Contact Name is blank at rows:<br /><ul>"
    blank_rows.each { |row_num| msg += "<li>#{row_num}</li>" }
    msg += "</ul>"
  end

  def employee_upload_errors?(filename)
    workbook = Rails.root.join(batch_path, filename)
    column_count = 0
    blank_name_rows = []

    Spreadsheet.open(workbook) do |book|
      sheet = book.worksheet(0)
      column_count = sheet.column_count

      sheet.each_with_index do |row, idx|
        row_num = (idx + 1).to_s
        blank_name_rows << row_num if missing_employee_name?(row)
      end
    end

    employee_errors?(column_count, blank_name_rows)
  end

  def missing_employee_name?(row)
    row[0].blank? && row[1].blank? && row.any? { |cell| cell.present? }
  end

  def employee_errors?(column_count, blanks)
    if column_count != 10
      flash.alert = column_count_employee_error_msg(column_count)
      return true
    elsif blanks.any?
      flash.alert = blank_names_employee_error_msg(blanks)
      return true
    else
      return false
    end
  end

  def blank_names_employee_error_msg(blank_rows)
    msg = "Upload failed. Employee first AND last name is blank at rows:<br /><ul>"
    blank_rows.each { |row_num| msg += "<li>#{row_num}</li>" }
    msg += "</ul>"
  end

  def column_count_employee_error_msg(count)
    "Upload failed. Spreadsheet has #{count} columns. " +
    "Must have 10 Columns for employees."
  end

  def send_upload_file
    if upload_filename
      send_file(upload_file_path, type: 'application/vnd.ms-excel')
    else
      flash.alert = "Original upload file can't be found."
      redirect_to event_path(@event)
    end
  end

  def upload_filename
    Dir.entries(batch_path).select { |file| file[-4..-1] == '.xls' }.first
  end

  def upload_file_path
    Rails.root.join(batch_path, upload_filename)
  end

  def send_qr_codes_zip_file
    if zip_file?
      if @batch.batch_type == '1'
        send_file(zip_file, type: 'application/zip', filename: attendee_qr_name)
      elsif @batch.batch_type == '2'
        send_file(zip_file, type: 'application/zip', filename: employee_qr_name)
      end
    else
      flash.alert = "QR Codes zip file can't be found."
      redirect_to event_path(@event)
    end
  end

  def zip_file
    Rails.root.join(batch_path, 'qr_codes.zip')
  end

  def zip_file?
    File.exist?(zip_file)
  end

  def attendee_qr_name
    "QR_CODES_#{@event.name}#{'_' + @batch.location if @batch.location}_" +
    "BATCH_#{@batch.number}_Attendees.zip"
  end

  def employee_qr_name
    "QR_CODES_#{@event.name}_BATCH_#{@batch.number}_Employees.zip"
  end

  def send_export_file
    if export_file?
      if @batch.batch_type == '1'
        send_file(export_file, type: 'application/vnd.ms-excel',
          filename: attendee_export_name)
      elsif @batch.batch_type == '2'
        send_file(export_file, type: 'application/vnd.ms-excel',
          filename: employee_export_name)
      end
    else
      flash.alert = "Export file can't be found."
      redirect_to event_path(@event)
    end
  end

  def export_file
    Rails.root.join(export_path, 'export.xls')
  end

  def export_file?
    File.exist?(export_file)
  end

  def attendee_export_name
    "FINAL_#{@event.name}#{'_' + @batch.location if @batch.location}_" +
    "BATCH_#{@batch.number}_Attendees.xls"
  end

  def employee_export_name
    "FINAL_#{@event.name}_BATCH_#{@batch.number}_Employees.xls"
  end
end