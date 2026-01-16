/* Copyright (C) 2024 Illya Byelkin
   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License... */

import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Communications;
import Toybox.Activity;
import Toybox.ActivityMonitor;

class GarminSugarView extends WatchUi.WatchFace {
  private var sugarView;
  private var backgroundView;
  private var sugarArrowView;
  var mFontHuge;
  var mFontLarge;
  var mFontMedium;
  var mFontSmall;
  var mFontTiny;
  var mIconHeart;
  var mIconStep;
  var mIconBat;
  var mIconPhone;
  var mIconWeather;
  var mIconMountain;
  private var valuesGap;
  var width;
  var height;
  var centerX;
  var centerY;
  var scale;
  private var app;

  function initialize() {
    WatchFace.initialize();
    app = Application.getApp();
  }

  function onLayout(dc as Dc) as Void {
    setLayout(Rez.Layouts.WatchFace(dc));
    sugarView = View.findDrawableById("SugarLabel") as Text;
    backgroundView = View.findDrawableById("BackgroundId") as Background;
    sugarArrowView = View.findDrawableById("SugarArrow") as Text;

    mFontHuge = Graphics.FONT_NUMBER_MEDIUM;
    mFontLarge = Graphics.FONT_SYSTEM_LARGE;
    mFontMedium = Graphics.FONT_SYSTEM_MEDIUM;
    mFontSmall = Graphics.FONT_SYSTEM_XTINY;
    mFontTiny = Graphics.FONT_XTINY;

    width = dc.getWidth();
    height = dc.getHeight();
    centerX = width / 2;
    centerY = height / 2;
    scale = height / 280.0;

    mIconHeart = WatchUi.loadResource(Rez.Drawables.IconHeart);
    mIconStep = WatchUi.loadResource(Rez.Drawables.IconStep);
    mIconBat = WatchUi.loadResource(Rez.Drawables.IconBat);
    mIconPhone = WatchUi.loadResource(Rez.Drawables.IconPhone);
    mIconWeather = WatchUi.loadResource(Rez.Drawables.IconWeather);
    mIconMountain = WatchUi.loadResource(Rez.Drawables.IconMountain);

    backgroundView.updateSgv(dc, getSafeSgvData());
    valuesGap = 20;

    sugarView.setFont(mFontHuge);
    sugarArrowView.setFont(mFontMedium);
    sugarView.setJustification(
      Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
    );
    sugarArrowView.setJustification(
      Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
    );

    sugarView.setLocation(centerX, centerY - s(10));
    // sugarView.setFont(mFontLarge);
    sugarArrowView.setLocation(centerX, centerY - s(10) - height * 0.1);
  }

  function onShow() as Void {}

