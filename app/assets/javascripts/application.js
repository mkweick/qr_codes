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
  $('#crm-dival-employee-fn').val("");
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
  $('#title').val("");
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

function populateBuffaloWhsAddress() {
  $('#street1').val("1721 Niagara St");
  $('#street2').val("");
  $('#city').val("Buffalo");
  $('#state').val("NY");
  $('#zip_code').val("14207");
};

function populateRochesterWhsAddress() {
  $('#street1').val("845 West Ave");
  $('#street2').val("Building 7");
  $('#city').val("Rochester");
  $('#state').val("NY");
  $('#zip_code').val("14611");
};

function populateSyracuseWhsAddress() {
  $('#street1').val("6179 East Molloy Rd");
  $('#street2').val("");
  $('#city').val("East Syracuse");
  $('#state').val("NY");
  $('#zip_code').val("13057");
};

function populateHoustonWhsAddress() {
  $('#street1').val("3131 Federal Rd");
  $('#street2').val("");
  $('#city').val("Pasadena");
  $('#state').val("TX");
  $('#zip_code').val("77504");
};

function populatePittsburghWhsAddress() {
  $('#street1').val("311 South Central Ave");
  $('#street2').val("");
  $('#city').val("Canonsburg");
  $('#state').val("PA");
  $('#zip_code').val("15317");
};

function populateBostonWhsAddress() {
  $('#street1').val("31 Loring Rd");
  $('#street2').val("");
  $('#city').val("Framingham");
  $('#state').val("MA");
  $('#zip_code').val("01702");
};

function populateFloridaWhsAddress() {
  $('#street1').val("2207 Sterling Rd");
  $('#street2').val("");
  $('#city').val("Dania Beach");
  $('#state').val("FL");
  $('#zip_code').val("33312");
};

function showOrRemoveLocations() {
  if (typeof batchLocationGroup === 'undefined') {
    window.batchLocationGroup = $('#batch-location-group')[0];
  }

  if ($("#batch_batch_type option[value='2']").is(':selected')) {
    $('#batch-location-group').remove();
  } else {
    $(batchLocationGroup).insertAfter('#batch-type-group');
  }
};