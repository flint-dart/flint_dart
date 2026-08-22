import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Represents a single data series in a [LineChart].
class LineChartSeries {
  final List<double> data;
  final String strokeColor;
  final String fillColor;
  final double strokeWidth;
  final String label;

  const LineChartSeries({
    required this.data,
    this.strokeColor = '#6366f1',
    this.fillColor = 'rgba(99, 102, 241, 0.08)',
    this.strokeWidth = 2.5,
    this.label = '',
  });
}

/// A customizable SVG-based Line Chart widget for displaying trends.
class LineChart extends FlintElement {
  LineChart({
    List<double>? data,
    required List<String> labels,
    List<LineChartSeries>? series,
    double height = 200.0,
    String strokeColor = '#6366f1',
    String fillColor = 'rgba(99, 102, 241, 0.08)',
    double strokeWidth = 2.5,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         'div',
         props: mergeComponentProps(
           props,
           className: className,
           defaultStyle: const {'width': '100%'},
           dartStyle: dartStyle,
           style: style,
         ),
         children: [
           _buildSvg(
             series ?? [
               LineChartSeries(
                 data: data ?? const [],
                 strokeColor: strokeColor,
                 fillColor: fillColor,
                 strokeWidth: strokeWidth,
               ),
             ],
             labels,
             height,
           ),
         ],
       );

  static FlintNode _buildSvg(
    List<LineChartSeries> seriesList,
    List<String> labels,
    double height,
  ) {
    if (seriesList.isEmpty || seriesList.every((s) => s.data.isEmpty)) {
      return FlintElement(
        'div',
        props: const {
          'style': {
            'padding': '20px',
            'text-align': 'center',
            'color': '#94a3b8',
          },
        },
        children: [FlintText('No data available')],
      );
    }

    final double width = 600.0;
    final double padLeft = 50.0;
    final double padRight = 20.0;
    final double padTop = 20.0;
    final double padBottom = 30.0;

    final double graphWidth = width - padLeft - padRight;
    final double graphHeight = height - padTop - padBottom;

    // Find min and max values across all series to scale
    double maxVal = double.negativeInfinity;
    double minVal = double.infinity;

    for (final series in seriesList) {
      if (series.data.isEmpty) continue;
      final double localMax = series.data.reduce((a, b) => a > b ? a : b);
      final double localMin = series.data.reduce((a, b) => a < b ? a : b);
      if (localMax > maxVal) maxVal = localMax;
      if (localMin < minVal) minVal = localMin;
    }

    if (maxVal == double.negativeInfinity) {
      maxVal = 10.0;
      minVal = 0.0;
    }
    if (maxVal == minVal) maxVal = minVal + 10.0;

    // Round max value up slightly for clean axis lines
    final double yMax = maxVal * 1.05;
    final double yMin = minVal * 0.95 > 0 ? minVal * 0.95 : 0.0;

    // Y grid values
    final yGridLines = <double>[];
    for (int i = 0; i <= 3; i++) {
      yGridLines.add(yMin + (yMax - yMin) * (i / 3));
    }

    return FlintElement(
      'svg',
      props: {
        'viewBox': '0 0 $width $height',
        'width': '100%',
        'height': '${height}px',
        'style': {'display': 'block', 'overflow': 'visible'},
      },
      children: [
        // Grid Lines & Y labels
        for (final gridVal in yGridLines) ...[
          FlintElement(
            'line',
            props: {
              'x1': padLeft.toString(),
              'y1':
                  (padTop +
                          (1.0 - (gridVal - yMin) / (yMax - yMin)) *
                              graphHeight)
                      .toString(),
              'x2': (width - padRight).toString(),
              'y2':
                  (padTop +
                          (1.0 - (gridVal - yMin) / (yMax - yMin)) *
                              graphHeight)
                      .toString(),
              'stroke': 'rgba(255, 255, 255, 0.05)',
              'stroke-width': '1',
              'stroke-dasharray': '4 4',
            },
          ),
          FlintElement(
            'text',
            props: {
              'x': (padLeft - 8).toString(),
              'y':
                  (padTop +
                          (1.0 - (gridVal - yMin) / (yMax - yMin)) *
                              graphHeight +
                          4)
                      .toString(),
              'fill': '#94a3b8',
              'font-size': '10px',
              'font-family': 'sans-serif',
              'text-anchor': 'end',
            },
            children: [
              FlintText(
                gridVal >= 1000
                    ? '\$${(gridVal / 1000).toStringAsFixed(1)}k'
                    : '\$${gridVal.toStringAsFixed(0)}',
              ),
            ],
          ),
        ],

        // Draw paths for each series
        for (final series in seriesList) ...[
          ..._buildSeriesPaths(series, labels.length, yMin, yMax, padLeft, padTop, graphWidth, graphHeight, height, padBottom),
        ],

        // X labels
        for (int i = 0; i < labels.length; i++) ...[
          FlintElement(
            'text',
            props: {
              'x':
                  (padLeft +
                          (labels.length > 1
                              ? (i / (labels.length - 1)) * graphWidth
                              : 0.0))
                      .toString(),
              'y': (height - 8).toString(),
              'fill': '#94a3b8',
              'font-size': '10px',
              'font-family': 'sans-serif',
              'text-anchor': 'middle',
            },
            children: [FlintText(labels[i])],
          ),
        ],
      ],
    );
  }

  static List<FlintNode> _buildSeriesPaths(
    LineChartSeries series,
    int labelsLength,
    double yMin,
    double yMax,
    double padLeft,
    double padTop,
    double graphWidth,
    double graphHeight,
    double height,
    double padBottom,
  ) {
    if (series.data.isEmpty) return const [];

    final points = <String>[];
    final fillPoints = <String>[];

    // Add start fill point
    fillPoints.add('$padLeft,${height - padBottom}');

    for (int i = 0; i < series.data.length; i++) {
      final double pctX = series.data.length > 1 ? (i / (series.data.length - 1)) : 0.0;
      final double x = padLeft + (pctX * graphWidth);

      final double pctY = (series.data[i] - yMin) / (yMax - yMin);
      final double y = padTop + ((1.0 - pctY) * graphHeight);

      points.add('$x,$y');
      fillPoints.add('$x,$y');
    }

    // Add end fill point
    fillPoints.add('${padLeft + (series.data.length > 1 ? graphWidth : 0.0)},${height - padBottom}');

    return [
      // Filled path under the line
      FlintElement(
        'polygon',
        props: {'points': fillPoints.join(' '), 'fill': series.fillColor},
      ),

      // Smooth polyline path
      FlintElement(
        'polyline',
        props: {
          'points': points.join(' '),
          'fill': 'none',
          'stroke': series.strokeColor,
          'stroke-width': series.strokeWidth.toString(),
          'stroke-linecap': 'round',
          'stroke-linejoin': 'round',
        },
      ),

      // Interactive/Highlighted data point circles
      for (int i = 0; i < series.data.length; i++)
        FlintElement(
          'circle',
          props: {
            'cx':
                (padLeft +
                        (series.data.length > 1
                            ? (i / (series.data.length - 1)) * graphWidth
                            : 0.0))
                    .toString(),
            'cy':
                (padTop +
                        (1.0 - (series.data[i] - yMin) / (yMax - yMin)) *
                            graphHeight)
                    .toString(),
            'r': '4',
            'fill': series.strokeColor,
            'stroke': '#1e1b4b',
            'stroke-width': '2',
            'style': {'transition': 'all 0.15s ease', 'cursor': 'pointer'},
          },
        ),
    ];
  }
}
/// Represents a single data series in a [BarChart].
class BarChartSeries {
  final List<double> data;
  final String barColor;
  final String label;

