import 'package:flutter/material.dart';
import 'package:interactive_chart/interactive_chart.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import 'chart.dart';
import 'chart_page.dart';
import 'coin_data.dart';
import 'widgets.dart';

final log = Logger('overview_page');
const cellSize = 140.0;

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
  String _quoteAsset = quoteAssets.first;
  Exchange _exch = Exchange.Bitfinex;
  ExchData _exchData = createExchData(Exchange.Bitfinex);
  List<ExchMarket> _exchMarkets = [];
  List<MarketOverview> _markets = [];
  bool _retreivingData = false;
  String _searchAsset = '';

  final interval = MarketInterval.i1h;

  @override
  void initState() {
    _initMarkets();
    super.initState();
  }

  Widget _makeControls() {
    return Row(children: [
      const SizedBox(width: 10),
      const Text('Refresh: '),
      IconButton(onPressed: _refreshData, icon: const Icon(Icons.refresh)),
      const SizedBox(width: 20),
      const Text('Quote asset: '),
      DropdownButton<String>(
          items: quoteAssets
              .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
              .toList(),
          value: _quoteAsset,
          onChanged: _quoteAssetChange),
      const SizedBox(width: 20),
      SearchInput(_search),
      const SizedBox(width: 20),
      const Text('Show detail using: '),
      DropdownButton<Exchange>(
          items: Exchange.values
              .map((e) =>
                  DropdownMenuItem<Exchange>(value: e, child: Text(e.name)))
              .toList(),
          value: _exch,
          onChanged: _exchChange),
    ]);
  }

  List<Widget> _overviewRows() {
    if (_searchAsset.isEmpty) {
      return _markets
          .map((e) => OverviewWidget(null, null, null, e, _marketDetailTap))
          .toList();
    }
    // TODO: figure out why the wrong wigets get rendered when a search filter is set
    var filteredMarkets = _markets.where((e) =>
        e.baseAsset.toUpperCase().startsWith(_searchAsset.toUpperCase()));
    var widgets = filteredMarkets
        .map((e) => OverviewWidget(null, null, null, e, _marketDetailTap))
        .toList();
    return widgets;
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
        cell(Text('Market Cap', style: ts)),
        cell(Text('Price', style: ts)),
        cell(Text('1h %', style: ts)),
        cell(Text('1d %', style: ts)),
        cell(Text('1w %', style: ts))
      ]),
      _retreivingData
          ? const Center(child: CircularProgressIndicator())
          : _markets.isNotEmpty
              ? Column(children: _overviewRows())
              : const Text('no data to show')
    ]));
  }

  void _quoteAssetChange(String? asset) {
    if (asset == null) return;
    setState(() {
      _quoteAsset = asset;
      _markets = [];
      _retreivingData = true;
      _initMarkets();
    });
  }

  void _search(String value) {
    setState(() => _searchAsset = value);
  }

  void _exchChange(Exchange? exch) {
    if (exch == null) return;
    setState(() {
      _exchMarkets = [];
      _exch = exch;
      _exchData = createExchData(exch);
    });
  }

  void _initMarkets() {
    marketOverview(_quoteAsset).then((value) {
      if (value.err == null) {
        setState(() {
          _markets = value.markets;
          _retreivingData = false;
        });
      } else {
        var snackBar = SnackBar(
            content: Text('Unable to get market overview - ${value.err}'));
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    });
  }

  void _marketDetailShow(String baseAsset, String quoteAsset) {
    for (var market in _exchMarkets) {
      if (market.baseAsset == baseAsset &&
          (market.quoteAsset == quoteAsset ||
              market.quoteAsset == 'USDT' && quoteAsset == 'USD')) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ChangeNotifierProvider(
                    create: (context) => CandleChartModel(),
                    child: BasicScreen(ChartPage(_exch, market),
                        title: 'Chart Detail'))));
        return;
      }
    }
    var snackBar = SnackBar(
        content:
            Text('Unable find $baseAsset-$quoteAsset market on ${_exch.name}'));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _marketDetailTap(String baseAsset, String quoteAsset) {
    if (_exchMarkets.isEmpty) {
      _exchData.markets().then((value) {
        if (value.err == null) {
          _exchMarkets = value.markets;
          _marketDetailShow(baseAsset, quoteAsset);
        } else {
          var snackBar = SnackBar(
              content: Text('Unable to get exchange markets! - ${value.err}'));
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        }
      });
    } else {
      _marketDetailShow(baseAsset, quoteAsset);
    }
  }

  void _refreshData() {
    setState(() => _retreivingData = true);
    _initMarkets();
  }
}

