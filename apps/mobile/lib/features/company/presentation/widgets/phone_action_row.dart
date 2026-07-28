import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PhoneActionRow extends StatelessWidget {
  const PhoneActionRow({super.key, required this.phoneNumber});

  final String phoneNumber;

  Future<void> _launchUri(BuildContext context, Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('امکان باز کردن لینک در این دستگاه وجود ندارد.'),
          ),
        );
      }
    }
  }

  String _normalizeWhatsAppNumber(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('09')) {
      return '98${digits.substring(1)}';
    }

    return digits;
  }

  Future<void> _handleCall(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber.trim());
    await _launchUri(context, uri);
  }

  Future<void> _handleSms(BuildContext context) async {
    final uri = Uri(scheme: 'sms', path: phoneNumber.trim());
    await _launchUri(context, uri);
  }

  Future<void> _handleWhatsApp(BuildContext context) async {
    final normalizedNumber = _normalizeWhatsAppNumber(phoneNumber.trim());

    if (normalizedNumber.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('واتساپ روی این دستگاه نصب نیست.')),
        );
      }
      return;
    }

    final uri = Uri.parse('https://wa.me/$normalizedNumber');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('واتساپ روی این دستگاه نصب نیست.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanPhone = phoneNumber.trim();

    if (cleanPhone.isEmpty) {
      return const SizedBox.shrink();
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Text(
              cleanPhone,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => _handleWhatsApp(context),
            icon: const FaIcon(FontAwesomeIcons.whatsapp),
            tooltip: 'واتساپ',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          IconButton(
            onPressed: () => _handleSms(context),
            icon: const Icon(Icons.sms),
            tooltip: 'پیامک',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          IconButton(
            onPressed: () => _handleCall(context),
            icon: const Icon(Icons.phone),
            tooltip: 'تماس',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
