import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';

import 'chart.dart';
import 'coin_data.dart';

final log = Logger('main');

void main() {
  runApp(ChangeNotifierProvider(
      create: (context) => ChartModel(), child: const MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  bool _darkMode = true;
  bool _showAverage = false;
  bool _retreivingData = true;

  @override
  void initState() {
    btcData().then((value) {
      log.info('retrieved data');
      var model = context.read<ChartModel>();
      model.updateData(value);
      setState(() => _retreivingData = false);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: _darkMode ? Brightness.dark : Brightness.light,
        ),
        home: Scaffold(
            appBar: AppBar(title: const Text('Basic BTC Chart'), actions: [
              IconButton(
                icon: Icon(_darkMode ? Icons.dark_mode : Icons.light_mode),
                onPressed: () => setState(() => _darkMode = !_darkMode),
              ),
              IconButton(
                icon: Icon(
                  _showAverage ? Icons.show_chart : Icons.bar_chart_outlined,
                ),
                onPressed: () {
                  _showAverage = !_showAverage;
                  var model = context.read<ChartModel>();
                  if (_showAverage) {
                    model.computeTrendLines();
                  } else {
                    model.removeTrendLines();
                  }
                },
              ),
            ]),
            body: _retreivingData
                ? const CircularProgressIndicator()
                : Consumer<ChartModel>(
                    builder: (context, model, child) => Chart(model))));
  }
}
