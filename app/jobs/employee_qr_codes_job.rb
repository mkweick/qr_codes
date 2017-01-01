class EmployeeQrCodesJob < ActiveJob::Base
  queue_as :default

  def perform(event, batch, email)
    @event, @batch = event, batch

    prep_batch_dir_structure
    export = Spreadsheet::Workbook.new
    sheet = export.create_worksheet name: @event.name
    style_export_sheet(sheet)

    Spreadsheet.open(upload_file) do |book|
      book.worksheet(0).map { |row| row.to_a }.drop(1).each do |row|
        next if row[0].blank? && row[1].blank?

        filename = build_filename(sheet, row[0], row[1])
        qr_code = generate_qr_code(row)
        save_qr_code(qr_code, filename)
        insert_employee_row(sheet, row, filename)
      end
    end

    export.write(export_file_path)
    zip_qr_codes
    delete_qr_codes_dir
    update_batch_status_to_complete
    email_requestor(email)
  end

  private

  def batch_path
    Rails.root.join('events', @event.id.to_s, @batch.number.to_s)
  end

  def prep_batch_dir_structure
    delete_qr_codes_dir
    delete_export_file_dir
    make_qr_codes_dir
    make_export_file_dir
  end

  def qr_codes_dir
    Rails.root.join(batch_path, 'qr_codes')
  end

  def qr_codes_dir?
    Dir.exist?(qr_codes_dir)
  end

  def delete_qr_codes_dir
    FileUtils.remove_dir(qr_codes_dir) if qr_codes_dir?
  end

  def make_qr_codes_dir
    Dir.mkdir(qr_codes_dir) unless qr_codes_dir?
  end

  def qr_codes_dir_path
    qr_codes_dir.to_s
  end

  def qr_codes_zip_file_path
    Rails.root.join(batch_path, 'qr_codes.zip').to_s
  end

  def qr_code_filenames
    Dir.entries(qr_codes_dir).select { |file| file[-4..-1] == '.png' }
  end

  def zip_qr_codes
    Zip::File.open(qr_codes_zip_file_path, Zip::File::CREATE) do |zip|
      qr_code_filenames.each do |filename|
        zip.add(filename, qr_codes_dir_path + '/' + filename)
      end

      zip.get_output_stream('') { |file| file.write '' }
    end
  end

  def export_file_dir
    Rails.root.join(batch_path, 'export')
  end

  def export_file_dir?
    Dir.exist?(export_file_dir)
  end

  def delete_export_file_dir
    FileUtils.remove_dir(export_file_dir) if export_file_dir?
  end

  def make_export_file_dir
    Dir.mkdir(export_file_dir) unless export_file_dir?
  end

  def export_file_path
    Rails.root.join(export_file_dir, 'export.xls')
  end

  def style_export_sheet(sheet)
    sheet.insert_row(0, export_header_row)
    sheet.row(0).default_format = Spreadsheet::Format.new :weight => :bold
    sheet.column(0).width = 26
    sheet.column(1).width = 30
    sheet.column(2).width = 38
    sheet.column(3).width = 45
  end

  def export_header_row
    ['First Name', 'Last Name', 'Company', 'QR Code']
  end

  def upload_file
    Rails.root.join(batch_path, upload_filename)
  end

  def upload_filename
    Dir.entries(batch_path).select { |file| file[-4..-1] == '.xls' }.first
  end

  def build_filename(export_sheet, first_name, last_name)
    first_name = first_name.strip if first_name
    last_name = last_name.strip if last_name

    filename = sanitize("#{first_name if first_name}" +
      "#{" " if first_name && last_name}#{last_name if last_name}.png")

    dups = duplicate_filenames(export_sheet, filename)
    increment_filename(dups, filename) if dups.any?

    filename
  end

  def duplicate_filenames(export_sheet, filename)
    export_sheet.column(3).drop(1).select do |name|
      filename == name.gsub(/-{1}\d+/, '')
    end
  end

  def increment_filename(duplicates, filename)
    last_number = duplicates.last[-5]

    if last_number =~ /\d/
      incrementer = last_number.to_i.next.to_s
      filename.insert(-5, "-#{incrementer}")
    else
      filename.insert(-5, '-1')
    end
  end

  def generate_qr_code(row)
    RQRCode::QRCode.new(
      "MATMSG:TO:;SUB:DIVAL SALES REP REQUEST;BODY:" +
      "\n\n\n______________________" +
      "\n" + "N: " + "#{row[0] + " " if row[0]}" + "#{row[1] if row[1]}" +
      "\n" + "T: " + "#{row[2] if row[2]}" +
      "\n" + "E: " + "#{row[8] if row[8]}" +
      "\n" + "P: " + "#{row[9] if row[9]}" +
      "\n\n" + "DiVal Safety Equipment" +
      "\n" + "AD1: " + "#{row[3] if row[3]}" +
      "\n" + "AD2: " + "#{row[4] if row[4]}" +
      "\n" + "CSZ: " + "#{row[5] if row[5]}" +
        "#{', ' if row[5] && row[6]}" +
        "#{row[6] if row[6]} " +
        "#{row[7] if row[7]};;",
      level: :l
    )
  end

  def save_qr_code(qr_code, filename)
    qr_code.to_img.resize(375, 375).save("#{qr_codes_dir_path}/#{filename}")
  end

  def insert_employee_row(export_sheet, row, filename)
    employee_data_row = [row[0], row[1], "DiVal Safety Equipment", filename]
    next_row = export_sheet.last_row_index + 1

    export_sheet.insert_row(next_row, employee_data_row)
  end

  def update_batch_status_to_complete
    @batch.update(processing_status: '3')
  end

  def email_requestor(email)
    NotificationMailer.batch_complete_email(@event, @batch, email).deliver_now
  end

  def sanitize(filename)
    filename.gsub(/[\\\/:*"'?<>|]/, '')
  end
end
