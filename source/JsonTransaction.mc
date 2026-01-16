using Toybox.Background;
using Toybox.System as Sys;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.Application;
import Toybox.Communications;

(:background)
class JsonTransaction extends Toybox.System.ServiceDelegate {
  function initialize() {
    Sys.ServiceDelegate.initialize();
  }

  function onTemporalEvent() {
    makeRequest("http://127.0.0.1:29863/info.json");
  }

  function onReceive(
    responseCode as Number,
    data as Null or Dictionary or String
  ) as Void {
    if (responseCode == 200 && data instanceof Toybox.Lang.String) {
      try {
        // Extract "bg" scope first
        var bgScope = ManualParser.extractScope(data, "bg");
        var bgVal = null;
        var trend = null;
        var delta = null;
        var time = null;
        var isStale = null;

        if (bgScope != null) {
          bgVal = ManualParser.extractString(bgScope, "val", "\"");
          trend = ManualParser.extractString(bgScope, "trend", "\"");
          delta = ManualParser.extractString(bgScope, "delta", "\"");

          // FIX: Manually extract time string and truncate ms -> seconds
          // to avoid 32-bit integer overflow on the watch.
          time = extractTimeAsSeconds(bgScope);

          // "isStale":false
          isStale = ManualParser.extractPrimitive(bgScope, "isStale");
        }

        // "bat":78  - Scoped to "status"
        var statusScope = ManualParser.extractScope(data, "status");
        var bat = null;
        if (statusScope != null) {
          bat = ManualParser.extractPrimitive(statusScope, "bat");
        }
        var isMgdl = ManualParser.extractPrimitive(data, "isMgdl");

        // Extract Graph Points
        var graphPoints = ManualParser.extractMergedGraphPoints(data, 60);
        var lineLow = ManualParser.extractLineValue(data, "lineLow");
        var lineHigh = ManualParser.extractLineValue(data, "lineHigh");

        // Construct Dictionary
        var dict = {
          "bg" => {
            "val" => bgVal,
            "trend" => trend,
            "delta" => delta,
            "time" => time, // This is now UNIX SECONDS (Number)
            "isStale" => isStale,
          },
          "status" => {
            "bat" => bat,
            "isMgdl" => isMgdl,
          },
          "graph" => {
            "lines" => [
              { "name" => "inRange", "points" => graphPoints },
              { "name" => "lineLow", "points" => [[0, lineLow]] },
              { "name" => "lineHigh", "points" => [[0, lineHigh]] },
            ],
          },
        };
        Background.exit(dict);
      } catch (ex) {
        System.println("Parsing Error: " + ex.getErrorMessage());
        Background.exit({ "error" => 999 });
      }
    } else {
      System.println("Response: " + responseCode);
      Background.exit({ "error" => responseCode });
    }
  }

  // New helper to bypass 32-bit overflow
  function extractTimeAsSeconds(jsonString) {
    var key = "\"time\"";
    var idx = jsonString.find(key);
    if (idx == null) {
      return null;
    }

    // Start searching after "time"
    var start = idx + key.length();
    var valStr = "";
    var foundDigit = false;

    // Search a reasonable window for the value
    var limit = start + 30;
    if (limit > jsonString.length()) {
      limit = jsonString.length();
    }

    for (var i = start; i < limit; i++) {
      var char = jsonString.substring(i, i + 1);
      var isDigit = isDigit(char);

      if (!foundDigit) {
        // Skip until we find a digit (skips ':', space, etc.)
        if (isDigit) {
          foundDigit = true;
          valStr = valStr + char;
        }
      } else {
        // We are inside the number
        if (isDigit) {
          valStr = valStr + char;
        } else {
          // Hit a non-digit (comma, closing brace, space), stop
          break;
        }
      }
    }

    // valStr should be the full timestamp string.
    // If it's Milliseconds (usually 13 digits for current years), we truncate 3.
    // If it's Seconds (usually 10 digits), we keep it as is.
    // Current Unix Time (2026) is ~1768xxxxxx (10 digits) or ~1768xxxxxxxxx (13 digits)

    if (valStr.length() >= 13) {
      valStr = valStr.substring(0, valStr.length() - 3);
    }

    // Now safely convert to Number (Seconds fit in 32-bit signed int)
    if (valStr.length() > 0) {
      return valStr.toLong();
    }
    return null;
  }

  function isDigit(char) {
    // "0" is 48, "9" is 57
    var valid = "0123456789";
    return valid.find(char) != null;
  }

  function makeRequest(url) as Void {
    var params = {
      "graph" => "1",
    };
    var options = {
      :method => Communications.HTTP_REQUEST_METHOD_GET,
      :headers => {},
      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN,
    };
    var responseCallback = method(:onReceive);
    Communications.makeWebRequest(url, params, options, responseCallback);
  }
}
