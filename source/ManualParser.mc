using Toybox.System;
using Toybox.Lang;
using Toybox.StringUtil;

(:background)
module ManualParser {
  // Helper to find a value between two delimiters
  // Returns the String value or null if not found
  function extractString(buffer, key, endChar) {
    var keyStr = "\"" + key + "\":\""; // Looks for "key":"
    var start = buffer.find(keyStr);

    if (start == null) {
      return null;
    }

    start += keyStr.length();

    // Safety check
    if (start >= buffer.length()) {
      return null;
    }

    var content = buffer.substring(start, buffer.length());
    var end = content.find(endChar);

    if (end == null) {
      return null;
    }

    return content.substring(0, end);
  }

  // Extract a specific object scope content (e.g. content inside "status":{ ... })
  function extractScope(buffer, key) {
    var keyStr = "\"" + key + "\":{";
    var start = buffer.find(keyStr);

    if (start == null) {
      return null;
    }

    start += keyStr.length(); // Point to content after "key":{

    if (start >= buffer.length()) {
      return null;
    }

    var content = buffer.substring(start, buffer.length());

    // Find matching brace via simple search for "}"
    // WARNING: This assumes no nested objects in the scope we are extracting.
    // For "status":{...}, it works.
    var end = content.find("}");
    if (end == null) {
      return null;
    }

    return content.substring(0, end);
  }

  // Helper to find a number (no quotes around the value, or boolean)
  // Looks for "key":123 or "key":false
  function extractPrimitive(buffer, key) {
    var keyStr = "\"" + key + "\":";
    var start = buffer.find(keyStr);

    if (start == null) {
      return null;
    }

    start += keyStr.length();

    // Safety check
    if (start >= buffer.length()) {
      return null;
    }

    // Look for the next comma or closing brace
    var content = buffer.substring(start, buffer.length());
    var endComma = content.find(",");
    var endBrace = content.find("}");

    var end = endComma;
    // If brace is closer than comma (end of object), use brace
    if (end == null || (endBrace != null && endBrace < end)) {
      end = endBrace;
    }

    if (end == null) {
      return null;
    }

    var valStr = content.substring(0, end);

    // Check for boolean
    if (valStr.equals("true")) {
      return true;
    }
    if (valStr.equals("false")) {
      return false;
    }
    if (valStr.equals("null")) {
      return null;
    }

    // Try Number (Integer)
    if (valStr.find(".") == null) {
      return valStr.toNumber();
    }
    // Try Float
    return valStr.toFloat();
  }

  // Helper to extract Long (64-bit) for timestamps
  function extractLong(buffer, key) {
    var keyStr = "\"" + key + "\":";
    var start = buffer.find(keyStr);

    if (start == null) {
      return null;
    }

    start += keyStr.length();

    if (start >= buffer.length()) {
      return null;
    }

    var content = buffer.substring(start, buffer.length());
    var endComma = content.find(",");
    var endBrace = content.find("}");

    var end = endComma;
    if (end == null || (endBrace != null && endBrace < end)) {
      end = endBrace;
    }

    if (end == null) {
      return null;
    }

    var valStr = content.substring(0, end);
    return valStr.toLong();
  }

  // Specialized function to extract simple line value (like lineLow/lineHigh)
  // Returns the Float value from the first point [[x, VAL], ...]
  function extractLineValue(buffer, lineName) {
    var nameKey = "\"name\":\"" + lineName + "\"";
    var nameIndex = buffer.find(nameKey);
    if (nameIndex == null) {
      return null;
    }

    var truncBuffer = buffer.substring(nameIndex, buffer.length());
    var pointsStart = truncBuffer.find("\"points\":[[");
    if (pointsStart == null) {
      return null;
    }

    // 11 is length of "points":[[
    if (pointsStart + 11 >= truncBuffer.length()) {
      return null;
    }

    // Extract first point value: [[123, 3.9], ...]
    // pointsStart points to "points":[[
    // We want content after [[
    var dataRegion = truncBuffer.substring(
      pointsStart + 11,
      truncBuffer.length()
    );
    var firstPointEnd = dataRegion.find("]");
    if (firstPointEnd == null) {
      return null;
    }

    var valStr = dataRegion.substring(0, firstPointEnd); // "123, 3.9"
    var comma = valStr.find(",");
    if (comma == null) {
      return null;
    }

    return valStr.substring(comma + 1, valStr.length()).toFloat();
  }

