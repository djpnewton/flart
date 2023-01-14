import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:interactive_chart/interactive_chart.dart';
import 'package:logging/logging.dart';

final log = Logger('coin_data');

Future<List<CandleData>> btcData() async {
  List<CandleData> data = [];
  // https://docs.bitfinex.com/reference/rest-public-candles
  var response = await http.get(Uri.parse(
      'https://api-pub.bitfinex.com/v2/candles/trade:1D:tBTCUSD/hist?limit=365&sort=-1'));
  if (response.statusCode == 200) {
    var json = jsonDecode(response.body);
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
  } else {
    log.severe(response.reasonPhrase);
  }
  return data;
}