  const BarChartSeries({
    required this.data,
    this.barColor = '#6366f1',
    this.label = '',
  });
}

/// A customizable SVG-based Bar Chart widget for representing categories/metrics.
class BarChart extends FlintElement {
  BarChart({
    List<double>? data,
    required List<String> labels,
    List<BarChartSeries>? series,
    double height = 200.0,
    String barColor = '#6366f1',
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         'div',
         props: mergeComponentProps(
           props,
           className: className,
           defaultStyle: const {'width': '100%'},
           dartStyle: dartStyle,
           style: style,
         ),
         children: [
           _buildSvg(
             series ?? [
               BarChartSeries(
                 data: data ?? const [],
                 barColor: barColor,
               ),
             ],
             labels,
             height,
           )
         ],
       );

  static FlintNode _buildSvg(
    List<BarChartSeries> seriesList,
    List<String> labels,
    double height,
  ) {
    if (seriesList.isEmpty || seriesList.every((s) => s.data.isEmpty)) {
      return FlintElement(
        'div',
        props: const {
          'style': {
            'padding': '20px',
            'text-align': 'center',
            'color': '#94a3b8',
          },
        },
        children: [FlintText('No data available')],
      );
    }

    final double width = 600.0;
    final double padLeft = 40.0;
    final double padRight = 20.0;
    final double padTop = 20.0;
    final double padBottom = 30.0;

    final double graphWidth = width - padLeft - padRight;
    final double graphHeight = height - padTop - padBottom;

    // Find min and max values to scale
    double maxVal = double.negativeInfinity;
    for (final series in seriesList) {
      if (series.data.isEmpty) continue;
      final double localMax = series.data.reduce((a, b) => a > b ? a : b);
      if (localMax > maxVal) maxVal = localMax;
    }
    if (maxVal <= 0) maxVal = 10.0;

    final double yMax = maxVal * 1.05;

    // Calculate grouping sizes
    final double totalBarsPerGroup = seriesList.length.toDouble();
    final double barGapRatio = 0.35; // gap width as fraction of category space
    final double barSpaceWidth = graphWidth / labels.length;
    final double groupActiveWidth = barSpaceWidth * (1.0 - barGapRatio);
    final double barWidth = groupActiveWidth / totalBarsPerGroup;

    return FlintElement(
      'svg',
      props: {
        'viewBox': '0 0 $width $height',
        'width': '100%',
        'height': '${height}px',
        'style': {'display': 'block', 'overflow': 'visible'},
      },
      children: [
        // Horizontal Grid Lines
        for (int i = 0; i <= 3; i++) ...[
          FlintElement(
            'line',
            props: {
              'x1': padLeft.toString(),
              'y1': (padTop + (i / 3) * graphHeight).toString(),
              'x2': (width - padRight).toString(),
              'y2': (padTop + (i / 3) * graphHeight).toString(),
              'stroke': 'rgba(255, 255, 255, 0.05)',
              'stroke-width': '1',
            },
          ),
        ],

        // Grouped Bars
        for (int i = 0; i < labels.length; i++) ...[
          for (int s = 0; s < seriesList.length; s++) ...[
            ..._buildBar(seriesList[s], i, s, barSpaceWidth, barWidth, barGapRatio, yMax, padLeft, padTop, graphHeight),
          ]
        ],

        // X labels
        for (int i = 0; i < labels.length; i++) ...[
          FlintElement(
            'text',
            props: {
              'x': (padLeft + (i * barSpaceWidth) + (barSpaceWidth / 2))
                  .toString(),
              'y': (height - 8).toString(),
              'fill': '#94a3b8',
              'font-size': '10px',
              'font-family': 'sans-serif',
              'text-anchor': 'middle',
            },
            children: [FlintText(labels[i])],
          ),
        ],
      ],
    );
  }

  static List<FlintNode> _buildBar(
    BarChartSeries series,
    int itemIndex,
    int seriesIndex,
    double barSpaceWidth,
    double barWidth,
    double barGapRatio,
    double yMax,
    double padLeft,
    double padTop,
    double graphHeight,
  ) {
    if (itemIndex >= series.data.length) return const [];
    final double val = series.data[itemIndex];

    final double barX = padLeft +
        (itemIndex * barSpaceWidth) +
        (barSpaceWidth * barGapRatio / 2) +
        (seriesIndex * barWidth);

    final double barY = padTop + (1.0 - (val / yMax)) * graphHeight;
    final double barH = (val / yMax) * graphHeight;

    // Apply a tiny inner gap between adjacent bars in the group
    final double innerGap = barWidth * 0.1 > 1.5 ? 1.5 : barWidth * 0.1;
    final double rectX = barX + innerGap / 2;
    final double rectWidth = barWidth - innerGap;

    return [
      FlintElement(
        'rect',
        props: {
          'x': rectX.toString(),
          'y': barY.toString(),
          'width': rectWidth.toString(),
          'height': barH.toString(),
          'rx': '4',
          'fill': series.barColor,
          'style': {'transition': 'all 0.2s ease', 'cursor': 'pointer'},
        },
      ),
      // Bar value labels on top of bars
      FlintElement(
        'text',
        props: {
          'x': (barX + barWidth / 2).toString(),
          'y': (barY - 6).toString(),
          'fill': '#e2e8f0',
          'font-size': '9px',
          'font-family': 'sans-serif',
          'font-weight': 'bold',
          'text-anchor': 'middle',
        },
        children: [FlintText(val.toStringAsFixed(0))],
      ),
    ];
  }
}
