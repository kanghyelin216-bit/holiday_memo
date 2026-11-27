import 'dart:convert';

import 'package:http/http.dart' as http;

class Holiday {
  final int date; // 20261225 형태
  final String name;
  final bool isHoliday;
  const Holiday(this.date, this.name, this.isHoliday);

  int get year => date ~/ 10000;
  int get month => (date ~/ 100) % 100;
  int get day => date % 100;

  String get label {
    const w = ['월', '화', '수', '목', '금', '토', '일'];
    final wd = w[DateTime(year, month, day).weekday - 1];
    return '$month월 $day일 ($wd)';
  }
}

class HolidayService {
  static const _apiKey = String.fromEnvironment('HOLIDAY_API_KEY');

  static Future<List<Holiday>> fetch(int year, int month) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'API 키가 없습니다. --dart-define=HOLIDAY_API_KEY=... 로 실행하세요.',
      );
    }
    final uri = Uri.https(
      'apis.data.go.kr',
      '/B090041/openapi/service/SpcdeInfoService/getRestDeInfo',
      {
        'serviceKey': _apiKey,
        'solYear': '$year',
        'solMonth': month.toString().padLeft(2, '0'),
        'numOfRows': '50',
        '_type': 'json',
      },
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('공휴일 API 오류 (HTTP ${res.statusCode})');
    }
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final header = json['response']['header'];
    if ('${header['resultCode']}' != '00') {
      throw Exception('API 응답 오류: ${header['resultMsg']}');
    }

    final items = json['response']['body']['items'];
    if (items == null || items == '') return [];
    final item = items['item'];
    final list = item is List ? item : [item];

    return list
        .map(
          (e) => Holiday(
            int.parse('${e['locdate']}'),
            '${e['dateName']}',
            '${e['isHoliday']}' == 'Y',
          ),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
}
