class BatchesController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create]
  before_action :set_event
  before_action :require_user, except: [:create]
  before_action :require_user_batch_upload, only: [:create]
  before_action :require_admin

  def create
    file = params[:batch][:file] if params[:batch][:file]

    if file && file.original_filename[-4..-1].downcase == '.xls'
      batches = @event.batches.pluck(:number)
      next_batch = batches.any? ? batches.map(&:to_i).sort.last.next.to_s : '1'

      @batch = @event.batches.create(batch_params.merge(number: next_batch))

      if @batch.save
        make_batch_dir(@event.id, @batch.id)

        filename = sanitize(file.original_filename)
        File.open(Rails.root.join('events', @event.id.to_s, @batch.id.to_s, filename), 'wb') do |f|
          f.write(file.read)
        end

        if upload_has_errors?(@event.id.to_s, @batch.id.to_s, filename)
          delete_batch_dir(@event.id, @batch.id)
          @batch.destroy
        else
          flash.notice = "Batch created."
        end

        redirect_to event_path(@event)
      else
        @batches = @event.batches.order(:number)
        @locations = Location.sorted_locations.pluck(:city) if @event.multiple_locations
        render 'events/show'
      end
    else
      flash.alert = "Upload file must be <strong>.xls</strong> format."
      redirect_to event_path(@event)
    end
  end

  def edit

  end

  def update

  end

  def destroy

  end

  private

  def batch_params
    params.require(:batch).permit(:location, :description)
  end

  def set_event
    @event = Event.find(params[:event_id]) if params[:event_id]
  end

  def make_batch_dir(event, batch)
    FileUtils.mkdir_p(Rails.root.join('events', event.to_s, batch.to_s))
    FileUtils.mkdir(Rails.root.join('events', event.to_s, batch.to_s, 'export'))
  end

  def delete_batch_dir(event, batch)
    FileUtils.remove_dir(Rails.root.join('events', event.to_s, batch.to_s))
  end

  def upload_has_errors?(event, batch, filename)
    duplicates = []
    column_count = 0
    workbook = Rails.root.join('events', event, batch, filename)

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
      else
        return false
      end
    else
      flash.alert = "Spreadsheet contained #{column_count} columns. " +
                    "Spreadsheet must only have 14 Columns. " +
                    "#{view_context.link_to 'DOWNLOAD TEMPLATE',
                      download_path(type: 'template'),
                      data: { turbolinks: false }}"
      return true
    end
  end
end