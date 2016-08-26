class NotificationMailer < ApplicationMailer
	default from: 'qr.codes@divalsafety.com'

	helper :application

	def batch_generation_complete_email(event_name, batch, email, execution_time)
		@event_name = event_name
		@batch = batch
		@execution_time = execution_time
		mail(to: email, subject: "#{@event_name} - Batch #{@batch} is ready!")
	end
end