  function onUpdate(dc as Dc) as Void {
    var sgvData = getSafeSgvData();
    var sugar = "--";
    var sugarArrowStr = "x";
    var deltaStr = "";
    var timeDiffStr = "";

    if (app.getWasTempEvent()) {
      backgroundView.updateSgv(dc, sgvData);
    }

    var statusColor = Graphics.COLOR_ORANGE;
    var errorCode = null;

    if (sgvData instanceof Toybox.Lang.String) {
      statusColor = Graphics.COLOR_BLUE;
    } else if (sgvData instanceof Toybox.Lang.Dictionary) {
      statusColor = Graphics.COLOR_PURPLE;

      if (sgvData.get("error") != null) {
        statusColor = Graphics.COLOR_RED;
        errorCode = sgvData.get("error");
      } else if (sgvData.get("bg") != null) {
        statusColor = Graphics.COLOR_GREEN;

        if (sgvData.size() != 0) {
          var curr_time = Time.now().value().toLong(); // Garmin Time (Seconds)

          var dataChanged = Application.Storage.getValue("dataChanged");
          if (dataChanged == null) {
            dataChanged = 0;
          }
          var time_diff = curr_time - dataChanged;
          var trashhold = valuesGap * 60;

          var dataDict = sgvData as Dictionary;
          var bg_info = dataDict.get("bg") as Dictionary;
          var arrow = bg_info.get("trend") as String;

          // --- Extract Delta ---
          var dVal = bg_info.get("delta");
          if (dVal != null) {
            deltaStr = dVal.toString();
          }

          // --- Extract Time and Calc Diff ---
          // tVal is now expected to be Unix SECONDS (from JsonTransaction truncation)
          var tVal = bg_info.get("time");

          if (
            tVal != null &&
            (tVal instanceof Toybox.Lang.Number ||
              tVal instanceof Toybox.Lang.Long)
          ) {
            var tSeconds = tVal.toLong(); // This is Unix Seconds

            // Adaptive Epoch Check:
            // Standard Garmin devices return 1990-based seconds (approx 1.1 Billion in 2026)
            // Some newer devices/simulators return 1970-based seconds (approx 1.7 Billion in 2026)
            // We calculate diff directly first.
            var diffSec = curr_time - tSeconds;

            // If diff is huge negative (e.g. -600 million), it means curr_time is 1990-based
            // and we are comparing it to a 1970-based tSeconds.
            // We fix this by adding the offset (631065600).
            // Threshold: -300,000,000 (roughly -10 years difference)
            if (diffSec < -300000000) {
              diffSec += 631065600;
            }

            var diffMin = diffSec / 60;

            if (diffMin > 99) {
              diffMin = 99;
            }
            if (diffMin < 0) {
              diffMin = 0;
            }

            timeDiffStr = diffMin.format("%d") + " min";
          }

          var isStale = bg_info.get("isStale");
          var isRemoteStale = false;
          if (time_diff > trashhold) {
            isRemoteStale = true;
          }
          if (isStale != null && isStale instanceof Toybox.Lang.Boolean) {
            isRemoteStale = isStale;
          }

          if (!isRemoteStale) {
            switch (arrow) {
              case "Flat":
                sugarArrowStr = "→";
                break;
              case "FortyFiveUp":
                sugarArrowStr = "↗";
                break;
              case "FortyFiveDown":
                sugarArrowStr = "↘";
                break;
              case "SingleUp":
                sugarArrowStr = "↑";
                break;
              case "SingleDown":
                sugarArrowStr = "↓";
                break;
              case "DoubleUp":
                sugarArrowStr = "↑↑";
                break;
              case "DoubleDown":
                sugarArrowStr = "↓↓";
                break;
              default:
                sugarArrowStr = "x";
            }

            var status = dataDict.get("status") as Dictionary;
            if (status.get("isMgdl") == true) {
              var val = parseToFloat(bg_info.get("val"));
              sugar = val.format("%d");
            } else {
              var val = parseToFloat(bg_info.get("val"));
              sugar = val.format("%.1f");
            }
            sugarView.setText(sugar);
            sugarArrowView.setText(sugarArrowStr);
          } else {
            sugarArrowStr = "x";
            sugarArrowView.setText(sugarArrowStr);
          }
        }
      }
    }

    View.onUpdate(dc);
    drawTimeDateHR(dc, centerX, centerY, statusColor, errorCode);

    // Draw Delta and Time Diff
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

    // Right: Delta (NOW DEBUGGING tSeconds)
    if (!deltaStr.equals("")) {
      dc.drawText(
        centerX + s(40),
        centerY - s(10),
        mFontSmall,
        deltaStr,
        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
      );
    }
    // Left: Time Diff
    if (!timeDiffStr.equals("")) {
      dc.drawText(
        centerX - s(40),
        centerY - s(10),
        mFontSmall,
        timeDiffStr,
        Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
      );
    }
  }

  function drawTimeDateHR(dc, x, y, statusColor, errorCode) {
    dc.setColor(statusColor, Graphics.COLOR_TRANSPARENT);
    // Error Code
    if (errorCode != null) {
      dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
      dc.drawText(
        x + s(10),
        y + s(10),
        mFontTiny,
        errorCode.toString(),
        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
      );
    }
    var now = System.getClockTime();
    var date = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
    // Weather
    var tempStr = "--";
    if (Toybox has :Weather) {
      var cond = Weather.getCurrentConditions();
      if (cond != null && cond.temperature != null) {
        tempStr = cond.temperature.format("%d") + "°";
      }
    }
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    if (mIconWeather != null) {
      dc.drawBitmap(x - s(30), y - s(130), mIconWeather);
    }
    dc.drawText(
      x + s(10),
      y - s(115),
      mFontSmall,
      tempStr,
      Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
    );
    // Time
    var is24Hour = System.getDeviceSettings().is24Hour;
    var hour = now.hour;
    var amPm = "";
    if (!is24Hour) {
      amPm = hour < 12 ? "am" : "pm";
      hour = hour % 12;
      hour = hour == 0 ? 12 : hour;
    }

    var timeString = Lang.format("$1$:$2$", [
      hour.format("%02d"),
      now.min.format("%02d"),
    ]);
    var secString = now.sec.format("%02d");

    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    dc.drawText(
      x - s(11),
      y - s(106),
      mFontHuge,
      timeString,
      Graphics.TEXT_JUSTIFY_CENTER
    );
    dc.drawText(
      x + s(50),
      y - s(73),
      mFontTiny,
      secString,
      Graphics.TEXT_JUSTIFY_LEFT
    );

    if (!is24Hour) {
      dc.drawText(
        x + s(50),
        y - s(97),
        mFontTiny,
        amPm,
        Graphics.TEXT_JUSTIFY_LEFT
      );
    }

    // Date
    var dateString = Lang.format("$1$/$2$", [
      date.day.format("%02d"),
      date.month.format("%02d"),
    ]);
    var dayOfWeek = getDayOfWeek(date.day_of_week);
    var fullDateStr = Lang.format("$1$ $2$", [dayOfWeek, dateString]);
    dc.drawText(
      x,
      y + s(70),
      mFontSmall,
      fullDateStr,
      Graphics.TEXT_JUSTIFY_CENTER
    );

    // Arcs
    drawQuadArcs(dc, width, height);
    // HR
    drawHeartRate(dc, x, y + s(120));
  }

