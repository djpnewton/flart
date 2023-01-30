import 'package:flutter/material.dart';
import 'package:interactive_chart/interactive_chart.dart';
import 'package:logging/logging.dart';
import 'package:intl/intl.dart';

import 'mock_data.dart';

final log = Logger('chart');

class CandleChartModel extends ChangeNotifier {
  final _ma200Color = Colors.blueGrey;

  String _exchange = '';
  String _market = '';
  String _interval = '';
  List<CandleData> _data = MockDataTesla.candles;
  ChartStyle _chartStyle = const ChartStyle();
  bool _ma200 = false;

  List<CandleData> get data => _data;
  ChartStyle get style => _chartStyle;

  updateData(
      String exchange, String market, String interval, List<CandleData> data) {
    _exchange = exchange;
    _market = market;
    _interval = interval;
    _data = data;

    notifyListeners();
  }

  computeMa200() {
    final ma200 = CandleData.computeMA(_data, 200);
    for (int i = 0; i < _data.length; i++) {
      _data[i].trends = [ma200[i]];
    }
    _chartStyle = ChartStyle(trendLineStyles: [
      Paint()
        ..strokeWidth = 2
        ..color = _ma200Color
    ]);
    _ma200 = true;

    notifyListeners();
  }

  removeTrendLines() {
    for (final data in _data) {
      data.trends = [];
    }
    _ma200 = false;

    notifyListeners();
  }
}

class CandleChart extends StatelessWidget {
  final CandleChartModel model;

  const CandleChart(this.model, {super.key});

  Widget _buildTitleAndLegend() {
    var title = Text('${model._exchange} ${model._market} ${model._interval}',
        style: const TextStyle(fontSize: 18));
    var legend = model._ma200
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('MA 200'),
            const SizedBox(width: 10),
            SizedBox(
                width: 30,
                height: 30,
                child: CustomPaint(painter: LegendPainter(model._ma200Color)))
          ])
        : const SizedBox();
    return Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(5),
        decoration: const BoxDecoration(color: Colors.black12),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, legend]));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      InteractiveChart(
          candles: model.data,
          style: model.style,
          overlayInfo: _getOverlayInfo,
          onTap: _onTap),
      _buildTitleAndLegend()
    ]);
  }

  Map<String, String> _getOverlayInfo(CandleData candle) {
    final date = DateFormat.yMMMd()
        .format(DateTime.fromMillisecondsSinceEpoch(candle.timestamp));
    var data = {
      'Date': date,
      'Open': candle.open?.toStringAsFixed(2) ?? '-',
      'High': candle.high?.toStringAsFixed(2) ?? '-',
      'Low': candle.low?.toStringAsFixed(2) ?? '-',
      'Close': candle.close?.toStringAsFixed(2) ?? '-',
      'Volume': candle.volume?.asAbbreviated() ?? '-',
    };
    if (candle.trends.isNotEmpty) {
      data['MA 200'] = candle.trends[0]?.toStringAsFixed(2) ?? '-';
    }
    return data;
  }

  void _onTap(CandleData candel, int candleIndex, double price) {
    //blah!
  }
}

class LegendPainter extends CustomPainter {
  final Color color;

  LegendPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    canvas.drawLine(
        Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
  }

  @override
  bool shouldRepaint(SparkPainter oldDelegate) => false;
}

class SparkPainter extends CustomPainter {
  final List<double?> values;
  final Color color;

  SparkPainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    //canvas.drawRect(Rect.fromPoints(const Offset(0, 0), Offset(size.width, size.height)), Paint()..color = Colors.green..style = PaintingStyle.stroke);
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    var xInc = size.width / values.length;
    var xCur = 0.0;
    var yMin = 999999999999999999.0;
    var yMax = 0.0;
    for (var i = 0; i < values.length; i++) {
      var v = values[i];
      if (v != null) {
        if (yMax < v) yMax = v;
        if (yMin > v) yMin = v;
      }
    }
    var yRange = yMax - yMin;
    double? yCur;
    for (var i = 0; i < values.length - 1; i++) {
      var v = values[i];
      if (v != null) {
        var closeNormalized = v - yMin;
        if (yCur == null) {
          yCur = size.height - closeNormalized / yRange * size.height;
          canvas.drawCircle(
              Offset(xCur, yCur), 3, paint..style = PaintingStyle.fill);
        } else {
          var yNext = size.height - closeNormalized / yRange * size.height;
          canvas.drawLine(
              Offset(xCur, yCur), Offset(xCur + xInc, yNext), paint);
          yCur = yNext;
        }
      }
      xCur += xInc;
      if (i == values.length - 2 && yCur != null) {
        canvas.drawCircle(
            Offset(xCur, yCur), 3, paint..style = PaintingStyle.fill);
      }
    }
  }

  @override
  bool shouldRepaint(SparkPainter oldDelegate) => false;
}
