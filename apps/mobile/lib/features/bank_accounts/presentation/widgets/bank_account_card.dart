import 'package:flutter/material.dart';

import '../../../../data/models/bank_account.dart';

class BankAccountCard extends StatelessWidget {
  const BankAccountCard({
    super.key,
    required this.account,
    required this.onTap,
  });

  final BankAccount account;
  final VoidCallback onTap;

  String _maskedCardNumber(String? cardNumber) {
    if (cardNumber == null || cardNumber.trim().isEmpty) {
      return 'شماره کارت ثبت نشده';
    }

    final digits = cardNumber.replaceAll(' ', '');

    if (digits.length <= 4) {
      return digits;
    }

    return '**** **** **** ${digits.substring(digits.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      account.bankName,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account.accountTitle,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'صاحب حساب: ${account.accountHolder}',
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _maskedCardNumber(account.cardNumber),
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}