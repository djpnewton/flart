import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:interactive_chart/interactive_chart.dart';
import 'package:logging/logging.dart';
import 'package:universal_platform/universal_platform.dart';

final log = Logger('coin_data');

Future<String?> _get(String url) async {
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

Future<List<CandleData>> btcData() async {
  List<CandleData> data = [];
  // https://docs.bitfinex.com/reference/rest-public-candles
  var body = await _get(
      'https://api-pub.bitfinex.com/v2/candles/trade:1D:tBTCUSD/hist?limit=365&sort=-1');
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