class OverviewWidget extends StatefulWidget {
  final ExchMarket? market;
  final MarketInterval? interval;
  final List<CandleData>? candles1h;
  final MarketOverview? overview;
  final Function(String baseAsset, String quoteAsset) onMarketClick;

  const OverviewWidget(this.market, this.interval, this.candles1h,
      this.overview, this.onMarketClick,
      {super.key});
  factory OverviewWidget.exchMarket(
      ExchMarket market,
      MarketInterval interval,
      List<CandleData>? candles1h,
      Function(String baseAsset, String quoteAsset) onMarketClick) {
    return OverviewWidget(market, interval, candles1h, null, onMarketClick);
  }
  factory OverviewWidget.marketOverview(MarketOverview market,
      Function(String baseAsset, String quoteAsset) onMarketClick) {
    return OverviewWidget(null, null, null, market, onMarketClick);
  }

  @override
  OverviewWidgetState createState() => OverviewWidgetState();
}

class OverviewWidgetState extends State<OverviewWidget> {
  String _baseAsset = '';
  String _quoteAsset = '';
  double _price = 0;
  double _marketCap = 0;
  final NumberFormat _nfc = NumberFormat.compact();
  double _change1h = 0;
  double _change24h = 0;
  double _change7d = 0;
  List<double?> _sparkline7d = [];

  @override
  void initState() {
    super.initState();

    if (widget.market != null) {
      _baseAsset = widget.market!.baseAsset;
      _quoteAsset = widget.market!.quoteAsset;
      if (widget.candles1h != null) {
        _price = widget.candles1h!.last.close!;
        _sparkline7d = widget.candles1h!
            .skip(_sparkCandleIndex(widget.candles1h!))
            .map((e) => e.close)
            .toList();
        _change1h = _percentChange(1, widget.candles1h!);
        _change24h = _percentChange(24, widget.candles1h!);
        _change7d = _percentChange(168, widget.candles1h!);
      }
    } else if (widget.overview != null) {
      _baseAsset = widget.overview!.baseAsset;
      _quoteAsset = widget.overview!.quoteAsset;
      _price = widget.overview!.price;
      _marketCap = widget.overview!.marketCap;
      _sparkline7d = widget.overview!.sparkline7d;
      _change1h = widget.overview!.change1h;
      _change24h = widget.overview!.change24h;
      _change7d = widget.overview!.change7d;
    }
  }

  int _sparkCandleIndex(List<CandleData> candles1h) {
    // get the last week of data
    const hoursInWeek = 168;
    if (candles1h.length <= hoursInWeek) return 0;
    return candles1h.length - hoursInWeek;
  }

  double _percentChange(int numPeriods, List<CandleData> candles1h) {
    var startIndex = candles1h.length - 1 - numPeriods;
    var start = candles1h[startIndex].close;
    var end = candles1h[candles1h.length - 1].close;
    if (start == null || end == null) return 0;
    var diff = end - start;
    var avg = (start + end) / 2;
    return (diff / avg) * 100;
  }

  Widget _changeIndicator(double changePercent) {
    var upArrow = '▲';
    var downArrow = '▼';
    var changeStr = changePercent.toStringAsFixed(2);
    if (changePercent >= 0) {
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
          child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
            _baseAsset.isNotEmpty
                ? SvgPicture.network(svgUrl(_baseAsset.toLowerCase()),
                    placeholderBuilder: (context) =>
                        Image.asset('images/coin.png', width: 32, height: 32))
                : const SizedBox(),
            const SizedBox(width: 10),
            Text(_baseAsset)
          ]),
          onPressed: () => widget.onMarketClick(_baseAsset, _quoteAsset)))
    ];
    if (_sparkline7d.isNotEmpty) {
      rowWidgets.add(cell(SizedBox(
          width: 100,
          height: 30,
          child:
              CustomPaint(painter: SparkPainter(_sparkline7d, sparkColor)))));
      rowWidgets.add(cell(Text('${_nfc.format(_marketCap)} $_quoteAsset')));
      rowWidgets.add(cell(Text('${_price.toStringAsFixed(2)} $_quoteAsset')));
      rowWidgets.add(cell(_changeIndicator(_change1h)));
      rowWidgets.add(cell(_changeIndicator(_change24h)));
      rowWidgets.add(cell(_changeIndicator(_change7d)));
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
