class NotificationMailer < ApplicationMailer

	def batch_complete_email(event, batch, email)
		@event = event
		@batch = batch
    subject = "#{@event.name}#{' - ' + @batch.location if @batch.location}" +
      " - Batch #{@batch.number} - " +
      "#{@batch.batch_type == '1' ? 'Attendees' : 'Employees'} is Ready!"

    mail(to: email, subject: subject)
	end

  def customer_checked_in_email_salesrep(event, email, fn, ln, an)
    @event = event
    @first_name = fn
    @last_name = ln
    @account_name = an
    from = 'Customer Arrived <noreply@divalsafety.com>'
    subject = "#{fn if fn}#{' ' + ln if ln}#{' - ' + an if an}"

    mail(to: email, from: from, subject: subject)
  end
end