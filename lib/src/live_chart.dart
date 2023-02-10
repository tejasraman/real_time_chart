import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'chart_display.dart';
import 'point.dart';

class RealTimeGraph extends StatefulWidget {
  const RealTimeGraph({
    this.updateDelay = const Duration(milliseconds: 50),
    this.displayMode = ChartDisplay.line,
    this.displayYAxisValues = true,
    this.displayYAxisLines = true,
    this.axisColor = Colors.black87,
    this.graphColor = Colors.black45,
    this.pointsSpacing = 3.0,
    this.graphStroke = 1,
    this.axisStroke = 1.0,
    this.axisTextBuilder,
    required this.stream,
    this.minValue = 0,
    this.speed = 1,
    Key? key,
    this.supportNegativeValuesDisplay = false,
  }) : super(key: key);

  // Callback to build custom Y-axis text.
  final Widget Function(double)? axisTextBuilder;

  // Enum to display chart as line or points.
  final ChartDisplay displayMode;

  // Flag to display Y-axis values or not.
  final bool displayYAxisValues;

  // Flag to display the X-Y-axis lines or not.
  final bool displayYAxisLines;

  // Flag to display the x-Axis in the middle of the chart
  // And support the display of negative values < 0
  final bool supportNegativeValuesDisplay;

  // The stream to listen to for new data.
  final Stream<double> stream;

  // The frequency of updating the chart.
  final Duration updateDelay;

  // The spacing between points in the chart.
  final double pointsSpacing;

  // The stroke width of the Y-axis line.
  final double axisStroke;

  // The stroke width of the graph line.
  final double graphStroke;

  // The color of the graph.
  final Color graphColor;

  // The color of the Y-axis line.
  final Color axisColor;

  // The minimum value of the Y-axis.
  final double minValue;

  // The speed at which the chart updates.
  final int speed;

  @override
  RealTimeGraphState createState() => RealTimeGraphState();
}

class RealTimeGraphState extends State<RealTimeGraph>
    with TickerProviderStateMixin {
  // Subscription to the stream provided in the constructor
  StreamSubscription<double>? streamSubscription;

  // List of data points to be displayed on the graph
  List<Point<double>> _data = [];

  // Timer to periodically update the data for visualization
  Timer? timer;

  // Width of the canvas for the graph
  double canvasWidth = 1000;

  @override
  void initState() {
    super.initState();

    // Subscribe to the stream provided in the constructor
    streamSubscription = widget.stream.listen(_streamListener);

    // Start a periodic timer to update the data for visualization
    timer = Timer.periodic(widget.updateDelay, (_) {
      // delete data that is no longer displayed on the graph.
      _data.removeWhere((element) => element.x < canvasWidth * -1.5);

      // Clone the data to avoid modifying the original list while iterating
      List<Point<double>> data = _data.map((e) => e).toList();

      // Increment the x value of each data point
      for (var element in data) {
        element.x = element.x - widget.speed;
      }

      // Trigger a rebuild with the updated data
      setState(() {
        _data = data;
      });
    });
  }

  // Maximum value of the y-axis of the graph
  double get maxValue {
    if (_data.isEmpty) {
      return 0;
    }

    final maxValue = _data.map((point) => point.y).reduce(max);
    final minValue = _data.map((point) => point.y).reduce(min);

    if (widget.supportNegativeValuesDisplay) {
      if (maxValue > minValue.abs()) {
        return maxValue;
      } else {
        return minValue.abs();
      }
    }

    return maxValue;
  }

  // Minimum value of the y-axis of the graph
  double get minValue {
    if (_data.isEmpty) {
      return 0;
    }

    final maxValue = _data.map((point) => point.y).reduce(max);
    final minValue = _data.map((point) => point.y).reduce(min);

    if (widget.supportNegativeValuesDisplay) {
      if (maxValue > minValue.abs()) {
        return maxValue * -1;
      } else {
        return minValue;
      }
    }

    return widget.minValue;
  }

  // Median value of the y-axis of the graph
  double get medianValue => (maxValue + minValue) / 2;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        // Display the values of the y-axis if the option is enabled
        if (widget.displayYAxisValues)
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Call the custom axis text builder if provided
              // or use the default text builder otherwise
              widget.axisTextBuilder?.call(maxValue) ?? textBuilder(maxValue),
              widget.axisTextBuilder?.call(medianValue) ??
                  textBuilder(medianValue),
              widget.axisTextBuilder?.call(minValue) ?? textBuilder(minValue),
            ],
          ),
        // Display the y-axis line
        if (widget.displayYAxisLines)
          Container(
            color: widget.axisColor,
            width: widget.axisStroke,
            height: double.maxFinite,
          ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (!constraints.maxWidth.isFinite ||
                        !constraints.maxHeight.isFinite) {
                      return const SizedBox.shrink();
                    }

                    canvasWidth = constraints.maxWidth;

                    return SizedBox(
                      key: Key(
                          '${constraints.maxWidth}${constraints.maxHeight}'),
                      height: constraints.maxHeight,
                      width: constraints.maxWidth,
                      child: ClipRRect(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            size: Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            ),
                            painter: widget.displayMode == ChartDisplay.points
                                ? _PointGraphPainter(
                                    data: _data,
                                    pointsSpacing: widget.pointsSpacing,
                                    graphStroke: widget.graphStroke,
                                    color: widget.graphColor,
                                    supportNegativeValuesDisplay:
                                        widget.supportNegativeValuesDisplay,
                                  )
                                : _LineGraphPainter(
                                    data: _data,
                                    graphStroke: widget.graphStroke,
                                    color: widget.graphColor,
                                    supportNegativeValuesDisplay:
                                        widget.supportNegativeValuesDisplay,
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (widget.displayYAxisLines)
                Align(
                  alignment: widget.supportNegativeValuesDisplay
                      ? Alignment.center
                      : Alignment.bottomCenter,
                  child: Container(
                    color: widget.axisColor,
                    height: widget.axisStroke,
                    width: double.maxFinite,
                  ),
                )
            ],
          ),
        ),
      ],
    );
  }

  Widget textBuilder(double value) {
    return Text(
      value.toString(),
      style: const TextStyle(color: Colors.black),
    );
  }

  void _streamListener(double data) {
    // Insert the new data point in the beginning of the list
    _data.insert(0, Point(0, data));
  }

  @override
  void dispose() {
    // Clean up resources when the widget is removed from the tree
    streamSubscription?.cancel();
    timer?.cancel();
    super.dispose();
  }
}

