if (typeof compound_checkVar === 'undefined') {

  var compound_checkVar=1;

  var req = new XMLHttpRequest();
  req.open('GET', document.location, false);
  req.send(null);
  var csrfToken = req.getResponseHeader('X-FHEM-csrfToken');

  var compound_icon={};

  compound_icon.loading='<svg xmlns:svg="http://www.w3.org/2000/svg" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.0" viewBox="0 0 128 128" xml:space="preserve"><g transform="rotate(-32.1269 64 64)"><path d="M78.75 16.18V1.56a64.1 64.1 0 0 1 47.7 47.7H111.8a49.98 49.98 0 0 0-33.07-33.08zM16.43 49.25H1.8a64.1 64.1 0 0 1 47.7-47.7V16.2a49.98 49.98 0 0 0-33.07 33.07zm33.07 62.32v14.62A64.1 64.1 0 0 1 1.8 78.5h14.63a49.98 49.98 0 0 0 33.07 33.07zm62.32-33.07h14.62a64.1 64.1 0 0 1-47.7 47.7v-14.63a49.98 49.98 0 0 0 33.08-33.07z" fill-opacity="1"/><animateTransform attributeName="transform" type="rotate" from="0 64 64" to="-90 64 64" dur="1800ms" repeatCount="indefinite"/></g></svg>';


  function compound_encodeParm(oldVal) {
      var newVal;
      newVal = oldVal.replace(/\$/g, '\\%24');
      newVal = newVal.replace(/"/g, '%27');
      newVal = newVal.replace(/#/g, '%23');
      newVal = newVal.replace(/\+/g, '%2B');
      newVal = newVal.replace(/&/g, '%26');
      newVal = newVal.replace(/'/g, '%27');
      newVal = newVal.replace(/=/g, '%3D');
      newVal = newVal.replace(/\?/g, '%3F');
      newVal = newVal.replace(/\|/g, '%7C');
      newVal = newVal.replace(/\s/g, '%20');
      return newVal;
  };﻿
  function compound_dialog(message,tTitle) {
      $('<div></div>').appendTo('body').html('<div>' + message + '</div>').dialog({
          modal: true, title: tTitle, zIndex: 10000, autoOpen: true,
          width: 'auto', resizable: false,
          buttons: {
              OK: function () {
                  $(this).dialog("close");
              }
          },
          close: function (event, ui) {
              $(this).remove();
          }
      });
      setTimeout(function(){
        $('.ui-dialog').remove();
      },10000);
  };

  function compound_ErrorDialog(name,text,title) {
    compound_dialog(text,title);
    compound_removeLoading(name);
  }

  function compound_addLoading() {
    if ( $('.compound_devType').find('.compound_loadingDiv').length ) {
      $('.compound_devType').find('.compound_loadingDiv').remove();
    }
    else {
      $('.compound_devType').append('<div class="compound_icon compound_loadingDiv">' + compound_icon.loading + '</div>');
      setTimeout(function(){
        compound_removeLoading(name);
      }, 10000);
    }
  }

  function compound_removeLoading() {
    $('.compound_devType').find('.compound_loadingDiv').remove();
  }

  function compound_sendCommand(cmd) {
    var name = cmd.split(" ")[1];
    compound_addLoading();
    var location = document.location.pathname;
    if (location.substr(location.length -1, 1) == '/') {
        location = location.substr(0, location.length -1);
    }
    var url = document.location.protocol + "//" + document.location.host + location;
    FW_cmd(url + '?XHR=1&fwcsrf=' + csrfToken + '&cmd.' + name + '=' + cmd);
  }

  function compound_reloadTable(val) {
    $('table#compound_schaltung_table').find('tbody#compound_data_body').remove();
    $('table#compound_schaltung_table').find('#compound_head_th').after(val);
    compound_removeLoading();
  }

  function compound_reloadPlan(val) {
    $('div.compound_plan_outer_container').find('div.compound_plan_container').remove();
    $('div.compound_plan_outer_container').html(val);
    compound_removeLoading();
  }

  $(document).ready(function(){
    $('.compound_name').each(function() {
      var name = $(this).val();
      $('#compound_schaltung_table').on('click','span.compound_status_span_'+name,function(e) {
        var val = $(this).attr('data-do');
        compound_sendCommand('set ' + name + ' ' +  val);
        return false;
      });
      $('#compound_schaltung_table').on('click','td.compound_switch_'+name+' span',function(e) {
        var val = $(this).attr('data-do');
        if (val!="-") {
          var dev = $(this).attr('data-device');
          compound_sendCommand('set ' + name + ' ' + dev + '_state ' +  val);
        }
        return false;
      });
      $('div.compound_plan_outer_container').on('click','td.doDown_'+name,function(e) {
        if (confirm(compound_tt.areyousure)) {
          var id = $(this).attr('data-id');
          var val = $(this).prev().find('input').val();
          if (id == "copy_light_"+name) $('#compound_data_body_' + name + ' .compound_lightInput').val(val);
          if (id == "copy_heat_"+name) $('#compound_data_body_' + name + ' .compound_heatInput').val(val);
          if (id == "copy_cam_"+name) $('#compound_data_body_' + name + ' .compound_camInput').val(val);
          if (id == "copy_cool_"+name) $('#compound_data_body_' + name + ' .compound_coolInput').val(val);
          $(this).prev().find('input').trigger( "blur" );
        }
        return false;
      });
      $('#compound_schaltung_table').on('change','select#compound_compound_' + name,function(e) {
        var val = $(this).val();
        compound_sendCommand('set ' + name + ' compound ' +  val);
        return false;
      });
      $('input.compound_plan_input_' + name).each(function() {
        var tid = $(this).attr("data-tid");
        $('div.compound_plan_outer_container').on('click','span.compound_plan_text_' + name + '[data-tid="' + tid + '"]',function(e) {
          var val=$(this).html();
          var width=$(this).width()+5;
          $(this).hide();
          $("input[data-tid='" + tid +"']").show().focus().val("").val(val).width(width);
        });
      });
      $('div.compound_plan_outer_container').on('blur keypress','input.compound_plan_input_' + name,function(e) {
        if (e.type!='keypress' || e.which==13) {
          var tVal = $(this).val();
          var id = this.id;
          var tid = $(this).attr("data-tid");
          var dev = $(this).attr('data-name');
          if (tVal!="" && dev!="") {
            var type="light";
            if ($(this).hasClass('compound_heatInput')) type="heat";
            else if ($(this).hasClass('compound_camInput')) type="cam";
            else if ($(this).hasClass('compound_coolInput')) type="cool";
            var arr=[];
            $('#compound_data_body_'+name+' .compound_'+type+'Input').each(function() {
              var no = $(this).attr('data-no');
              var arrno = no-1;
              var val = $(this).val();
              if (val!="-" && val!="") arr[arrno] = no + " " + val;
            });
            $(this).hide();
            $("span.compound_plan_text_" + name +"[data-tid='" + tid +"']").html(tVal);
            $("span.compound_plan_text_" + name +"[data-tid='" + tid +"']").show();
            var data = arr.join("␤");
            compound_sendCommand('set ' + name + ' ' + dev + '_plan ' +  data);
          }
        }
      });
    });
  });
}