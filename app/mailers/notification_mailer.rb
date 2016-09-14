class NotificationMailer < ApplicationMailer

	def batch_generation_complete_email(event, batch, email)
		@event = event
		@batch = batch
		mail(to: email, subject: "#{@event.name} - Batch #{@batch.number} is Ready!")
	end
end