import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/nutrition.dart';
import 'package:trainlog/i18n.dart';

class OffException implements Exception {
  OffException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Клиент Open Food Facts. Запросы идут напрямую с телефона; данные распространяются по лицензии ODbL.
class OffClient {
  OffClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _host = 'world.openfoodfacts.org';
  static const _fields = 'code,product_name,product_name_ru,brands,nutriments';
  static const _headers = {'User-Agent': 'TrainLog/1.0 (personal Android app)'};

  Future<Map<String, dynamic>> _get(Uri uri) async {
    try {
      final r = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
      if (r.statusCode == 404) return const {};
      if (r.statusCode != 200) throw OffException(tr('Open Food Facts ответил ошибкой {0}. Попробуйте позже.', [r.statusCode]));
      return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } on SocketException {
      throw OffException(tr('Нет соединения с интернетом. Доступны ручной ввод и сохранённые продукты.'));
    } on TimeoutException {
      throw OffException(tr('Open Food Facts не отвечает. Проверьте интернет и попробуйте ещё раз.'));
    } on http.ClientException {
      throw OffException(tr('Нет соединения с интернетом. Доступны ручной ввод и сохранённые продукты.'));
    } on FormatException {
      throw OffException(tr('Open Food Facts вернул некорректный ответ.'));
    }
  }

  /// Поиск по названию. Карточки без калорий отбрасываются.
  Future<List<OffProduct>> search(String query) async {
    final json = await _get(Uri.https(_host, '/cgi/search.pl', {
      'search_terms': query,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '30',
      'fields': _fields,
    }));
    final list = (json['products'] as List? ?? const []).whereType<Map<String, dynamic>>();
    return [
      for (final p in list)
        if (parseOffProduct(p) case final OffProduct ok) ok,
    ];
  }

  /// Поиск по штрихкоду. [found] — есть ли карточка; product == null при found — карточка без калорий.
  Future<({bool found, OffProduct? product})> byBarcode(String code) async {
    final json = await _get(Uri.https(_host, '/api/v2/product/$code.json', {'fields': _fields}));
    final p = json['product'];
    if (p is! Map<String, dynamic>) return (found: false, product: null);
    return (found: true, product: parseOffProduct({...p, 'code': p['code'] ?? code}));
  }
}
