// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'package:flart/config.dart';
import 'package:http/http.dart' as http;
import 'package:interactive_chart/interactive_chart.dart';
import 'package:logging/logging.dart';
import 'package:universal_platform/universal_platform.dart';

final log = Logger('coin_data');

final quoteAssets = ['USD', 'BTC', 'ETH'];

final supportedMarkets = [
  'BTC-USD',
  'BTC-USDT',
  'LTC-USD',
  'LTC-USDT',
  'LTC-BTC',
  'ETH-USD',
  'ETH-USDT',
  'ETH-BTC',
  'ZEC-USD',
  'ZEC-USDT',
  'ZEC-BTC',
  'XMR-USD',
  'XMR-USDT',
  'XMR-BTC',
  'BCH-USD',
  'BCH-USDT',
  'BCH-BTC',
];

enum Exchange { Bitfinex, Binance }

enum MarketInterval {
  i5m,
  i1h,
  i1d,
  i1w,
  i1M;
}

String svgUrl(String coinSymbol) {
  return 'https://cdn.jsdelivr.net/gh/atomiclabs/cryptocurrency-icons@1a63530be6e374711a8554f31b17e4cb92c25fa5/svg/color/$coinSymbol.svg';
}

class MarketOverview {
  String name;
  String baseAsset;
  String quoteAsset;
  double price;
  double marketCap;
  int marketCapRank;
  double high24h;
  double low24h;
  double circulatingSupply;
  double change1h;
  double change24h;
  double change7d;
  List<double> sparkline7d;

  MarketOverview(
      this.name,
      this.baseAsset,
      this.quoteAsset,
      this.price,
      this.marketCap,
      this.marketCapRank,
      this.high24h,
      this.low24h,
      this.circulatingSupply,
      this.change1h,
      this.change24h,
      this.change7d,
      this.sparkline7d);
}

class MarketOverviewResult {
  List<MarketOverview> markets;
  String? err;
  MarketOverviewResult(this.markets, {this.err});
  factory MarketOverviewResult.err(String err) =>
      MarketOverviewResult([], err: err);
}

Future<MarketOverviewResult> marketOverview(String vsCurrency) async {
  var result = await httpGet(
      'https://api.coingecko.com/api/v3/coins/markets?vs_currency=${vsCurrency.toLowerCase()}&order=market_cap_desc&per_page=150&page=1&sparkline=true&price_change_percentage=1h%2C24h%2C7d');
  if (result.err != null) return MarketOverviewResult.err(result.err!);
  var json = jsonDecode(result.body);
  List<MarketOverview> markets = [];
  for (var item in json) {
    var sparkline = <double>[];
    for (var val in item['sparkline_in_7d']['price']) {
      sparkline.add(val);
    }
    var market = MarketOverview(
        item['name'],
        (item['symbol'] as String).toUpperCase(),
        vsCurrency.toUpperCase(),
        item['current_price'].toDouble(),
        item['market_cap'].toDouble(),
        item['market_cap_rank'],
        item['high_24h'].toDouble(),
        item['low_24h'].toDouble(),
        item['circulating_supply'].toDouble(),
        item['price_change_percentage_1h_in_currency'] ?? 0,
        item['price_change_percentage_24h_in_currency'] ?? 0,
        item['price_change_percentage_7d_in_currency'] ?? 0,
        sparkline);
    markets.add(market);
  }
  return MarketOverviewResult(markets);
}

class ExchMarket {
  final String exchangeId;
  final String baseAsset;
  final String quoteAsset;
  ExchMarket(this.exchangeId, this.baseAsset, this.quoteAsset);

  String symbol() {
    return '$baseAsset-$quoteAsset';
  }

  bool supported() {
    return supportedMarkets.contains(symbol());
  }

  factory ExchMarket.empty() => ExchMarket('', '', '');
}

class HttpGetResult {
  String body;
  String? err;
  HttpGetResult(this.body, {this.err});
  factory HttpGetResult.err(String err) => HttpGetResult('', err: err);
}

Future<HttpGetResult> httpGet(String url) async {
  var uri = Uri.parse(url);
  if (UniversalPlatform.isWeb || useCorsProxy) {
    // CORS proxy server for web clients
    uri = Uri.parse(
        'https://cors-proxy-q337.onrender.com/proxy?url=${Uri.encodeComponent(url)}');
  }
  var response = await http.get(uri);
  if (response.statusCode == 200) {
    return HttpGetResult(response.body);
  } else {
    log.severe(response.reasonPhrase);
    return HttpGetResult.err(response.reasonPhrase != null
        ? response.reasonPhrase!
        : response.statusCode.toString());
  }
}

ExchData createExchData(Exchange exch) {
  switch (exch) {
    case Exchange.Bitfinex:
      return BitfinexData();
    case Exchange.Binance:
      return BinanceData();
  }
}