class _PointGraphPainter extends CustomPainter {
  _PointGraphPainter({
    required this.data,
    required this.pointsSpacing,
    required this.graphStroke,
    required this.color,
    required this.supportNegativeValuesDisplay,
  });

  // List of data points to be plotted on the graph
  final List<Point<double>> data;

  // Spacing between consecutive data points on the graph
  final double pointsSpacing;

  // Stroke width of the graph
  final double graphStroke;

  // Color of the graph
  final Color color;

  // Whether to support display of negative values on the graph
  final bool supportNegativeValuesDisplay;

  @override
  void paint(Canvas canvas, Size size) {
    // Paint object used to draw the graph
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = graphStroke
      ..color = color;

    // If the data is not empty, calculate the maximum y value and the y scaling factor
    if (data.isNotEmpty) {
      // Calculate the maximum and minimum y values in the data
      final maxY = data.map((point) => point.y).reduce(max);
      final minY = data.map((point) => point.y).reduce(min);

      // Calculate the scaling factor for the y values
      double yScale = 1;
      final yTranslation =
          supportNegativeValuesDisplay ? size.height / 2 : size.height;
      if (maxY.abs() > yTranslation) {
        yScale = yTranslation / maxY.abs();
      }

      if (minY.abs() > yTranslation) {
        final scale = yTranslation / minY.abs();
        if (maxY.abs() < minY.abs()) {
          yScale = scale;
        }
      }

      // Iterate over the data points and draw them on the canvas
      for (int i = 0; i < data.length - 1; i++) {
        double y1 = data[i].y * yScale;
        double x1 = data[i].x + size.width;
        double y2 = data[i + 1].y * yScale;
        double x2 = data[i + 1].x + size.width;
        double yDiff = (y2 - y1).abs();
        double xDiff = (x2 - x1).abs();

        final distance = sqrt(pow(xDiff, 2) + pow(yDiff, 2));
        // If the difference in y values or x values is large, add intermediate points
        if (distance >= pointsSpacing) {
          int numOfIntermediatePoints = (distance / pointsSpacing).round();
          double yInterval = (y2 - y1) / numOfIntermediatePoints;
          double xInterval = (x2 - x1) / numOfIntermediatePoints;
          for (int j = 0; j <= numOfIntermediatePoints; j++) {
            final intermediateY = y1 + yInterval * j;
            final intermediateX = x1 + xInterval * j;
            if (intermediateX.isFinite && intermediateY.isFinite) {
              // Draw an intermediate point if it is within the canvas bounds
              canvas.drawCircle(
                Offset(intermediateX, yTranslation - intermediateY),
                sqrt(graphStroke),
                paint,
              );
            }
          }
        }
        // Draw the data point
        canvas.drawCircle(
          Offset(x1, yTranslation - y1),
          sqrt(graphStroke),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class _LineGraphPainter extends CustomPainter {
  _LineGraphPainter({
    required this.data,
    required this.graphStroke,
    required this.color,
    this.supportNegativeValuesDisplay = false,
  });

  // The data to be plotted in the graph
  final List<Point<double>> data;

  // The width of the graph's lines
  final double graphStroke;

  // The color of the graph
  final Color color;

  // Whether to support display of negative values on the graph
  final bool supportNegativeValuesDisplay;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = graphStroke
      ..color = color;

    // A path object to store the graph's lines
    Path path = Path();

    if (data.isNotEmpty) {
      // Calculate the maximum and minimum y values in the data
      final maxY = data.map((point) => point.y).reduce(max);
      final minY = data.map((point) => point.y).reduce(min);

      // Calculate the scaling factor for the y values
      double yScale = 1;
      final yTranslation =
          supportNegativeValuesDisplay ? size.height / 2 : size.height;
      if (maxY.abs() > yTranslation) {
        yScale = yTranslation / maxY.abs();
      }

      if (minY.abs() > yTranslation) {
        final scale = yTranslation / minY.abs();
        if (maxY.abs() < minY.abs()) {
          yScale = scale;
        }
      }

      // Start the path at the first data point
      path.moveTo(
        data.first.x + size.width,
        yTranslation - (data.first.y * yScale),
      );

      // Plot the lines between each subsequent data point
      for (int i = 0; i < data.length - 1; i++) {
        final y = data[i + 1].y * yScale;
        final x = data[i + 1].x + size.width;
        path.lineTo(x, yTranslation - y);
      }
    }

    // Draw the path on the canvas
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
