class NotificationMailer < ApplicationMailer

	def batch_generation_complete_email(event, batch, email)
		@event = event
		@batch = batch

    if @batch.location
      if @batch.batch_type == '1'
        mail(
          to: email,
          subject: "#{@event.name} - #{@batch.location} - Batch " +
            "#{@batch.number} - Attendees is Ready!"
        )
      elsif @batch.batch_type == '2'
        mail(
          to: email,
          subject: "#{@event.name} - Batch #{@batch.number} - Employees is Ready!"
        )
      end
    else
		  if @batch.batch_type == '1'
        mail(
          to: email,
          subject: "#{@event.name} - Batch #{@batch.number} - Attendees is Ready!"
        )
      elsif @batch.batch_type == '2'
        mail(
          to: email,
          subject: "#{@event.name} - Batch #{@batch.number} - Employees is Ready!"
        )
      end
    end
	end
end