import 'package:flutter/material.dart';
import '../widgets/jalali_commitment_calendar_view.dart';

class JalaliCommitmentCalendarPage extends StatelessWidget {
  const JalaliCommitmentCalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تقویم تعهدات')),
        body: const SafeArea(child: JalaliCommitmentCalendarView()),
      ),
    );
  }
}
