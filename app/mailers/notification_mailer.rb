class NotificationMailer < ApplicationMailer

	def batch_generation_complete_email(event, batch, email)
		@event = event
		@batch = batch

    if @batch.batch_type == '1'
      mail(to: email,
        subject: "#{@event.name}#{' - ' + @batch.location if @batch.location}" +
          " - Batch #{@batch.number} - Attendees is Ready!"
      )
    elsif @batch.batch_type == '2'
      mail(
        to: email,
        subject: "#{@event.name} - Batch #{@batch.number} - Employees is Ready!"
      )
    end
	end

  def customer_checked_in_email_salesrep(event, email, fn, ln, an)
    @event = event
    @first_name = fn
    @last_name = ln
    @account_name = an

    mail(from: 'Customer Arrived <noreply@divalsafety.com>', to: email,
      subject: "#{@first_name if @first_name}" +
        "#{' ' + @last_name if @last_name}" +
        "#{' - ' + @account_name if @account_name}"
    )
  end
end