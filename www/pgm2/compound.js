if (typeof compound_checkVar === 'undefined') {

  var compound_checkVar=1;

  var req = new XMLHttpRequest();
  req.open('GET', document.location, false);
  req.send(null);
  var csrfToken = req.getResponseHeader('X-FHEM-csrfToken');

  var compound_icon={};
  
  var compound_svgPrefix='<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><path ';
  
  compound_icon.save=compound_svgPrefix+'d="M433.941 129.941l-83.882-83.882A48 48 0 0 0 316.118 32H48C21.49 32 0 53.49 0 80v352c0 26.51 21.49 48 48 48h352c26.51 0 48-21.49 48-48V163.882a48 48 0 0 0-14.059-33.941zM272 80v80H144V80h128zm122 352H54a6 6 0 0 1-6-6V86a6 6 0 0 1 6-6h42v104c0 13.255 10.745 24 24 24h176c13.255 0 24-10.745 24-24V83.882l78.243 78.243a6 6 0 0 1 1.757 4.243V426a6 6 0 0 1-6 6zM224 232c-48.523 0-88 39.477-88 88s39.477 88 88 88 88-39.477 88-88-39.477-88-88-88zm0 128c-22.056 0-40-17.944-40-40s17.944-40 40-40 40 17.944 40 40-17.944 40-40 40z"/></svg>';
  compound_icon.restore=compound_svgPrefix+'d="M527.943 224H480v-48c0-26.51-21.49-48-48-48H272l-64-64H48C21.49 64 0 85.49 0 112v288c0 26.51 21.49 48 48 48h400a48.001 48.001 0 0 0 40.704-22.56l79.942-128c19.948-31.917-3.038-73.44-40.703-73.44zM54 112h134.118l64 64H426a6 6 0 0 1 6 6v42H152a48 48 0 0 0-41.098 23.202L48 351.449V117.993A5.993 5.993 0 0 1 54 112zm394 288H72l77.234-128H528l-80 128z"/></svg>';

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

  function compound_reloadPlan(name,val) {
    $('div.compound_plan_outer_container').find('#compound_data_body_' + name).html(val);
    compound_removeLoading();
  }
  
  function resizable (el, factor) {
    var int = Number(factor) || 7.7;
    function resize() {el.style.width = ((el.value.length+1) * int) + 'px'}
    var e = 'keyup,keypress,focus,blur,change'.split(',');
    for (var i in e) el.addEventListener(e[i],resize,false);
    resize();
  }
  function compound_setTimer(ele) {
    var name = $(ele).parent().attr('data-name');
    var dev = $(ele).parent().find('.set_compound_device').val();
    var type = $(ele).parent().find('.set_compound_type').val();
    var time = $(ele).parent().find('.set_compound_timer').val();
    if (dev!="" && type!="" && time!="") {
      compound_sendCommand('set ' + name + ' ' + dev + '_state ' + type + ' ' +  time);
    }
    return false;
  }
  
  function compound_addHeaders() {
    $("<div class='compound_save compound_icon' title='" + compound_tt.save + "'> </div>").appendTo($('.compound_devType_plan')).html(compound_icon.save);
    $("<div class='compound_restore compound_icon' title='" + compound_tt.restore + "'> </div>").appendTo($('.compound_devType_plan')).html(compound_icon.restore);
  }

  $(document).ready(function(){
    compound_addHeaders();
    $('.compound_on-till_container').on('change','.set_compound_type',function(e) {
      var val = $(this).val();
      var timeInput = $(this).parent().find('.set_compound_timer');
      var timeInputVal = $(this).parent().find('.set_compound_timer_hidden').val();
      var tType = $(timeInput).attr('type');
      if (val == "on-till" && tType != "time") $(timeInput).attr('type','time').val(timeInputVal);
      if (val == "on-for-timer" && tType != "text") $(timeInput).attr('type','text').val(3600);
    });
    $('.compound_name').each(function() {
      var name = $(this).val();
      $('.compound_plan_outer_container').on('click','.compound_on-till_container[data-name=' + name + '] .set',function(e) {
        compound_setTimer(this);
      });
      $('.compound_plan_outer_container').on('keypress','.compound_on-till_container[data-name=' + name + '] .set_compound_timer',function(e) {
        if (e.which==13) {
          compound_setTimer(this);
        }
      });
      $('#compound_schaltung_table').on('click','span.compound_status_span_'+name,function(e) {
        var val = $(this).attr('data-do');
        compound_sendCommand('set ' + name + ' ' +  val);
        return false;
      });
      $('div.compound_plan_outer_container').on('click','.compound_devType_' + name +' div.compound_save',function(e) {
        compound_sendCommand('set ' + name + ' save');
      });
      $('div.compound_plan_outer_container').on('click','.compound_devType_' + name +' div.compound_restore',function(e) {
        if (confirm(compound_tt.restoreconfirm)) {
          compound_sendCommand('set ' + name + ' restore');
        }
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
          if (id == "copy_light_"+name) {
             $('#compound_data_body_' + name + ' .compound_lightInput').val(val);
             $('#compound_data_body_' + name + ' .compound_plan_light_text').html(val);
          }
          if (id == "copy_heat_"+name) {
            $('#compound_data_body_' + name + ' .compound_heatInput').val(val);
            $('#compound_data_body_' + name + ' .compound_plan_heat_text').html(val);
          }
          if (id == "copy_cam_"+name) {
            $('#compound_data_body_' + name + ' .compound_camInput').val(val);
            $('#compound_data_body_' + name + ' .compound_plan_cam_text').html(val);
          }
          if (id == "copy_cool_"+name) {
            $('#compound_data_body_' + name + ' .compound_coolInput').val(val);
            $('#compound_data_body_' + name + ' .compound_plan_cool_text').html(val);
          }
          var e = jQuery.Event("keypress");
          e.which = 13;
          $(this).prev().find('input').show().trigger(e);
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
        var tid = $(this).attr("data-tid");
        if (e.type=="blur" || e.type=="focusout") {
          $(this).hide();
          $("span.compound_plan_text_" + name +"[data-tid='" + tid +"']").show();
        }
        else if (e.which==13 && e.type=='keypress') {
          var tVal = $(this).val();
          var id = this.id;
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
        else if (e.type=='keypress' && e.which!=13) {
          resizable(this,7);
        }
      });
    });
  });
}