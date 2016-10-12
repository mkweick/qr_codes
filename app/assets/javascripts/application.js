//= require jquery
//= require jquery_ujs
//= require turbolinks
//= require jquery.turbolinks
//= require bootstrap
//= require_tree .

function clearCrmContactAndAccountSearch() {
  $('#crm-contact-ln').val("");
  $('#crm-contact-an').val("");
  
  if ($('#crm-contact-line')) { $('#crm-contact-line').remove(); };
  if ($('#crm-contact-results')) { $('#crm-contact-results').remove(); };
  if ($('#crm-contact-no-results')) { $('#crm-contact-no-results').remove(); };
  if ($('#crm-contact-cancel-btn')) { $('#crm-contact-cancel-btn').remove(); };

  $('#crm-account-an').val("");
  
  if ($('#crm-account-line')) { $('#crm-account-line').remove(); };
  if ($('#crm-account-results')) { $('#crm-account-results').remove(); };
  if ($('#crm-account-no-results')) { $('#crm-account-no-results').remove(); };
  if ($('#crm-account-cancel-btn')) { $('#crm-account-cancel-btn').remove(); };
};

function clearCrmDivalEmployeeSearch() {
  $('#crm-dival-employee-ln').val("");
  
  if ($('#crm-dival-employee-line')) { $('#crm-dival-employee-line').remove(); };
  if ($('#crm-dival-employee-results')) { $('#crm-dival-employee-results').remove(); };
  if ($('#crm-dival-employee-no-results')) { $('#crm-dival-employee-no-results').remove(); };
  if ($('#crm-dival-employee-cancel-btn')) { $('#crm-dival-employee-cancel-btn').remove(); };
};

function resetNewAttendeeForm() {
  if ($('div#flash-msg')) { $('div#flash-msg').remove(); };
  if ($('div#obj-errors')) { $('div#obj-errors').remove(); };
  $('#on_site_attendee_contact_in_crm').val("false");
  $('#on_site_attendee_first_name').val("");
  $('#on_site_attendee_last_name').val("");
  $('#on_site_attendee_account_name').val("");
  $('#on_site_attendee_account_number').val("");
  $('#on_site_attendee_street1').val("");
  $('#on_site_attendee_street2').val("");
  $('#on_site_attendee_city').val("");
  $('#on_site_attendee_state').val("");
  $('#on_site_attendee_zip_code').val("");
  $('#on_site_attendee_email').val("");
  $('#on_site_attendee_phone').val("");
  $('#on_site_attendee_salesrep').val("");
  $('input[type=radio]').prop('checked', function() {
    return this.getAttribute('checked') == 'checked';
  });
  $('div.form-group').removeClass("has-error");
};

function resetDivalEmployeeForm() {
  if ($('div#flash-msg')) { $('div#flash-msg').remove(); };
  $('#first_name').val("");
  $('#last_name').val("");
  $('#account_name').val("");
  $('#street1').val("");
  $('#street2').val("");
  $('#city').val("");
  $('#state').val("");
  $('#zip_code').val("");
  $('#email').val("");
  $('#phone').val("");
};

function resetVendorForm() {
  if ($('div#flash-msg')) { $('div#flash-msg').remove(); };
  $('#first_name').val("");
  $('#last_name').val("");
  $('#vendor_name').val("");
};