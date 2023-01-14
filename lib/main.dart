import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';

import 'config.dart';
import 'chart.dart';
import 'coin_data.dart';

final log = Logger('main');

void main() {
  // setup logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  log.info('Git SHA: $gitSha');
  log.info('Build Date: $buildDate');
  runApp(ChangeNotifierProvider(
      create: (context) => ChartModel(), child: const MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  final _coinData = CoinData();
  bool _darkMode = true;
  List<Market> _markets = [];
  Market _market = Market.empty();
  bool _showMa200 = false;
  final List<String> _intervals = ['5m', '1h', '1D', '1W', '1M'];
  List<bool> _selectedInterval = [false, false, true, false, false];
  bool _haveData = false;
  bool _retreivingData = false;

  @override
  void initState() {
    _coinData.markets().then((value) {
      setState(() => _markets = value);
      if (value.isNotEmpty) {
        _setMarket(value[0]);
      }
    });
    super.initState();
  }

  Widget _makeControls() {
    if (_markets.isEmpty) {
      return Row(children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(_coinData.source())),
        const CircularProgressIndicator()
      ]);
    }
    return Row(children: [
      const SizedBox(width: 10),
      Text(_coinData.source()),
      const SizedBox(width: 10),
      DropdownButton<String>(
          items: _markets
              .map((e) => DropdownMenuItem<String>(
                  value: e.symbol,
                  child: Text('${e.baseAsset}-${e.quoteAsset}')))
              .toList(),
          value: _market.symbol,
          onChanged: _marketChange),
      const SizedBox(width: 10),
      ToggleButtons(
        isSelected: [_showMa200],
        onPressed: (int index) => _toggleMa200(),
        children: const [Text('MA 200')],
      ),
      const SizedBox(width: 10),
      ToggleButtons(
        isSelected: _selectedInterval,
        onPressed: (int index) {
          for (int buttonIndex = 0;
              buttonIndex < _selectedInterval.length;
              buttonIndex++) {
            if (buttonIndex == index) {
              _selectedInterval[buttonIndex] = true;
            } else {
              _selectedInterval[buttonIndex] = false;
            }
          }
          setState(() => _selectedInterval = _selectedInterval);
          _updateCandles(_market, _interval());
        },
        children: _intervals.map((e) => Text(e)).toList(),
      ),
    ]);
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
          ]),
          body: Column(children: [
            _makeControls(),
            _retreivingData
                ? const Center(child: CircularProgressIndicator())
                : _haveData
                    ? Expanded(
                        child: Consumer<ChartModel>(
                            builder: (context, model, child) => Chart(model)))
                    : const Text('no data to show')
          ]),
        ));
  }

  void _setMarket(Market market) {
    setState(() => _market = market);
    _updateCandles(market, _interval());
  }

  void _marketChange(String? symbol) {
    for (var market in _markets) {
      if (market.symbol == symbol) {
        _setMarket(market);
        return;
      }
    }
  }

  String _interval() {
    for (int i = 0; i < _selectedInterval.length; i++) {
      if (_selectedInterval[i]) {
        return _intervals[i];
      }
    }
    log.severe('could not find valid interval');
    return _intervals[0];
  }

  void _updateCandles(Market market, String interval) {
    setState(() => _retreivingData = true);
    _coinData.candles(market.symbol, interval).then((value) {
      log.info('retrieved data for ${market.symbol}');
      var model = context.read<ChartModel>();
      model.updateData(value);
      _updateMa200();
      setState(() {
        _retreivingData = false;
        _haveData = true;
      });
    });
  }

  void _toggleMa200() {
    setState(() => _showMa200 = !_showMa200);
    _updateMa200();
  }

  void _updateMa200() {
    var model = context.read<ChartModel>();
    if (_showMa200) {
      model.computeMa200();
    } else {
      model.removeTrendLines();
    }
  }
}
