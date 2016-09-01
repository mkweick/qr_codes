module ApplicationHelper

	def format_page_title
    if @page_title.blank?
      'Event QR Codes - DiVal Safety'
    else
      "#{@page_title} - Event QR Codes - DiVal Safety"
    end
  end
end
