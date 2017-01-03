//= require jquery
//= require jquery_ujs
//= require turbolinks
//= require jquery.turbolinks
//= require bootstrap
//= require_tree .

function clearCrmCampaignSearch() {
  $('#name').val("");
  
  if ($('#crm-campaign-results')) { $('#crm-campaign-results').remove(); };
  if ($('#crm-campaign-no-results')) { $('#crm-campaign-no-results').remove(); };
  if ($('#crm-campaign-cancel-btn')) { $('#crm-campaign-cancel-btn').remove(); };
};

function clearCheckInSearch() {
  $('#check-in-fn').val("");
  $('#check-in-ln').val("");
  $('#check-in-an').val("");
  $('#check-in-submit-btn').removeClass('width-80');
  
  if ($('#check-in-results')) { $('#check-in-results').remove(); };
  if ($('#check-in-no-results')) { $('#check-in-no-results').remove(); };
  if ($('.check-in-cancel-btn')) { $('.check-in-cancel-btn').remove(); };
};

function clearCrmContactAndAccountSearch() {
  $('#crm-contact-ln').val("");
  $('#crm-contact-an').val("");
  $('#crm-contact-submit-btn').removeClass('width-80');
  
  if ($('#crm-contact-line')) { $('#crm-contact-line').remove(); };
  if ($('#crm-contact-search-results')) { $('#crm-contact-search-results').remove(); };
  if ($('#crm-contact-no-results')) { $('#crm-contact-no-results').remove(); };
  if ($('.crm-contact-cancel-btn')) { $('.crm-contact-cancel-btn').remove(); };

  $('#crm-account-an').val("");
  $('#crm-account-submit-btn').removeClass('width-80');
  
  if ($('#crm-account-line')) { $('#crm-account-line').remove(); };
  if ($('#crm-account-search-results')) { $('#crm-account-search-results').remove(); };
  if ($('#crm-account-no-results')) { $('#crm-account-no-results').remove(); };
  if ($('.crm-account-cancel-btn')) { $('.crm-account-cancel-btn').remove(); };
};

function clearCrmDivalEmployeeSearch() {
  $('#crm-dival-employee-fn').val("");
  $('#crm-dival-employee-ln').val("");
  $('#crm-dival-employee-submit-btn').removeClass('width-80');
  
  if ($('#crm-dival-employee-line')) { $('#crm-dival-employee-line').remove(); };
  if ($('#crm-dival-employee-results')) { $('#crm-dival-employee-results').remove(); };
  if ($('#crm-dival-employee-no-results')) { $('#crm-dival-employee-no-results').remove(); };
  if ($('#crm-dival-employee-cancel-btn')) { $('#crm-dival-employee-cancel-btn').remove(); };
};

function resetOnSiteAttendeeFormUrl() {
  var questionMarkIndex = $('#on-site-attendee-form').attr('action').indexOf('?');

  if (questionMarkIndex >= 0) {
    $('#on-site-attendee-form').attr('action', $('#on-site-attendee-form').attr('action').slice(0, questionMarkIndex));
  }
}

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
  $('#badge-type').addClass('hide-me');
  $('div.form-group').removeClass("has-error");
  resetOnSiteAttendeeFormUrl();
};

function resetCheckInForm() {
  if ($('div#flash-msg')) { $('div#flash-msg').remove(); };
  $('#check-in-fn').val("");
  $('#check-in-ln').val("");
  $('#check-in-an').val("");
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

function generateBatchSpinner() {
  var spinnerButton;
  spinnerButton = "<button class=\"btn btn-primary width-80\" disabled=\"disabled\">";
  spinnerButton += "<div class=\"spinner spinner-20\">";
  spinnerButton += "<div class=\"white\"></div><div class=\"white\"></div>";
  spinnerButton += "<div class=\"white\"></div><div class=\"white\"></div>";
  spinnerButton += "<div class=\"white\"></div><div class=\"white\"></div>";
  spinnerButton += "<div class=\"white\"></div><div class=\"white\"></div>";
  spinnerButton += "<div class=\"white\"></div><div class=\"white\"></div>";
  spinnerButton += "<div class=\"white\"></div><div class=\"white\"></div>";
  spinnerButton += "</div></button>";

  $(this).replaceWith(spinnerButton);
}

function batchesStatusCheck() {
  window.batchStatusCheck;
  var processingBatches = $("div.active-batch[status='2']");

  if (processingBatches.length > 0) {
    batchStatusCheck = setInterval(function() {
      processingBatches = $("div.active-batch[status='2']");

      if (processingBatches.length > 0) {
        processingBatches.each(function() {
          var ids = $(this).find('.list-group a:first-child').attr('href').match(/\d+/g);
          var eventId = ids[0];
          var batchId = ids[1];
          var url = "/events/" + eventId + "/batches/" + batchId + "/check-status";

          $.ajax({ url: url, dataType: 'script' });
        });
      }
    }, 15000);
  }
}

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
  $('#street1').val("31 Loring Dr");
  $('#street2').val("");
  $('#city').val("Framingham");
  $('#state').val("MA");
  $('#zip_code').val("01702");
};

function populateFloridaWhsAddress() {
  $('#street1').val("2207 Stirling Rd");
  $('#street2').val("");
  $('#city').val("Dania Beach");
  $('#state').val("FL");
  $('#zip_code').val("33314");
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

function adjustFontSizeAttendeeInfo() {
  while ($('#first-name').width() > 250) {
    $('#first-name').css('font-size', (parseInt($('#first-name').css('font-size')) - 1) + 'px');
  }

  while ($('#last-name').width() > 250) {
    $('#last-name').css('font-size', (parseInt($('#last-name').css('font-size')) - 1) + 'px');
  }

  while ($('#account-name').height() > 60) {
    $('#account-name').css('font-size', (parseInt($('#account-name').css('font-size')) - 1) + 'px');
  }

  if ($('#account-name').height() < 30) {
    $('#account-name').css('margin-top', '10px');
    $('img').css('margin-top', '5px');
  }
}

function adjustFontSizeDivalEmployeeInfo() {
  while ($('#first-name').width() > 250) {
    $('#first-name').css('font-size', (parseInt($('#first-name').css('font-size')) - 1) + 'px');
  }

  while ($('#last-name').width() > 250) {
    $('#last-name').css('font-size', (parseInt($('#last-name').css('font-size')) - 1) + 'px');
  }
}

function adjustFontSizeVendorInfo() {
  while ($('#first-name').width() > 270) {
    $('#first-name').css('font-size', (parseInt($('#first-name').css('font-size')) - 1) + 'px');
  }

  while ($('#last-name').width() > 270) {
    $('#last-name').css('font-size', (parseInt($('#last-name').css('font-size')) - 1) + 'px');
  }

  while ($('#account-name').height() > 95) {
    $('#account-name').css('font-size', (parseInt($('#account-name').css('font-size')) - 1) + 'px');
  }

  if ($('#account-name').height() < 50) {
    $('#account-name').css('margin-top', '10px');
  }
}