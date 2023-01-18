import 'package:flutter/material.dart';
import 'package:interactive_chart/interactive_chart.dart';
import 'package:logging/logging.dart';

import 'mock_data.dart';
import 'coin_data.dart';

final log = Logger('chart');

class CandleChartModel extends ChangeNotifier {
  List<CandleData> _data = MockDataTesla.candles;

  List<CandleData> get data => _data;

  updateData(List<CandleData> data) {
    _data = data;

    notifyListeners();
  }

  computeMa200() {
    final ma200 = CandleData.computeMA(_data, 200);

    for (int i = 0; i < _data.length; i++) {
      _data[i].trends = [ma200[i]];
    }

    notifyListeners();
  }

  removeTrendLines() {
    for (final data in _data) {
      data.trends = [];
    }

    notifyListeners();
  }
}

class CandleChart extends StatelessWidget {
  final CandleChartModel model;

  const CandleChart(this.model, {super.key});

  @override
  Widget build(BuildContext context) {
    return InteractiveChart(candles: model.data);
  }
}

class SparkPainter extends CustomPainter {
  final MarketInterval interval;
  final List<CandleData> candles;
  final int startIndex;
  final Color color;

  SparkPainter(this.interval, this.candles, this.startIndex, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    //canvas.drawRect(Rect.fromPoints(const Offset(0, 0), Offset(size.width, size.height)), Paint()..color = Colors.green..style = PaintingStyle.stroke);
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    var xInc = size.width / (candles.length - startIndex);
    var xCur = 0.0;
    var yMin = 999999999999999999.0;
    var yMax = 0.0;
    for (var i = startIndex; i < candles.length; i++) {
      var c = candles[i];
      if (c.close != null) {
        if (yMax < c.close!) yMax = c.close!;
        if (yMin > c.close!) yMin = c.close!;
      }
    }
    var yRange = yMax - yMin;
    double? yCur;
    for (var i = startIndex; i < candles.length - 1; i++) {
      var c = candles[i];
      if (c.close != null) {
        var closeNormalized = c.close! - yMin;
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
      if (i == candles.length - 2 && yCur != null) {
        canvas.drawCircle(
            Offset(xCur, yCur), 3, paint..style = PaintingStyle.fill);
      }
    }
  }

  @override
  bool shouldRepaint(SparkPainter oldDelegate) => false;
}
