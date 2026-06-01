import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class Background extends WatchUi.Drawable {
  private var width as Number?;
  private var height as Number?;

  var graphPoints = [];
  var highThreshold = 10.0;
  var lowThreshold = 3.9;

  var app;
  var mGraphColor = Graphics.COLOR_WHITE;

  function initialize(params as Dictionary) {
    Drawable.initialize(params);

    app = Application.getApp();
  }

  function updateSgv(dc as Dc, sgvData as Dictionary?) as Void {
    width = dc.getWidth();
    height = dc.getHeight();

    // New Graph Dimensions
    // Width: Reduced by additional 10% (0.68 * 0.9 = ~0.61)
    var contentWidth = width * 0.61;
    // Height: Expanded to ~36% (from 18%) to double the gap between lines
    var contentHeight = height * 0.36;

    // Store in member vars
    // graphWidth = contentWidth.toNumber();
    // graphHeight = contentHeight.toNumber();
    // graphLeft = ((width - contentWidth) / 2).toNumber();

    // StartY: Adjusted to keep the Red Line (4mmol) at the same visual position
    // keeping red line fixed while expanding height upwards.
    // Shift up by (0.36 - 0.18) * 0.875 * height = 0.18 * 0.875 * height = 0.1575 * height
    // graphTop = (height / 2 + 15 - height * 0.1575).toNumber();

    // Extract Graph Data
    graphPoints = new [0];

    if (sgvData instanceof Toybox.Lang.Dictionary) {
      var graph = sgvData.get("graph") as Dictionary;
      if (graph != null) {
        var lines = graph.get("lines") as Array<Dictionary>;
        if (lines != null && lines instanceof Toybox.Lang.Array) {
          for (var i = 0; i < lines.size(); i++) {
            var line = lines[i];
            var name = line.get("name") as String;
            var points = line.get("points") as Array<Array<Number> >;

            if (
              name.equals("inRange") ||
              name.equals("high") ||
              name.equals("low")
            ) {
              if (points != null) {
                graphPoints.addAll(points);
              }
            } else if (
              name.equals("lineHigh") &&
              points != null &&
              points.size() > 0
            ) {
              try {
                highThreshold = points[0][1].toFloat();
              } catch (e) {
                highThreshold = 10.0;
              }
            } else if (
              name.equals("lineLow") &&
              points != null &&
              points.size() > 0
            ) {
              try {
                lowThreshold = points[0][1].toFloat();
              } catch (e) {
                lowThreshold = 3.9;
              }
            }
          }
        }
      }
    }
  }

  function draw(dc as Dc) as Void {
    var width = dc.getWidth();
    var height = dc.getHeight();

    var graphWidth = width * 0.5;
    var graphHeight = height * 0.15;
    var graphLeft = (width - graphWidth) / 2;
    var graphTop = height / 2 + 20; // Position below text
    var graphBottom = graphTop + graphHeight;

    if (
      graphWidth == null ||
      graphHeight == null ||
      graphLeft == null ||
      graphTop == null
    ) {
      return;
    }

    // Need at least 2 points to draw a meaningful graph;
    // also guards against division by zero in stepX calculation below.
    if (graphPoints.size() < 2) {
      return;
    }

    // 1. Determine Y-Axis Range (Min/Max Value)
    var minVal = 999.0;
    var maxVal = -999.0;

    // Include thresholds in range to ensure they are visible
    if (highThreshold != null) {
      if (highThreshold > maxVal) {
        maxVal = highThreshold;
      }
      if (highThreshold < minVal) {
        minVal = highThreshold;
      }
    }
    if (lowThreshold != null) {
      if (lowThreshold > maxVal) {
        maxVal = lowThreshold;
      }
      if (lowThreshold < minVal) {
        minVal = lowThreshold;
      }
    }

    // Include data points
    for (var i = 0; i < graphPoints.size(); i++) {
      var v = graphPoints[i][1].toFloat();
      if (v > maxVal) {
        maxVal = v;
      }
      if (v < minVal) {
        minVal = v;
      }
    }

    // Add some padding
    var range = maxVal - minVal;
    if (range == 0) {
      range = 1;
    }
    // minVal -= range * 0.1;
    // maxVal += range * 0.1;

    // Helper to map Y value to pixel Y
    // Pixel Y = graphBottom - ((val - minVal) / (maxVal - minVal)) * graphHeight

    // 2. Draw Thresholds
    if (highThreshold != null) {
      var yHigh =
        graphBottom -
        ((highThreshold - minVal) / (maxVal - minVal)) * graphHeight;
      dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
      dc.setPenWidth(1);
      dc.drawLine(graphLeft, yHigh, graphLeft + graphWidth, yHigh);
    }

    if (lowThreshold != null) {
      var yLow =
        graphBottom -
        ((lowThreshold - minVal) / (maxVal - minVal)) * graphHeight;
      dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
      dc.setPenWidth(1);
      dc.drawLine(graphLeft, yLow, graphLeft + graphWidth, yLow);
    }

    // 3. Draw Graph Points
    dc.setColor(mGraphColor, Graphics.COLOR_TRANSPARENT);
    dc.setPenWidth(1);

    var numPoints = graphPoints.size();
    var stepX = graphWidth / (numPoints - 1); // Distance between points

    var prevX = -1;
    var prevY = -1;

    // graphPoints is sorted newest-first (index 0 = most recent).
    // We want oldest on the left and newest on the right, so we
    // iterate from the last element down to 0.

    for (var i = numPoints - 1; i >= 0; i--) {
      var val = graphPoints[i][1].toFloat();

      // X coordinate: j runs 0 (leftmost/oldest) to numPoints-1 (rightmost/newest)
      var j = numPoints - 1 - i;
      var x = graphLeft + j * stepX;

      var y = graphBottom - ((val - minVal) / (maxVal - minVal)) * graphHeight;

      // Draw Dot
      dc.fillCircle(x, y, 2);

      // Draw Line to previous
      if (prevX != -1) {
        dc.drawLine(prevX, prevY, x, y);
      }

      prevX = x;
      prevY = y;
    }
  }
}
