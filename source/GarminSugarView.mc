/* Copyright (C) 2024 Illya Byelkin

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>. */

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
  // private var hourView;
  // private var minutesView;
  // private var dateView;
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

    mIconHeart = WatchUi.loadResource(Rez.Drawables.IconHeart);
    mIconStep = WatchUi.loadResource(Rez.Drawables.IconStep);
    mIconBat = WatchUi.loadResource(Rez.Drawables.IconBat);
    mIconPhone = WatchUi.loadResource(Rez.Drawables.IconPhone);
    mIconWeather = WatchUi.loadResource(Rez.Drawables.IconWeather);
    mIconMountain = WatchUi.loadResource(Rez.Drawables.IconMountain);

    backgroundView.updateSgv(dc, getSafeSgvData());

    // Set default time out to 20 minutes
    valuesGap = 20;

    sugarView.setFont(mFontHuge);
    sugarArrowView.setFont(mFontLarge);

    sugarView.setJustification(
      Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
    );
    sugarArrowView.setJustification(
      Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
    );

    sugarView.setLocation(centerX, centerY - 10);
    // Preserving relative spacing (35% vs 28% -> 7% gap)
    sugarArrowView.setLocation(centerX, centerY - 10 - height * 0.1);
  }

  function onShow() as Void {}

  function onUpdate(dc as Dc) as Void {
    var sgvData = getSafeSgvData();

    var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);

    var date = now.day.format("%02d");
    var month = now.month;
    var dateString = Lang.format("$1$\n$2$", [month, date]);

    var sugar = "--";
    var sugarArrowStr = "x";

    if (app.getWasTempEvent()) {
      backgroundView.updateSgv(dc, sgvData);
    }

    var statusColor = Graphics.COLOR_ORANGE; // Default: Null (Orange)
    var errorCode = null;

    if (sgvData instanceof Toybox.Lang.String) {
      statusColor = Graphics.COLOR_BLUE; // String (Blue)
    } else if (sgvData instanceof Toybox.Lang.Dictionary) {
      statusColor = Graphics.COLOR_PURPLE; // Dict but unknown (Purple)
      if (sgvData.get("error") != null) {
        statusColor = Graphics.COLOR_RED; // Error (Red)
        errorCode = sgvData.get("error");
      } else if (sgvData.get("bg") != null) {
        statusColor = Graphics.COLOR_GREEN; // Success (Green)

        // Process Data ONLY if valid "bg" exists
        if (sgvData.size() != 0) {
          var curr_time = Time.now().value().toLong(); // Seconds
          var dataChanged = Storage.getValue("dataChanged");
          if (dataChanged == null) {
            dataChanged = 0;
          }
          var time_diff = curr_time - dataChanged;
          var trashhold = valuesGap * 60; // Convert min to sec

          var dataDict = sgvData as Dictionary;
          var bg_info = dataDict.get("bg") as Dictionary;
          var arrow = bg_info.get("trend") as String;

          var isStale = bg_info.get("isStale");
          var isRemoteStale = false;

          if (time_diff > trashhold) {
            isRemoteStale = true;
          }

          if (isStale != null && isStale instanceof Toybox.Lang.Boolean) {
            isRemoteStale = isStale;
          }
          // if (time_diff < trashhold && !isRemoteStale) {
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
  }

  function drawTimeDateHR(dc, x, y, statusColor, errorCode) {
    // Draw Traffic Light
    dc.setColor(statusColor, Graphics.COLOR_TRANSPARENT);
    // dc.fillCircle(x, y + 10, 5);

    // Draw Error Code if present
    if (errorCode != null) {
      dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
      dc.drawText(
        x + 10,
        y + 10,
        mFontTiny,
        errorCode.toString(),
        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
      );
    }
    var now = System.getClockTime();
    var date = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

    // Weather (Top, Above Time)
    var tempStr = "--";
    if (Toybox has :Weather) {
      var cond = Weather.getCurrentConditions();
      if (cond != null && cond.temperature != null) {
        tempStr = cond.temperature.format("%d") + "°";
      }
    }
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    if (mIconWeather != null) {
      dc.drawBitmap(x - 30, y - 130, mIconWeather);
    }
    dc.drawText(
      x + 10,
      y - 115,
      mFontSmall,
      tempStr,
      Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
    );

    // Time (Top Center)
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
      x - 11,
      y - 106,
      mFontHuge,
      timeString,
      Graphics.TEXT_JUSTIFY_CENTER
    );
    dc.drawText(
      x + 50,
      y - 73,
      mFontTiny,
      secString,
      Graphics.TEXT_JUSTIFY_LEFT
    ); // Small seconds

    if (!is24Hour) {
      dc.drawText(x + 50, y - 93, mFontTiny, amPm, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Date (Bottom)
    var dateString = Lang.format("$1$/$2$", [
      date.day.format("%02d"),
      date.month.format("%02d"),
    ]);
    var dayOfWeek = getDayOfWeek(date.day_of_week);
    var fullDateStr = Lang.format("$1$ $2$", [dayOfWeek, dateString]);
    dc.drawText(
      x,
      y + 70,
      mFontSmall,
      fullDateStr,
      Graphics.TEXT_JUSTIFY_CENTER
    );

    // Draw 4 Quadrant Arcs & Icons & Values
    drawQuadArcs(dc, width, height);

    // HR (Bottom)
    drawHeartRate(dc, x, y + 120);
  }

  // --- Arcs & Icons ---
  function drawQuadArcs(dc, w, h) {
    var cx = w / 2;
    var cy = h / 2;
    // Adjust radius to fit screen - Fenix 8 51mm is large, but check relative size
    var r = w / 2 - 8;
    var thick = 8;

    // 1. Top Left: Steps (Yellow)
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
      cx,
      cy,
      r,
      thick,
      175,
      135,
      stepPct,
      Graphics.COLOR_YELLOW,
      Graphics.ARC_CLOCKWISE
    );
    if (mIconStep != null) {
      dc.drawBitmap(cx - 120, cy - 30, mIconStep);
    }
    drawValue(
      dc,
      cx - 110,
      cy - 45,
      steps.toString(),
      Graphics.TEXT_JUSTIFY_LEFT
    );

    // 2. Top Right: Altitude or Depth (Dark Blue)
    var dBlue = 0x00008b;
    var valStr = "0";
    var pct = 0.0;
    var isDepth = false;

    // Check for Depth first
    var actInfo = Activity.getActivityInfo();
    if (actInfo has :currentDepth && actInfo.currentDepth != null) {
      var d = actInfo.currentDepth;

      // Sanity check: Depth > 0 and < 150m.
      // Also check if d == altitude (leakage).
      var safetyAlt = 0;
      if (actInfo has :altitude && actInfo.altitude != null) {
        safetyAlt = actInfo.altitude;
      }

      // If d is suspiciously close to altitude (and altitude > 0), ignore depth.
      var isLeakage = safetyAlt > 0 && (d - safetyAlt).abs() < 1.0;

      if (d > 0 && d < 150 && !isLeakage) {
        isDepth = true;
        // Depth Logic: 0 to 10m
        // 100% is 10m
        pct = d / 10.0;
        valStr = d.format("%.1f");

        // Fill Clockwise (Top to Bottom)
        drawSegment(
          dc,
          cx,
          cy,
          r,
          thick,
          45,
          5,
          pct,
          dBlue,
          Graphics.ARC_CLOCKWISE
        );
      }
    }

    if (!isDepth) {
      // Altitude Logic (Default)
      var alt = 0;
      if (actInfo has :altitude && actInfo.altitude != null) {
        alt = actInfo.altitude;
      }
      // Note: alt defaults to 0 if null.
      pct = alt / 1000.0;
      valStr = alt.format("%d");

      // Counter-Clockwise (Bottom 5 -> Top 45)
      drawSegment(
        dc,
        cx,
        cy,
        r,
        thick,
        5,
        45,
        pct,
        dBlue,
        Graphics.ARC_COUNTER_CLOCKWISE
      );
    }

    if (mIconMountain != null) {
      dc.drawBitmap(cx + 90, cy - 30, mIconMountain);
    }

    drawValue(dc, cx + 110, cy - 45, valStr, Graphics.TEXT_JUSTIFY_RIGHT);

    // 3. Bottom Right: Watch Bat (Green)
    var stats = System.getSystemStats();
    var wbPct = stats.battery / 100.0;
    drawSegment(
      dc,
      cx,
      cy,
      r,
      thick,
      315,
      355,
      wbPct,
      Graphics.COLOR_GREEN,
      Graphics.ARC_COUNTER_CLOCKWISE
    );
    if (mIconBat != null) {
      dc.drawBitmap(cx + 95, cy + 5, mIconBat);
    }
    drawValue(
      dc,
      cx + 110,
      cy + 45,
      stats.battery.format("%d"),
      Graphics.TEXT_JUSTIFY_RIGHT
    );

    // 4. Bottom Left: Phone Bat (Light Blue)
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
      cx,
      cy,
      r,
      thick,
      225,
      185,
      pbPct,
      lBlue,
      Graphics.ARC_CLOCKWISE
    );
    if (mIconPhone != null) {
      dc.drawBitmap(cx - 123, cy + 7, mIconPhone);
    }
    drawValue(
      dc,
      cx - 110,
      cy + 45,
      pbVal.format("%d"),
      Graphics.TEXT_JUSTIFY_LEFT
    );
  }

  function drawSegment(
    dc,
    cx,
    cy,
    r,
    thick,
    startDeg,
    endDeg,
    pct,
    color,
    direction
  ) {
    // Strict Clamping
    if (pct < 0.0) {
      pct = 0.0;
    }
    if (pct > 1.0) {
      pct = 1.0;
    }

    dc.setPenWidth(thick);

    // Background (Dark)
    dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
    // Cast to Number/Integer
    var s = startDeg.toNumber();
    var e = endDeg.toNumber();
    // Default to CCW if direction is null? But we will pass it.
    dc.drawArc(cx, cy, r, direction, s, e);

    // Only draw fill if meaningful
    if (pct > 0.01) {
      var range = e - s; // Works for both directions: 45-5 = 40 (CCW) or 5-45 = -40 (CW, if s=45 e=5? Wait. )
      // Logic check:
      // If CCW: 5 to 45. range = 40. fillEnd = 5 + 40*pct. e.g. 25. drawArc(5, 25).
      // If CW: 45 to 5. range = 5 - 45 = -40. fillEnd = 45 + (-40)*pct. e.g. 25. drawArc(45, 25). Correct?
      // Garmin drawArc(s, e) direction:
      // CCW: Draws from s to e increasing angle.
      // CW: Draws from s to e decreasing angle?

      // Wait. If I want 45 to 5 Clockwise.
      // 45 deg = Top Right Diag. 5 deg = Right Horizontal (approx).
      // Clockwise goes 45 -> 40 -> ... -> 5.
      // So s=45, e=5.

      // My existing code:
      // var range = e - s;

      var fillEnd = s + range * pct;
      var fe = fillEnd.toNumber();

      // Clamp?
      // If range > 0 (increasing): fe > e clamp.
      // If range < 0 (decreasing): fe < e clamp?
      // Need smart clamp.

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

  function drawIcon(dc, x, y, type) {
    dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
    dc.setPenWidth(2);

    if (type.equals("mountain")) {
      dc.drawLine(x - 6, y + 5, x, y - 6);
      dc.drawLine(x, y - 6, x + 6, y + 5);
      dc.drawLine(x + 6, y + 5, x - 6, y + 5);
    }
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
      dc.drawBitmap(x - 25, y - 10, mIconHeart);
    }
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    dc.drawText(
      x + 10,
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
    var isDebug = false;
    // isDebug = true;
    var data = isDebug ? debugJson() : app.getSgvData();
    return data;
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
    // Hardcoded minimal sample from the python script for fallback
    return {
      "bg" => {
        "trend" => "Flat",
        "val" => "10.2",
        "isStale" => false,
        "time" => Time.now().value().toLong() * 1000,
      },
      "status" => { "bat" => 78 },
      "graph" => {
        "lines" => [
          {
            "name" => "high",
            "points" => [
              [58940512, 10.1],
              [58940508, 10.2],
              [58940504, 10.6],
              [58940500, 11.1],
            ],
          },
          {
            "name" => "inRange",
            "points" => [
              [58940472, 9.6],
              [58940468, 9.1],
              [58940464, 8.8],
              [58940460, 8.8],
              [58940456, 8.9],
            ],
          },
          { "name" => "lineLow", "points" => [[58940032, 3.9]] },
          { "name" => "lineHigh", "points" => [[58940032, 10.0]] },
        ],
      },
    };
  }

  function onHide() as Void {}

  function onExitSleep() as Void {}

  function onEnterSleep() as Void {}

  function onPartialUpdate(dc as Dc) as Void {
    var now = System.getClockTime();
    var secString = now.sec.format("%02d");

    // Coordinates matching drawTimeDateHR
    // x component: centerX + 40
    // y component: centerY - 63
    var x = centerX + 50;
    var y = centerY - 73;

    // Approximate size for 2 digits in Tiny font
    // Assuming Tiny font height is around 25-30px and width ~20-25px
    // We'll give it a generous box to avoid clipping
    var width = 30;
    var height = 25;

    // Adjust y to top-left of the text (TEXT_JUSTIFY_LEFT means x is left edge)
    // TEXT_JUSTIFY_VCENTER means y is center.
    // So top-left of clip rect should be around y - height/2

    // Let's refine clip rect based on DrawText usage:
    // dc.drawText(x, y, mFontTiny, secString, Graphics.TEXT_JUSTIFY_LEFT);
    // Note: drawTimeDateHR used TEXT_JUSTIFY_LEFT.
    // But verify: drawTimeDateHR uses TEXT_JUSTIFY_LEFT for seconds.
    // wait, drawTimeDateHR didn't specify VCENTER for seconds?
    // Let's check line 217 in previous view_file output.
    /*
    212:     dc.drawText(
    213:       x + 40,
    214:       y - 63,
    215:       mFontTiny,
    216:       secString,
    217:       Graphics.TEXT_JUSTIFY_LEFT
    218:     );
    */
    // It is just LEFT. Default vertical alignment is TOP.
    // So (x, y-63) is the Top-Left corner of value.

    dc.setClip(x, y, width, height);
    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
    dc.clear();

    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    dc.drawText(x, y, mFontTiny, secString, Graphics.TEXT_JUSTIFY_LEFT);

    dc.clearClip();
  }
}
