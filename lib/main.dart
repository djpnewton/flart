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
  const MyApp({Key? key}) : super(key: key);

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  bool _darkMode = true;

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
            body: const HomePage()));
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  Exchange _exch = Exchange.Bitfinex;
  ExchData _exchData = createExchData(Exchange.Bitfinex);
  List<Market> _markets = [];
  Market _market = Market.empty();
  bool _showMa200 = false;
  List<bool> _selectedInterval = [false, false, true, false, false];
  bool _haveData = false;
  bool _retreivingData = false;
  int _requestId = 0;

  @override
  void initState() {
    _initMarkets();
    super.initState();
  }

  Widget _makeControls() {
    return Row(children: [
      const SizedBox(width: 10),
      DropdownButton<Exchange>(
          items: Exchange.values
              .map((e) =>
                  DropdownMenuItem<Exchange>(value: e, child: Text(e.name)))
              .toList(),
          value: _exch,
          onChanged: _exchChange),
      const SizedBox(width: 10),
      _markets.isEmpty
          ? const SizedBox()
          : DropdownButton<String>(
              items: _markets
                  .map((e) => DropdownMenuItem<String>(
                      value: e.exchangeId, child: Text(e.symbol())))
                  .toList(),
              value: _market.exchangeId,
              onChanged: _marketChange),
      const SizedBox(width: 10),
      _markets.isEmpty
          ? const SizedBox()
          : ToggleButtons(
              isSelected: [_showMa200],
              onPressed: (int index) => _toggleMa200(),
              children: const [Text('MA 200')],
            ),
      const SizedBox(width: 10),
      _markets.isEmpty
          ? const SizedBox()
          : ToggleButtons(
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
              children: MarketInterval.values
                  .map((e) => Text(e.name.substring(1)))
                  .toList(),
            ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _makeControls(),
      _retreivingData
          ? const Center(child: CircularProgressIndicator())
          : _haveData
              ? Expanded(
                  child: Consumer<ChartModel>(
                      builder: (context, model, child) => Chart(model)))
              : const Text('no data to show')
    ]);
  }

  void _exchChange(Exchange? exch) {
    if (exch == null) return;
    setState(() {
      _markets = [];
      _retreivingData = true;
      _haveData = false;
      _exch = exch;
      _exchData = createExchData(exch);
      _initMarkets();
    });
  }

  void _initMarkets() {
    _exchData.markets().then((value) {
      if (value.err == null) {
        setState(() => _markets = value.markets);
        if (value.markets.isNotEmpty) _setMarket(value.markets[0]);
      } else {
        var snackBar =
            SnackBar(content: Text('Unable to get markets! - ${value.err}'));
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    });
  }

  void _setMarket(Market market) {
    setState(() => _market = market);
    _updateCandles(market, _interval());
  }

  void _marketChange(String? exchangeId) {
    for (var market in _markets) {
      if (market.exchangeId == exchangeId) {
        _setMarket(market);
        return;
      }
    }
  }

  MarketInterval _interval() {
    for (int i = 0; i < _selectedInterval.length; i++) {
      if (_selectedInterval[i]) {
        return MarketInterval.values[i];
      }
    }
    log.severe('could not find valid interval');
    return MarketInterval.values[0];
  }

  void _updateCandles(Market market, MarketInterval interval) {
    _requestId += 1;
    var reqId = _requestId;
    log.info('get data for ${market.symbol} $interval, req id: $reqId..');
    setState(() => _retreivingData = true);
    _exchData.candles(market.exchangeId, interval).then((value) {
      if (value.err == null) {
        log.info('got data for ${market.symbol} $interval, req id: $reqId');
        if (_requestId > reqId) return;
        var model = context.read<ChartModel>();
        model.updateData(value.candles);
        _updateMa200();
        setState(() {
          _retreivingData = false;
          _haveData = true;
        });
      } else {
        var snackBar =
            SnackBar(content: Text('Unable to get candles! - ${value.err}'));
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
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
