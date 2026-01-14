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
        var bgVal = ManualParser.extractString(data, "val", "\"");
        var trend = ManualParser.extractString(data, "trend", "\"");

        // Extract primitive values (Numbers/Booleans)
        // "isStale":false
        var isStale = ManualParser.extractPrimitive(data, "isStale");

        // "bat":78  - Scoped to "status"
        var statusScope = ManualParser.extractScope(data, "status");
        var bat = null;
        if (statusScope != null) {
          bat = ManualParser.extractPrimitive(statusScope, "bat");
        }
        var isMgdl = ManualParser.extractPrimitive(data, "isMgdl");

        // Extract Graph Points (Downsampled, Merged, Sorted)
        // Target 60 points
        var graphPoints = ManualParser.extractMergedGraphPoints(data, 60);
        var lineLow = ManualParser.extractLineValue(data, "lineLow");
        var lineHigh = ManualParser.extractLineValue(data, "lineHigh");

        // Construct Dictionary
        // { "bg": {...}, "status": {...}, "graph": {...} }
        var dict = {
          "bg" => {
            "val" => bgVal,
            "trend" => trend,
            "isStale" => isStale,
          },
          "status" => {
            "bat" => bat,
            "isMgdl" => isMgdl,
          },
          "graph" => {
            // Reconstruct lines structure for View
            "lines" => [
              { "name" => "inRange", "points" => graphPoints },
              // Add lineLow/High as points for compatibility if needed,
              // or View logic handles them?
              // View expects: "lineLow" -> points -> [0][1] as value.
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

  function makeRequest(url) as Void {
    var params = {
      "graph" => "1",
    };

    var options = {
      :method => Communications.HTTP_REQUEST_METHOD_GET,
      :headers => {
        // "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
      },

      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN,
    };

    var responseCallback = method(:onReceive);
    Communications.makeWebRequest(url, params, options, responseCallback);
  }
}
