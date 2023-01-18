import 'package:flutter/material.dart';
import 'package:interactive_chart/interactive_chart.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'chart.dart';
import 'chart_page.dart';
import 'coin_data.dart';
import 'widgets.dart';

final log = Logger('overview_page');
const cellSize = 200.0;

Widget cell(Widget? child) {
  return SizedBox(
      width: cellSize, child: child != null ? Center(child: child) : null);
}

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  OverviewPageState createState() => OverviewPageState();
}

class OverviewPageState extends State<OverviewPage> {
  Exchange _exch = Exchange.Bitfinex;
  ExchData _exchData = createExchData(Exchange.Bitfinex);
  List<Market> _markets = [];
  Map<String, List<CandleData>> _candles = {};
  bool _retreivingData = false;
  int _requestId = 0;

  final interval = MarketInterval.i1h;

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
      IconButton(onPressed: _refreshData, icon: const Icon(Icons.refresh))
    ]);
  }

  @override
  Widget build(BuildContext context) {
    var ts = const TextStyle(decoration: TextDecoration.underline);
    return SingleChildScrollView(
        child: Column(children: [
      _makeControls(),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        cell(Text('Market', style: ts)),
        cell(Text('Last 7 days', style: ts)),
        cell(Text('Price', style: ts)),
        cell(Text('1h %', style: ts)),
        cell(Text('1d %', style: ts)),
        cell(Text('1w %', style: ts))
      ]),
      _retreivingData
          ? const Center(child: CircularProgressIndicator())
          : _markets.isNotEmpty
              ? Column(
                  children: _markets
                      .map((e) => OverviewWidget(
                          e, interval, _candles[e.exchangeId], _marketDetail))
                      .toList())
              : const Text('no data to show')
    ]));
  }

  void _exchChange(Exchange? exch) {
    if (exch == null) return;
    setState(() {
      _markets = [];
      _retreivingData = true;
      _exch = exch;
      _exchData = createExchData(exch);
      _initMarkets();
    });
  }

  void _initMarkets() {
    _exchData.markets().then((value) {
      if (value.err == null) {
        setState(() {
          _markets = value.markets;
          _candles.clear();
          _retreivingData = false;
        });
        for (var market in value.markets) {
          _updateMarket(market);
        }
      } else {
        var snackBar =
            SnackBar(content: Text('Unable to get markets! - ${value.err}'));
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    });
  }

  void _updateMarket(Market market) {
    _requestId += 1;
    var reqId = _requestId;
    log.info('get data for ${market.symbol} $interval, req id: $reqId..');
    _exchData.candles(market.exchangeId, interval).then((value) {
      if (value.err == null) {
        log.info('got data for ${market.symbol} $interval, req id: $reqId');
        _candles[market.exchangeId] = value.candles;
        setState(() => _candles = _candles);
      } else {
        var snackBar =
            SnackBar(content: Text('Unable to get candles! - ${value.err}'));
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    });
  }

  void _marketDetail(Market market) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ChangeNotifierProvider(
                create: (context) => CandleChartModel(),
                child: BasicScreen(ChartPage(_exch, market),
                    title: 'Chart Detail'))));
  }

  void _refreshData() {
    setState(() => _retreivingData = true);
    _initMarkets();
  }
}

class OverviewWidget extends StatefulWidget {
  final Market market;
  final MarketInterval interval;
  final List<CandleData>? candles1h;
  final Function(Market market) onMarketClick;

  const OverviewWidget(
      this.market, this.interval, this.candles1h, this.onMarketClick,
      {super.key});

  @override
  OverviewWidgetState createState() => OverviewWidgetState();
}

class OverviewWidgetState extends State<OverviewWidget> {
  @override
  void initState() {
    super.initState();
  }

  int _sparkCandleIndex() {
    // get the last week of data
    const hoursInWeek = 168;
    if (widget.candles1h == null) return 0;
    if (widget.candles1h!.length <= hoursInWeek) return 0;
    return widget.candles1h!.length - hoursInWeek;
  }

  double _percentChange(int startIndex) {
    if (widget.candles1h == null || widget.candles1h!.isEmpty) return 0;
    var start = widget.candles1h![startIndex].close;
    var end = widget.candles1h![widget.candles1h!.length - 1].close;
    if (start == null || end == null) return 0;
    var diff = end - start;
    var avg = (start + end) / 2;
    return (diff / avg) * 100;
  }

  Widget _changeIndicator(int numPeriods) {
    var startIndex = widget.candles1h == null
        ? 0
        : widget.candles1h!.length - 1 - numPeriods;
    var upArrow = '▲';
    var downArrow = '▼';
    var change = _percentChange(startIndex);
    var changeStr = change.toStringAsFixed(2);
    if (change >= 0) {
      return Text('$upArrow$changeStr%',
          style: const TextStyle(color: Colors.green));
    } else {
      return Text('$downArrow$changeStr%',
          style: const TextStyle(color: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    const sparkColor = Colors.blue;
    var rowWidgets = [
      cell(TextButton(
          child: Text(widget.market.symbol()),
          onPressed: () => widget.onMarketClick(widget.market)))
    ];
    if (widget.candles1h != null) {
      rowWidgets.add(cell(SizedBox(
          width: 100,
          height: 30,
          child: CustomPaint(
              painter: SparkPainter(widget.interval, widget.candles1h!,
                  _sparkCandleIndex(), sparkColor)))));
      rowWidgets.add(cell(
          Text('${widget.candles1h?.last.close} ${widget.market.quoteAsset}')));
      rowWidgets.add(cell(_changeIndicator(1))); // 1h
      rowWidgets.add(cell(_changeIndicator(24))); // 1d
      rowWidgets.add(cell(_changeIndicator(168))); // 1w
    } else {
      rowWidgets.add(cell(const CircularProgressIndicator()));
      rowWidgets.add(cell(null));
    }
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: rowWidgets));
  }
}
