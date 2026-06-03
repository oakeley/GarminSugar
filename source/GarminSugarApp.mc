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

  // Glucose reading time (Unix seconds) carried in the dict, or 0 if absent.
  function bgTimeOf(data) as Lang.Long {
    if (!(data instanceof Toybox.Lang.Dictionary)) {
      return 0l;
    }
    var bg = data.get("bg");
    if (!(bg instanceof Toybox.Lang.Dictionary)) {
      return 0l;
    }
    var t = bg.get("time");
    if (t instanceof Toybox.Lang.Long) {
      return t;
    }
    if (t instanceof Toybox.Lang.Number) {
      return t.toLong();
    }
    return 0l;
  }

  // Adopt incoming data ONLY if its glucose reading is strictly newer than
  // what is already displayed. Lets the complication and HTTP channels run
  // in parallel with "newest reading wins", and stops a stale-but-repeating
  // complication value from clobbering a fresher HTTP fetch (and vice versa).
  function adoptIfNewer(data) {
    if (bgTimeOf(data) > bgTimeOf(sgvData)) {
      sgvData = data;
      dataChanged = Time.now().value();
      Application.Storage.setValue("sgvData", sgvData);
      Application.Storage.setValue("dataChanged", dataChanged);
      wasTempEvent = true;
      return true;
    }
    return false;
  }

  // Push live glucose from the foreground complication path. Mirrors
  // onBackgroundData so the View + graph pick it up identically to HTTP.
  function setLiveSgvData(data as Dictionary) as Void {
    adoptIfNewer(data);
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
    // Only update the display and Storage when the background fetch returned
    // real glucose data (has a "bg" key). Error responses ({"error": code})
    // are silently discarded so the last known good graph stays visible.
    if (data instanceof Toybox.Lang.Dictionary && data.get("bg") != null) {
      adoptIfNewer(data);
    }

    // Always request a UI refresh so the clock face continues to update
    // even when no new glucose data was received.
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