  // Extract and Merge all graph lines (excluding threshold lines)
  // Sorts points by Timestamp Ascending
  function extractMergedGraphPoints(buffer, targetCount) {
    var linesKey = "\"lines\":[";
    var start = buffer.find(linesKey);
    if (start == null) {
      return [];
    }

    // Limit buffer to lines array
    var subBuf = buffer.substring(start, buffer.length());
    var allPoints = [];

    // Crude iterator over objects in array
    while (true) {
      var nameKey = "\"name\":\"";
      var nameIdx = subBuf.find(nameKey);
      if (nameIdx == null) {
        break;
      }

      // Extract name
      var nameStart = nameIdx + nameKey.length();
      if (nameStart >= subBuf.length()) {
        break;
      }

      var afterName = subBuf.substring(nameStart, subBuf.length());
      var quoteEnd = afterName.find("\"");
      if (quoteEnd == null) {
        break;
      }

      var lineName = afterName.substring(0, quoteEnd); // e.g. "high", "inRange", "lineLow"

      // Move subBuf to start of this line's points
      var pointsKey = "\"points\":[[";
      var pointsIdx = afterName.find(pointsKey);

      if (pointsIdx != null) {
        // Check if it's a valid line (not threshold)
        if (!lineName.equals("lineLow") && !lineName.equals("lineHigh")) {
          var pBuf = afterName.substring(pointsIdx, afterName.length()); // starts at "points":[[

          // Reuse logic
          var closeArr = pBuf.find("]]");
          if (closeArr != null) {
            var dataContent = pBuf.substring(10, closeArr + 1); // content inside [[...]]

            var parseP = dataContent;
            while (true) {
              var ptEnd = parseP.find("]");
              if (ptEnd == null) {
                break;
              }

              var ptStr = parseP.substring(0, ptEnd);
              // Clean
              var realStart = 0;
              var br = ptStr.find("[");
              if (br != null) {
                realStart = br + 1;
              }
              var cleanPt = ptStr.substring(realStart, ptStr.length());
              var comma = cleanPt.find(",");
              if (comma != null) {
                var ts = cleanPt.substring(0, comma).toLong();
                var val = cleanPt
                  .substring(comma + 1, cleanPt.length())
                  .toFloat();
                allPoints.add([ts, val]);
              }

              // Advance
              if (ptEnd + 1 >= parseP.length()) {
                break;
              }
              parseP = parseP.substring(ptEnd + 1, parseP.length());
            }
          }
        }
      }

      // Advance subBuf past this name to find next
      // Use quoteEnd + 1 to move past the closing quote of name
      subBuf = afterName.substring(quoteEnd + 1, afterName.length());
    }

    if (allPoints.size() == 0) {
      return [];
    }

    // Sort Descending (Newest First) - Selection Sort
    for (var i = 0; i < allPoints.size() - 1; i++) {
      var maxIdx = i; // Renamed to maxIdx for clarity
      for (var j = i + 1; j < allPoints.size(); j++) {
        // Compare timestamps (index 0)
        // Using > ensures the largest (most recent) time moves to the front
        if (allPoints[j][0] > allPoints[maxIdx][0]) {
          maxIdx = j;
        }
      }
      if (maxIdx != i) {
        var temp = allPoints[i];
        allPoints[i] = allPoints[maxIdx];
        allPoints[maxIdx] = temp;
      }
    }

    // Downsample
    if (allPoints.size() <= targetCount) {
      return allPoints;
    }

    var result = [];

    // Use (size - 1) to ensure the final index can reach the very last element
    var step = (allPoints.size() - 1).toFloat() / (targetCount - 1);

    for (var i = 0; i < targetCount; i++) {
      var idx = (i * step + 0.5).toNumber(); // Adding 0.5 helps with rounding to nearest index
      if (idx < allPoints.size()) {
        result.add(allPoints[idx]);
      }
    }

    return result;
  }
}
