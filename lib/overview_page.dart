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

const cellSizeMed = 100.0;
const smallDetailFontSize = 10.0;
const normalFontSize = 14.0;

class CellSize {
  double width;
  bool compact;
  CellSize(this.width, this.compact);
}

CellSize cellSize(double maxWidth) {
  const numCellsExpanded = 7;
  const numCellsCompact = 3;
  if (maxWidth >= numCellsExpanded * cellSizeMed) {
    return CellSize((maxWidth / numCellsExpanded).floorToDouble(), false);
  }
  return CellSize((maxWidth / numCellsCompact).floorToDouble(), true);
}

Widget cell(Widget? child, {required double size, Color? fillColor}) {
  var c = child != null ? Center(child: child) : null;
  if (fillColor != null) {
    return Container(color: fillColor, width: size, child: c);
  }
  return SizedBox(width: size, child: c);
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
    return LayoutBuilder(builder: (context, constraints) {
      return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Refresh: '),
              IconButton(
                  onPressed: _refreshData, icon: const Icon(Icons.refresh))
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Quote asset: '),
              DropdownButton<String>(
                  items: quoteAssets
                      .map((e) =>
                          DropdownMenuItem<String>(value: e, child: Text(e)))
                      .toList(),
                  value: _quoteAsset,
                  onChanged: _quoteAssetChange),
            ]),
            SearchInput(_search),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Show detail using: '),
              DropdownButton<Exchange>(
                  items: Exchange.values
                      .map((e) => DropdownMenuItem<Exchange>(
                          value: e, child: Text(e.name)))
                      .toList(),
                  value: _exch,
                  onChanged: _exchChange)
            ])
          ]);
    });
  }

  Widget _headerRow() {
    return LayoutBuilder(builder: (context, constraints) {
      var size = cellSize(constraints.maxWidth);
      if (size.compact) return const SizedBox();
      var ts = const TextStyle(decoration: TextDecoration.underline);
      var rowWidgets = <Widget>[
        cell(Text('Market', style: ts), size: size.width),
        cell(Text('Last 7 days', style: ts), size: size.width),
        cell(Text('Price ($_quoteAsset)', style: ts), size: size.width),
      ];
      rowWidgets.add(cell(Text('1h %', style: ts), size: size.width));
      rowWidgets.add(cell(Text('1d %', style: ts), size: size.width));
      rowWidgets.add(cell(Text('1w %', style: ts), size: size.width));
      rowWidgets.add(
          cell(Text('Market Cap ($_quoteAsset)', style: ts), size: size.width));
      return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: rowWidgets);
    });
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
    return Column(children: [
      _makeControls(),
      _headerRow(),
      _retreivingData
          ? const Center(child: CircularProgressIndicator())
          : _markets.isNotEmpty
              ? Expanded(child: ListView(children: _overviewRows()))
              : const Text('no data to show')
    ]);
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

  Widget _changeIndicator(double changePercent, {String? smallDetail}) {
    var ts = TextStyle(
        fontSize: smallDetail != null ? smallDetailFontSize : normalFontSize,
        color: changePercent >= 0 ? Colors.green : Colors.red);
    var upArrow = '▲';
    var downArrow = '▼';
    var changeStr = changePercent.toStringAsFixed(2);
    var detail = smallDetail != null ? ' $smallDetail' : '';
    if (changePercent >= 0) {
      return Text('$upArrow $changeStr%$detail', style: ts);
    } else {
      return Text('$downArrow $changeStr%$detail', style: ts);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      var size = cellSize(constraints.maxWidth);
      var iconSize = size.width < cellSizeMed ? 24.0 : 32.0;
      var sparklineHeight = size.compact ? 50.0 : 30.0;
      const sparkColor = Colors.blue;
      var rowWidgets = [
        cell(
            TextButton(
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                  _baseAsset.isNotEmpty
                      ? SvgPicture.network(svgUrl(_baseAsset.toLowerCase()),
                          width: iconSize,
                          height: iconSize,
                          placeholderBuilder: (context) => Image.asset(
                              'images/coin.png',
                              width: iconSize,
                              height: iconSize))
                      : const SizedBox(),
                  const SizedBox(width: 5),
                  Expanded(
                      child: Text(_baseAsset,
                          maxLines: 1, overflow: TextOverflow.fade))
                ]),
                onPressed: () => widget.onMarketClick(_baseAsset, _quoteAsset)),
            size: size.width)
      ];
      if (_sparkline7d.isNotEmpty) {
        var sparkline = SizedBox(
            width: size.width,
            height: sparklineHeight,
            child:
                CustomPaint(painter: SparkPainter(_sparkline7d, sparkColor)));
        if (!size.compact) {
          rowWidgets.add(cell(sparkline, size: size.width));
          rowWidgets
              .add(cell(Text(_price.toStringAsFixed(2)), size: size.width));
          rowWidgets.add(cell(_changeIndicator(_change1h), size: size.width));
          rowWidgets.add(cell(_changeIndicator(_change24h), size: size.width));
          rowWidgets.add(cell(_changeIndicator(_change7d), size: size.width));
          rowWidgets.add(cell(Text(_nfc.format(_marketCap)), size: size.width));
        } else {
          var gradientColor = Theme.of(context).colorScheme.surface;
          var sparkPrice = Stack(children: [
            sparkline,
            Container(
                height: sparklineHeight,
                alignment: Alignment.bottomCenter,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        gradientColor.withAlpha(0),
                        gradientColor.withAlpha(50),
                        gradientColor.withAlpha(100)
                      ]),
                ),
                child: Text('${_price.toStringAsFixed(2)} $_quoteAsset\n1w',
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center)),
          ]);
          rowWidgets.add(cell(sparkPrice, size: size.width));
          var detailsCol = Column(children: [
            _changeIndicator(_change1h, smallDetail: '1h'),
            _changeIndicator(_change24h, smallDetail: '1d'),
            _changeIndicator(_change7d, smallDetail: '1w'),
            Text('${_nfc.format(_marketCap)} Cap',
                style: const TextStyle(fontSize: smallDetailFontSize))
          ]);
          rowWidgets.add(cell(detailsCol, size: size.width));
        }
      } else {
        rowWidgets
            .add(cell(const CircularProgressIndicator(), size: size.width));
        rowWidgets.add(cell(null, size: size.width));
      }
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: rowWidgets));
    });
  }
}
