import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:interactive_chart/interactive_chart.dart';
import 'package:logging/logging.dart';
import 'package:universal_platform/universal_platform.dart';

final log = Logger('coin_data');

final supportedMarkets = ['BTC-USD', 'LTC-USD', 'LTC-BTC', 'ETH-USD', 'ETH-BTC', 'ZEC-USD', 'ZEC-BTC', 'XMR-USD', 'XMR-BTC'];

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

Future<String?> _get(String url) async {
  // https://docs.bitfinex.com
  url = 'https://api-pub.bitfinex.com/v2/$url';
  var uri = Uri.parse(url);
  if (UniversalPlatform.isWeb) {
    // CORS proxy server for web clients
    uri = Uri.parse(
        'https://api.allorigins.win/get?url=${Uri.encodeComponent(url)}');
  }
  var response = await http.get(uri);
  if (response.statusCode == 200) {
    if (UniversalPlatform.isWeb) {
      // strip content out of CORS proxy reponse
      var json = jsonDecode(response.body);
      return json['contents'];
    } else {
      return response.body;
    }
  } else {
    log.severe(response.reasonPhrase);
    return null;
  }
}

class CoinData {
  String source() {
    return 'Bitfinex';
  }

  Future<List<Market>> markets() async {
    List<Market> markets = [];
    var body = await _get('tickers?symbols=ALL');
    if (body != null) {
      var json = jsonDecode(body);
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
    }
    return markets;
  }

  Future<List<CandleData>> candles(String exchangeId, String interval) async {
    List<CandleData> data = [];
    var body =
        await _get('candles/trade:$interval:$exchangeId/hist?limit=10000&sort=-1');
    if (body != null) {
      var json = jsonDecode(body);
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
    }
    return data;
  }
}
