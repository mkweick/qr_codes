class NotificationMailer < ApplicationMailer

	def batch_generation_complete_email(event, batch, email)
		@event = event
		@batch = batch

    if @batch.location
      mail(
        to: email,
        subject: "#{@event.name} - #{@batch.location} - Batch #{@batch.number} is Ready!"
      )
    else
		  mail(
        to: email,
        subject: "#{@event.name} - Batch #{@batch.number} is Ready!"
      )
    end
	end
end