class ExchMarketsResult {
  List<ExchMarket> markets;
  String? err;
  ExchMarketsResult(this.markets, {this.err});
  factory ExchMarketsResult.err(String err) => ExchMarketsResult([], err: err);
}

class CandlesResult {
  List<CandleData> candles;
  String? err;
  CandlesResult(this.candles, {this.err});
  factory CandlesResult.err(String err) => CandlesResult([], err: err);
}

abstract class ExchData {
  Future<ExchMarketsResult> markets();
  String interval(MarketInterval int);
  Future<CandlesResult> candles(String exchangeId, MarketInterval int);
}

class BitfinexData implements ExchData {
  // https://docs.bitfinex.com
  final String _baseUrl = 'https://api-pub.bitfinex.com/v2/';

  Future<HttpGetResult> _get(String url) async {
    return await httpGet('$_baseUrl$url');
  }

  @override
  Future<ExchMarketsResult> markets() async {
    var result = await _get('tickers?symbols=ALL');
    if (result.err != null) return ExchMarketsResult.err(result.err!);
    var json = jsonDecode(result.body);
    List<ExchMarket> markets = [];
    for (var item in json) {
      var exchangeId = item[0];
      if (exchangeId[0] != 't') continue;
      var pair = (exchangeId as String).substring(1);
      String baseAsset, quoteAsset;
      if (pair.length == 6) {
        baseAsset = pair.substring(0, 3);
        quoteAsset = pair.substring(3);
      } else {
        var parts = pair.split(':');
        if (parts.length != 2) continue;
        baseAsset = parts[0];
        quoteAsset = parts[1];
      }
      var market = ExchMarket(exchangeId, baseAsset, quoteAsset);
      if (market.supported()) markets.add(market);
    }
    return ExchMarketsResult(markets);
  }

  @override
  String interval(MarketInterval int) {
    switch (int) {
      case MarketInterval.i5m:
        return '5m';
      case MarketInterval.i1h:
        return '1h';
      case MarketInterval.i1d:
        return '1D';
      case MarketInterval.i1w:
        return '1W';
      case MarketInterval.i1M:
        return '1M';
    }
  }

  @override
  Future<CandlesResult> candles(String exchangeId, MarketInterval int) async {
    var result = await _get(
        'candles/trade:${interval(int)}:$exchangeId/hist?limit=1000&sort=-1');
    if (result.err != null) return CandlesResult.err(result.err!);
    var json = jsonDecode(result.body);
    List<CandleData> data = [];
    for (var item in json) {
      var candle = CandleData(
          timestamp: item[0],
          open: item[1].toDouble(),
          close: item[2].toDouble(),
          high: item[3].toDouble(),
          low: item[4].toDouble(),
          volume: item[5].toDouble());
      data.insert(0, candle);
    }
    return CandlesResult(data);
  }
}

class BinanceData implements ExchData {
  // https://binance-docs.github.io/apidocs
  final String _baseUrl = 'https://api.binance.com/api/v3/';

  Future<dynamic> _get(String url) async {
    return await httpGet('$_baseUrl$url');
  }

  @override
  Future<ExchMarketsResult> markets() async {
    var result = await _get('exchangeInfo');
    if (result.err != null) return ExchMarketsResult.err(result.err!);
    var json = jsonDecode(result.body);
    List<ExchMarket> markets = [];
    for (var item in json['symbols']) {
      var exchangeId = item['symbol'];
      String baseAsset = item['baseAsset'];
      String quoteAsset = item['quoteAsset'];
      var market = ExchMarket(exchangeId, baseAsset, quoteAsset);
      if (market.supported()) markets.add(market);
    }
    return ExchMarketsResult(markets);
  }

  @override
  String interval(MarketInterval int) {
    switch (int) {
      case MarketInterval.i5m:
        return '5m';
      case MarketInterval.i1h:
        return '1h';
      case MarketInterval.i1d:
        return '1d';
      case MarketInterval.i1w:
        return '1w';
      case MarketInterval.i1M:
        return '1M';
    }
  }

  @override
  Future<CandlesResult> candles(String exchangeId, MarketInterval int) async {
    var result = await _get(
        'klines?symbol=$exchangeId&interval=${interval(int)}&limit=1000');
    if (result.err != null) return CandlesResult.err(result.err!);
    var json = jsonDecode(result.body);
    List<CandleData> data = [];
    for (var item in json) {
      var candle = CandleData(
          timestamp: item[0],
          open: double.parse(item[1]),
          close: double.parse(item[4]),
          high: double.parse(item[2]),
          low: double.parse(item[3]),
          volume: double.parse(item[5]));
      data.add(candle);
    }
    return CandlesResult(data);
  }
}
