class NotificationMailer < ApplicationMailer
	default from: 'qr.codes@divalsafety.com'

	def batch_generation_complete_email(event_name, batch, email)
		@event_name = event_name
		@batch = batch
		mail(to: email, subject: "#{@event_name} - Batch #{@batch} is ready!")
	end
end