// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'package:flart/config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:interactive_chart/interactive_chart.dart';
import 'package:logging/logging.dart';
import 'package:universal_platform/universal_platform.dart';

final log = Logger('coin_data');

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
  'XMR-BTC'
];

enum Exchange { Bitfinex, Binance }

enum MarketInterval {
  _5m,
  _1h,
  _1d,
  _1w,
  _1M;
}

class Market {
  final String exchangeId;
  final String baseAsset;
  final String quoteAsset;
  Market(this.exchangeId, this.baseAsset, this.quoteAsset);

  String symbol() {
    return '$baseAsset-$quoteAsset';
  }

  bool supported() {
    return supportedMarkets.contains(symbol());
  }

  factory Market.empty() => Market('', '', '');
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

class MarketsResult {
  List<Market> markets;
  String? err;
  MarketsResult(this.markets, {this.err});
  factory MarketsResult.err(String err) => MarketsResult([], err: err);
}

class CandlesResult {
  List<CandleData> candles;
  String? err;
  CandlesResult(this.candles, {this.err});
  factory CandlesResult.err(String err) => CandlesResult([], err: err);
}

abstract class ExchData {
  Future<MarketsResult> markets();
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
  Future<MarketsResult> markets() async {
    var result = await _get('tickers?symbols=ALL');
    if (result.err != null) return MarketsResult.err(result.err!);
    var json = jsonDecode(result.body);
    List<Market> markets = [];
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
      var market = Market(exchangeId, baseAsset, quoteAsset);
      if (market.supported()) markets.add(market);
    }
    return MarketsResult(markets);
  }

  @override
  String interval(MarketInterval int) {
    switch (int) {
      case MarketInterval._5m:
        return '5m';
      case MarketInterval._1h:
        return '1h';
      case MarketInterval._1d:
        return '1D';
      case MarketInterval._1w:
        return '1W';
      case MarketInterval._1M:
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
  Future<MarketsResult> markets() async {
    var result = await _get('exchangeInfo');
    if (result.err != null) return MarketsResult.err(result.err!);
    var json = jsonDecode(result.body);
    List<Market> markets = [];
    for (var item in json['symbols']) {
      var exchangeId = item['symbol'];
      String baseAsset = item['baseAsset'];
      String quoteAsset = item['quoteAsset'];
      var market = Market(exchangeId, baseAsset, quoteAsset);
      if (market.supported()) markets.add(market);
    }
    return MarketsResult(markets);
  }

  @override
  String interval(MarketInterval int) {
    switch (int) {
      case MarketInterval._5m:
        return '5m';
      case MarketInterval._1h:
        return '1h';
      case MarketInterval._1d:
        return '1d';
      case MarketInterval._1w:
        return '1w';
      case MarketInterval._1M:
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
