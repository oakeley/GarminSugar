import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;
using Toybox.Background;

class GarminSugarApp extends Application.AppBase {
  private var dataChanged;
  private var wasTempEvent = false;
  private var sgvData = ({}) as Dictionary;

  function getWasTempEvent() as Boolean {
    if (wasTempEvent) {
      wasTempEvent = false;
      return true;
    } else {
      return false;
    }
  }

  function getSgvData() as Dictionary {
    return sgvData;
  }

  function initialize() {
    AppBase.initialize();
  }

  function onStart(state as Dictionary?) as Void {
    var dataTmp = Storage.getValue("sgvData");
    var flag = Storage.getValue("dataChanged");
    if (dataTmp != null) {
      sgvData = dataTmp;
    }
    if (flag != null) {
      dataChanged = flag;
    }
    // if(Toybox.System has :ServiceDelegate) {
    //  Background.registerForTemporalEvent(new Time.Duration(5 * 60));
    // }
  }

  function onStop(state as Dictionary?) as Void {}

  function getInitialView() {
    if (Toybox.System has :ServiceDelegate) {
      Background.registerForTemporalEvent(new Time.Duration(5 * 60));
    } else {
      System.println("****background not available on this device****");
    }

    return [new GarminSugarView()];
  }

  function getServiceDelegate() {
    return [new JsonTransaction()];
  }

  function onBackgroundData(data) {
    sgvData = data;
    if (sgvData instanceof Dictionary && sgvData.size() != 0) {
      dataChanged = Time.now().value();
      Storage.setValue("sgvData", sgvData);
      Storage.setValue("dataChanged", dataChanged);
    }
    wasTempEvent = true;

    WatchUi.requestUpdate();
  }

  /**
   * Converts the string with a hex value inside in a number,
   * if the string is not in 0xnnnnnn format, where n is between
   * 0 and F(f) returns the default value.
   *
   * @param str String to convert
   * @param default_val default value
   * @return Number stored in the string or the default value
   */
}

function getApp() as GarminSugarApp {
  return Application.getApp() as GarminSugarApp;
}
