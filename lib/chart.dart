import 'package:flart/mock_data.dart';
import 'package:flutter/material.dart';
import 'package:interactive_chart/interactive_chart.dart';
import 'package:logging/logging.dart';

final log = Logger('chart');

class ChartModel extends ChangeNotifier {
  List<CandleData> _data = MockDataTesla.candles;

  List<CandleData> get data => _data;

  updateData(List<CandleData> data) {
    _data = data;

    notifyListeners();
  }

  computeTrendLines() {
    final ma7 = CandleData.computeMA(_data, 7);
    final ma30 = CandleData.computeMA(_data, 30);
    final ma90 = CandleData.computeMA(_data, 90);

    for (int i = 0; i < _data.length; i++) {
      _data[i].trends = [ma7[i], ma30[i], ma90[i]];
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

class Chart extends StatelessWidget {
  final ChartModel model;

  const Chart(this.model, {super.key});

  @override
  Widget build(BuildContext context) {
    return InteractiveChart(candles: model.data);
  }
}
