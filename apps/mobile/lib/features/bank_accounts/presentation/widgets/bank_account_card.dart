import 'package:flutter/material.dart';

import '../../../../data/models/bank_account.dart';

class BankAccountCard extends StatelessWidget {
  const BankAccountCard({
    super.key,
    required this.account,
    required this.onTap,
    required this.onCopyAccountNumber,
    required this.onCopyCardNumber,
    required this.onCopyIban,
    required this.onCopyAll,
    required this.onShare,
    this.onDelete,
  });

  final BankAccount account;
  final VoidCallback onTap;
  final VoidCallback onCopyAccountNumber;
  final VoidCallback onCopyCardNumber;
  final VoidCallback onCopyIban;
  final VoidCallback onCopyAll;
  final VoidCallback onShare;
  final VoidCallback? onDelete;

  String _accountNumberText(String accountNumber) {
    final normalized = accountNumber.trim();
    if (normalized.isEmpty) {
      return 'شماره حساب ثبت نشده';
    }

    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                        'شماره حساب: \u200E${_accountNumberText(account.accountNumber)}',
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_CardAction>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) {
                    switch (action) {
                      case _CardAction.copyAccountNumber:
                        onCopyAccountNumber();
                      case _CardAction.copyCardNumber:
                        onCopyCardNumber();
                      case _CardAction.copyIban:
                        onCopyIban();
                      case _CardAction.copyAll:
                        onCopyAll();
                      case _CardAction.share:
                        onShare();
                      case _CardAction.delete:
                        onDelete?.call();
                    }
                  },
                  itemBuilder: (context) {
                    final items = <PopupMenuEntry<_CardAction>>[
                      const PopupMenuItem<_CardAction>(
                        value: _CardAction.copyAccountNumber,
                        child: Text('کپی شماره حساب'),
                      ),
                      const PopupMenuItem<_CardAction>(
                        value: _CardAction.copyCardNumber,
                        child: Text('کپی شماره کارت'),
                      ),
                      const PopupMenuItem<_CardAction>(
                        value: _CardAction.copyIban,
                        child: Text('کپی شماره شبا'),
                      ),
                      const PopupMenuItem<_CardAction>(
                        value: _CardAction.copyAll,
                        child: Text('کپی همه اطلاعات'),
                      ),
                      const PopupMenuItem<_CardAction>(
                        value: _CardAction.share,
                        child: Text('اشتراک\u200cگذاری همه اطلاعات'),
                      ),
                    ];

                    if (onDelete != null) {
                      items.add(
                        const PopupMenuItem<_CardAction>(
                          value: _CardAction.delete,
                          child: Text('حذف'),
                        ),
                      );
                    }

                    return items;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _CardAction {
  copyAccountNumber,
  copyCardNumber,
  copyIban,
  copyAll,
  share,
  delete,
}