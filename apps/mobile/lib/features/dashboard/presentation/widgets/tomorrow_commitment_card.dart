import 'package:flutter/material.dart';

class TomorrowCommitmentCard extends StatelessWidget {
  const TomorrowCommitmentCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,

      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.black.withValues(alpha: 0.05),
            width: 0.8,
          ),
        ),

        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [
              const Text(
                'تعهدات فردا',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 8),

              const SizedBox(
                height: 30,
                child: _BankCommitmentRow(
                  bankName: 'حساب جاری رفاه',
                  amount: '123,454,000 ریال',
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Divider(
                  height: 1,
                  thickness: 0.6,
                  color: Color(0x1A000000),
                ),
              ),

              const SizedBox(
                height: 30,
                child: _BankCommitmentRow(
                  bankName: 'حساب سامان آدورا',
                  amount: '56,898,000 ریال',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BankCommitmentRow extends StatelessWidget {
  const _BankCommitmentRow({required this.bankName, required this.amount});

  final String bankName;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,

      children: [
        Expanded(
          child: Row(
            children: [
              const Icon(Icons.account_balance_outlined, size: 16),

              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  bankName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        Text(
          amount,
          textAlign: TextAlign.left,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