  function drawQuadArcs(dc, w, h) {
    var cx = w / 2;
    var cy = h / 2;
    var r = w / 2 - s(8);
    var thick = s(8);

    // 1. Steps
    var steps = 0;
    var info = ActivityMonitor.getInfo();
    if (info has :steps) {
      steps = info.steps;
    }
    if (steps == null) {
      steps = 0;
    }
    var stepPct = steps / 8000.0;
    drawSegment(
      dc,
      [cx, cy, r, thick],
      175,
      135,
      stepPct,
      Graphics.COLOR_YELLOW,
      Graphics.ARC_CLOCKWISE
    );
    if (mIconStep != null) {
      dc.drawBitmap(cx - s(120), cy - s(30), mIconStep);
    }
    drawValue(
      dc,
      cx - s(110),
      cy - s(45),
      steps.toString(),
      Graphics.TEXT_JUSTIFY_LEFT
    );

    // 2. Altitude/Depth
    var dBlue = 0x00008b;
    var valStr = "0";
    var pct = 0.0;
    var isDepth = false;
    var actInfo = Activity.getActivityInfo();
    if (actInfo has :currentDepth && actInfo.currentDepth != null) {
      var d = actInfo.currentDepth;
      var safetyAlt = 0;
      if (actInfo has :altitude && actInfo.altitude != null) {
        safetyAlt = actInfo.altitude;
      }
      var isLeakage = safetyAlt > 0 && (d - safetyAlt).abs() < 1.0;
      if (d > 0 && d < 150 && !isLeakage) {
        isDepth = true;
        pct = d / 10.0;
        valStr = d.format("%.1f");
        drawSegment(
          dc,
          [cx, cy, r, thick],
          45,
          5,
          pct,
          dBlue,
          Graphics.ARC_CLOCKWISE
        );
      }
    }
    if (!isDepth) {
      var alt = 0;
      if (actInfo has :altitude && actInfo.altitude != null) {
        alt = actInfo.altitude;
      }
      pct = alt / 1000.0;
      valStr = alt.format("%d");
      drawSegment(
        dc,
        [cx, cy, r, thick],
        5,
        45,
        pct,
        dBlue,
        Graphics.ARC_COUNTER_CLOCKWISE
      );
    }
    if (mIconMountain != null) {
      dc.drawBitmap(cx + s(90), cy - s(30), mIconMountain);
    }
    drawValue(dc, cx + s(110), cy - s(45), valStr, Graphics.TEXT_JUSTIFY_RIGHT);

    // 3. Watch Bat
    var stats = System.getSystemStats();
    var wbPct = stats.battery / 100.0;
    drawSegment(
      dc,
      [cx, cy, r, thick],
      315,
      355,
      wbPct,
      Graphics.COLOR_GREEN,
      Graphics.ARC_COUNTER_CLOCKWISE
    );
    if (mIconBat != null) {
      dc.drawBitmap(cx + s(95), cy + s(5), mIconBat);
    }
    drawValue(
      dc,
      cx + s(110),
      cy + s(45),
      stats.battery.format("%d"),
      Graphics.TEXT_JUSTIFY_RIGHT
    );

    // 4. Phone Bat
    var pbVal = 0;
    var sgvData = getSafeSgvData();
    if (sgvData instanceof Toybox.Lang.Dictionary) {
      var status = sgvData.get("status");
      if (status instanceof Toybox.Lang.Dictionary) {
        var val = status.get("bat");
        if (val instanceof Toybox.Lang.Number) {
          pbVal = val;
        } else if (val != null && val has :toNumber) {
          pbVal = val.toNumber();
        }
      }
    }
    var pbPct = pbVal / 100.0;
    var lBlue = 0xadd8e6;
    drawSegment(
      dc,
      [cx, cy, r, thick],
      225,
      185,
      pbPct,
      lBlue,
      Graphics.ARC_CLOCKWISE
    );
    if (mIconPhone != null) {
      dc.drawBitmap(cx - s(123), cy + s(7), mIconPhone);
    }
    drawValue(
      dc,
      cx - s(110),
      cy + s(45),
      pbVal.format("%d"),
      Graphics.TEXT_JUSTIFY_LEFT
    );
  }

