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

  // Extracts and merges glucose data points from "high", "inRange", and "low"
  // segments only.  "predict" and "treatment" are silently discarded.
  // Returns an Array of [Long ts, Float val] sorted DESCENDING (newest first)
  // so that Background.mc's existing draw loop works unchanged.
  // Downsamples to targetCount points when necessary.
  function extractMergedGraphPoints(buffer, targetCount) {

    var allPoints = [];

    var linesIdx = buffer.find("\"lines\":[");
    if (linesIdx == null || linesIdx < 0) { return []; }

    var pos  = linesIdx + 9;   // position right after the '[' of "lines":[
    var jLen = buffer.length();

    try {
      while (pos < jLen) {

        // ---- 1. find the next segment's  "name":"xxx" ----
        var nameKeyPos = _gsFindFrom(buffer, "\"name\":\"", pos);
        if (nameKeyPos < 0) { break; }

        var nameStart = nameKeyPos + 8;                      // past  "name":"
        var nameEnd   = _gsFindFrom(buffer, "\"", nameStart);
        if (nameEnd < 0) { break; }

        var name = buffer.substring(nameStart, nameEnd);

        // ---- 2. find this segment's  "points":[[ ----
        // Always search forward from nameEnd so we stay inside the current
        // line object and never stray into a later segment.
        var ptKeyPos = _gsFindFrom(buffer, "\"points\":[[", nameEnd);
        if (ptKeyPos < 0) { break; }

        // outerOpen = the '[' that opens the outer array  [[ts,v],...]
        var outerOpen = ptKeyPos + 9;

        // ---- 3. find ']]' that closes THIS segment's points array ----
        // Starting 2 chars past outerOpen skips the inner '[' of the very
        // first pair, preventing a false match on the opening '[['.
        var ptEnd = _gsFindFrom(buffer, "]]", outerOpen + 2);
        if (ptEnd < 0) { break; }

        // ---- 4. collect points only for allowed segment names ----
        if (name.equals("high") || name.equals("inRange") || name.equals("low")) {

          var innerPos = outerOpen + 1;  // skip outer '['; now at first inner '['

          while (innerPos < jLen) {
            var c = buffer.substring(innerPos, innerPos + 1);

            if (c.equals("[")) {
              var closePos = _gsFindFrom(buffer, "]", innerPos + 1);
              if (closePos < 0) { break; }

              var inner = buffer.substring(innerPos + 1, closePos);  // "ts,val"
              var comma = inner.find(",");
              if (comma != null && comma >= 0) {
                var ts  = inner.substring(0, comma).toLong();
                var val = inner.substring(comma + 1, inner.length()).toFloat();
                allPoints.add([ts, val]);
              }
              innerPos = closePos + 1;

            } else if (c.equals("]")) {
              break;   // end of outer array for this segment
            } else {
              innerPos++;
            }
          }
        }
        // "predict", "treatment", "lineLow", "lineHigh", anything else → skip

        // ---- 5. advance past ']]' before searching for next segment ----
        pos = ptEnd + 2;
      }
    } catch (ex) {
      System.println("extractMergedGraphPoints error: " + ex.getErrorMessage());
    }

    if (allPoints.size() == 0) { return []; }

    // Sort DESCENDING by timestamp (newest first — matches Background.mc draw loop).
    var n = allPoints.size();
    for (var i = 0; i < n - 1; i++) {
      var maxIdx = i;
      for (var j = i + 1; j < n; j++) {
        if (allPoints[j][0] > allPoints[maxIdx][0]) {
          maxIdx = j;
        }
      }
      if (maxIdx != i) {
        var tmp          = allPoints[i];
        allPoints[i]     = allPoints[maxIdx];
        allPoints[maxIdx] = tmp;
      }
    }

    if (allPoints.size() <= targetCount) {
      return allPoints;
    }

    // Downsample with 3-point average to suppress isolated-peak artefacts.
    var result = [];
    var step   = (allPoints.size() - 1).toFloat() / (targetCount - 1);
    for (var i = 0; i < targetCount; i++) {
      var idx = (i * step + 0.5).toNumber();
      if (idx < allPoints.size()) {
        var sumVal = allPoints[idx][1].toFloat();
        var cnt    = 1;
        if (idx > 0) {
          sumVal = sumVal + allPoints[idx - 1][1].toFloat();
          cnt    = cnt + 1;
        }
        if (idx < allPoints.size() - 1) {
          sumVal = sumVal + allPoints[idx + 1][1].toFloat();
          cnt    = cnt + 1;
        }
        result.add([allPoints[idx][0], sumVal / cnt.toFloat()]);
      }
    }
    return result;
  }

  // ================================================================
  // Preprocessing pipeline – equivalent to the bash sed/sort/tr
  // pipeline. Call preprocessGlucoseJson() on the raw JSON blob to
  // obtain a simple line-based string, then parse that with normal
  // find/substring instead of a full JSON parser.
  // ================================================================

  // Internal: find 'needle' in 's' starting at absolute index 'from'.
  // Returns absolute index, or -1 if not found.
  function _gsFindFrom(s, needle, from) {
    var sLen = s.length();
    if (from >= sLen) { return -1; }
    var rel = s.substring(from, sLen).find(needle);
    if (rel == null || rel < 0) { return -1; }
    return from + rel;
  }

  // Internal: extract one JSON field value by key from 'section'.
  // Handles quoted strings, numbers, and booleans.
  // Returns the bare value as a String, or "" if not found.
  function _gsExtract(section, key) {
    var needle = "\"" + key + "\":";
    var idx = section.find(needle);
    if (idx == null || idx < 0) { return ""; }
    var pos  = idx + needle.length();
    var sLen = section.length();
    if (pos >= sLen) { return ""; }
    var quoted = section.substring(pos, pos + 1).equals("\"");
    if (quoted) { pos++; }
    var end = pos;
    while (end < sLen) {
      var c = section.substring(end, end + 1);
      if (quoted) {
        if (c.equals("\"")) { break; }
      } else {
        if (c.equals(",") || c.equals("}")) { break; }
      }
      end++;
    }
    if (end <= pos) { return ""; }
    return section.substring(pos, end);
  }

  // Internal: return the JSON object (WITH braces) whose opening
  // matches keyPattern (which must end with '{').
  // e.g. keyPattern = "\"pump\":{"  returns  {"bat":0.0,...}
  // Only correct for flat objects (no nested braces).
  function _gsSection(json, keyPattern) {
    var idx = json.find(keyPattern);
    if (idx == null || idx < 0) { return ""; }
    var start = idx + keyPattern.length() - 1; // position of '{'
    var end   = _gsFindFrom(json, "}", start + 1);
    if (end < 0) { return ""; }
    return json.substring(start, end + 1);
  }

  // Internal: append every [timestamp, value] pair from the "points"
  // array in 'seg' to the parallel arrays ts and vs.
  function _gsExtractDataPoints(seg, ts, vs) {
    var pIdx = seg.find("\"points\":");
    if (pIdx == null || pIdx < 0) { return; }
    var pos    = pIdx + 9;
    var segLen = seg.length();
    // Skip outer '[' of  [[t,v],...]
    if (pos < segLen && seg.substring(pos, pos + 1).equals("[")) { pos++; }
    while (pos < segLen) {
      var c = seg.substring(pos, pos + 1);
      if (c.equals("[")) {
        var end = _gsFindFrom(seg, "]", pos + 1);
        if (end < 0) { break; }
        var inner = seg.substring(pos + 1, end);
        var comma = inner.find(",");
        if (comma != null && comma >= 0) {
          ts.add(inner.substring(0, comma));
          vs.add(inner.substring(comma + 1, inner.length()));
        }
        pos = end + 1;
      } else if (c.equals("]")) {
        break;
      } else {
        pos++;
      }
    }
  }

  // Internal: return the marker points of a lineLow/lineHigh segment
  // as a ready-to-output string:  "[t,v],[t,v]"
  function _gsExtractLineMarker(seg) {
    var pIdx = seg.find("\"points\":");
    if (pIdx == null || pIdx < 0) { return ""; }
    var pos    = pIdx + 9;
    var segLen = seg.length();
    if (pos < segLen && seg.substring(pos, pos + 1).equals("[")) { pos++; }
    var result = "";
    while (pos < segLen) {
      var c = seg.substring(pos, pos + 1);
      if (c.equals("[")) {
        var end = _gsFindFrom(seg, "]", pos + 1);
        if (end < 0) { break; }
        if (!result.equals("")) { result += ","; }
        result += seg.substring(pos, end + 1);
        pos = end + 1;
      } else if (c.equals("]")) {
        break;
      } else {
        pos++;
      }
    }
    return result;
  }

  // PUBLIC: preprocessGlucoseJson(json)
  //
  // Converts the raw CGM JSON string to a simplified line-based format.
  // Merges all data segments (inRange / high / low) and sorts ascending
  // by timestamp.  Call this once on the fetched response, then use
  // plain find/substring to read each field.
  //
  // Output format:
  //   graph:
  //   [timestamp,value]    <- sorted ascending
  //   ...
  //   bg:delta:<v>
  //   isHigh:<v>  isLow:<v>  isStale:<v>  time:<v>  trend:<v>  val:<v>
  //   name:lineLow
  //   points:[t,v],[t,v]
  //   name:lineHigh
  //   points:[t,v],[t,v]
  //   start:<v>
  //   pump:bat:<v>  iob:<v>  reservoir:<v>
  //   status:bat:<v>  isMgdl:<v>  now:<v>
  function preprocessGlucoseJson(json) {
    var timestamps  = [];
    var values      = [];
    var lineLowPts  = "";
    var lineHighPts = "";

    var splitTok = "]},{";
    var splitLen = 4;
    var segStart = 0;
    var jLen     = json.length();

    while (segStart < jLen) {
      var segEnd = _gsFindFrom(json, splitTok, segStart);
      var isLast = (segEnd < 0);
      if (isLast) { segEnd = jLen; }

      var seg = json.substring(segStart, segEnd);

      var llIdx = seg.find("lineLow");
      var lhIdx = seg.find("lineHigh");
      if (llIdx != null && llIdx >= 0) {
        lineLowPts = _gsExtractLineMarker(seg);
      } else if (lhIdx != null && lhIdx >= 0) {
        lineHighPts = _gsExtractLineMarker(seg);
      } else {
        _gsExtractDataPoints(seg, timestamps, values);
      }

      if (isLast) { break; }
      segStart = segEnd + splitLen;
    }

    // Insertion sort ascending by timestamp.
    // Pre-compute Long values to avoid O(n^2) toLong() calls.
    var n      = timestamps.size();
    var tsLong = [];
    for (var i = 0; i < n; i++) {
      tsLong.add(timestamps[i].toLong());
    }
    for (var i = 1; i < n; i++) {
      var ktl = tsLong[i];
      var kt  = timestamps[i];
      var kv  = values[i];
      var j   = i - 1;
      while (j >= 0 && tsLong[j] > ktl) {
        tsLong[j + 1]     = tsLong[j];
        timestamps[j + 1] = timestamps[j];
        values[j + 1]     = values[j];
        j--;
      }
      tsLong[j + 1]     = ktl;
      timestamps[j + 1] = kt;
      values[j + 1]     = kv;
    }

    var out = "graph:\n";
    for (var i = 0; i < n; i++) {
      out += "[" + timestamps[i] + "," + values[i] + "]\n";
    }

    var bg = _gsSection(json, "\"bg\":{");
    if (!bg.equals("")) {
      out += "bg:delta:" + _gsExtract(bg, "delta")   + "\n";
      out += "isHigh:"   + _gsExtract(bg, "isHigh")  + "\n";
      out += "isLow:"    + _gsExtract(bg, "isLow")   + "\n";
      out += "isStale:"  + _gsExtract(bg, "isStale") + "\n";
      out += "time:"     + _gsExtract(bg, "time")    + "\n";
      out += "trend:"    + _gsExtract(bg, "trend")   + "\n";
      out += "val:"      + _gsExtract(bg, "val")     + "\n";
    }

    if (!lineLowPts.equals("")) {
      out += "name:lineLow\npoints:" + lineLowPts + "\n";
    }
    if (!lineHighPts.equals("")) {
      out += "name:lineHigh\npoints:" + lineHighPts + "\n";
    }

    // "start" is unique in the blob - safe to search the full string.
    var startVal = _gsExtract(json, "start");
    if (!startVal.equals("")) { out += "start:" + startVal + "\n"; }

    var pump = _gsSection(json, "\"pump\":{");
    if (!pump.equals("")) {
      out += "pump:bat:"  + _gsExtract(pump, "bat")       + "\n";
      out += "iob:"       + _gsExtract(pump, "iob")       + "\n";
      out += "reservoir:" + _gsExtract(pump, "reservoir") + "\n";
    }

    var status = _gsSection(json, "\"status\":{");
    if (!status.equals("")) {
      out += "status:bat:" + _gsExtract(status, "bat")    + "\n";
      out += "isMgdl:"     + _gsExtract(status, "isMgdl") + "\n";
      out += "now:"        + _gsExtract(status, "now")    + "\n";
    }

    return out;
  }

}