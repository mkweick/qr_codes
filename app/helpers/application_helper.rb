module ApplicationHelper

	def url_friendly(url)
		url.gsub ' ', '%20'
	end
end