  function drawSegment(dc, coords, startDeg, endDeg, pct, color, direction) {
    var cx = coords[0];
    var cy = coords[1];
    var r = coords[2];
    var thick = coords[3];
    if (pct < 0.0) {
      pct = 0.0;
    }
    if (pct > 1.0) {
      pct = 1.0;
    }
    dc.setPenWidth(thick);
    dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
    var s = startDeg.toNumber();
    var e = endDeg.toNumber();
    dc.drawArc(cx, cy, r, direction, s, e);
    if (pct > 0.01) {
      var range = e - s;
      var fillEnd = s + range * pct;
      var fe = fillEnd.toNumber();
      if (range > 0) {
        if (fe > e) {
          fe = e;
        }
      } else {
        if (fe < e) {
          fe = e;
        }
      }
      dc.setColor(color, Graphics.COLOR_TRANSPARENT);
      dc.drawArc(cx, cy, r, direction, s, fe);
    }
  }

  function drawValue(dc, x, y, text, justify) {
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    dc.drawText(x, y, mFontTiny, text, justify | Graphics.TEXT_JUSTIFY_VCENTER);
  }

  function drawHeartRate(dc, x, y) {
    var hr = "--";
    var info = ActivityMonitor.getInfo();
    if (ActivityMonitor has :getHeartRateHistory) {
      var iter = ActivityMonitor.getHeartRateHistory(1, true);
      var sample = iter.next();
      if (
        sample != null &&
        sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE
      ) {
        hr = sample.heartRate.toString();
      }
    } else if (info has :currentHeartRate) {
      if (info.currentHeartRate != null) {
        hr = info.currentHeartRate.toString();
      }
    }
    if (mIconHeart != null) {
      dc.drawBitmap(x - s(25), y - s(10), mIconHeart);
    }
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    dc.drawText(
      x + s(10),
      y,
      mFontSmall,
      hr,
      Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_LEFT
    );
  }

  function getDayOfWeek(dow) {
    if (dow == 1) {
      return "SUN";
    }
    if (dow == 2) {
      return "MON";
    }
    if (dow == 3) {
      return "TUE";
    }
    if (dow == 4) {
      return "WED";
    }
    if (dow == 5) {
      return "THU";
    }
    if (dow == 6) {
      return "FRI";
    }
    if (dow == 7) {
      return "SAT";
    }
    return "";
  }

  function getSafeSgvData() as Object? {
    return app.getSgvData();
  }

  function parseToFloat(val) {
    if (val instanceof Toybox.Lang.String) {
      return val.toFloat();
    } else if (
      val instanceof Toybox.Lang.Number ||
      val instanceof Toybox.Lang.Float
    ) {
      return val.toFloat();
    }
    return 0.0f;
  }

  function debugJson() {
    // Note: Use SECONDS here for testing if you use debugJson
    // 1768580367
    return {
      "bg" => {
        "trend" => "Flat",
        "val" => "10.2",
        "delta" => "+0.1",
        "isStale" => false,
        "time" => 1768580367,
      },
      "status" => { "bat" => 78 },
      "graph" => {
        "lines" => [],
      },
    };
  }

  function onHide() as Void {}
  function onExitSleep() as Void {}
  function onEnterSleep() as Void {}

  function onPartialUpdate(dc as Dc) as Void {
    var now = System.getClockTime();
    var secString = now.sec.format("%02d");
    var x = centerX + s(50);
    var y = centerY - s(73);
    var width = s(30);
    var height = s(25);
    dc.setClip(x, y, width, height);
    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
    dc.clear();
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    dc.drawText(x, y, mFontTiny, secString, Graphics.TEXT_JUSTIFY_LEFT);
    dc.clearClip();
  }

  function s(val) {
    return (val * scale + 0.5).toNumber();
  }
}
