import 'package:shamsi_date/shamsi_date.dart';
import '../../shared/widgets/date_picker/pharmaflow_date_picker.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:price_increases_ui/price_increases_page.dart';
import '../../core/auth/staff_auth_token_storage.dart';

class StaffPriceIncreasesPage extends StatefulWidget {
  const StaffPriceIncreasesPage({super.key, this.canConfirm = true});
  final bool canConfirm;
  @override
  State<StaffPriceIncreasesPage> createState() =>
      _StaffPriceIncreasesPageState();
}

class _StaffPriceIncreasesPageState extends State<StaffPriceIncreasesPage> {
  final _client = http.Client();
  static const _base = String.fromEnvironment(
    'PHARMAFLOW_API_BASE_URL',
    defaultValue: 'https://naughty-haslett-zvtszb2yr.liara.run/api/v1',
  );
  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<Map<String, dynamic>> _request(
    String path,
    Map<String, dynamic>? body,
  ) async {
    final token = await StaffAuthTokenStorage().readToken();
    if (token == null || token.isEmpty)
      throw StateError('لطفاً دوباره وارد شوید.');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final patch = path.startsWith('PATCH:');
    final uri = Uri.parse('$_base${patch ? path.substring(6) : path}');
    final response =
        await (body == null
                ? _client.get(uri, headers: headers)
                : patch
                ? _client.patch(uri, headers: headers, body: jsonEncode(body))
                : _client.post(uri, headers: headers, body: jsonEncode(body)))
            .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw StateError('خطای سرور (${response.statusCode})');
    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
  }

  @override
  Widget build(BuildContext context) => PriceIncreasesPage(
    request: _request,
    pickDate: (context, initial) => PharmaFlowDatePicker.show(
      context: context,
      initialDate: initial,
      firstDate: Jalali(1390, 1, 1),
      lastDate: Jalali(1450, 12, 29),
    ),
    manager: false,
    canConfirm: widget.canConfirm,
  );
}
