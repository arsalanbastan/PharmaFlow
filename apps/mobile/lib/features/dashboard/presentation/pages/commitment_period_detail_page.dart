import 'package:flutter/material.dart';

import '../../domain/models/commitment_period.dart';


class CommitmentPeriodDetailPage extends StatelessWidget {
  const CommitmentPeriodDetailPage({
    required this.period,
    super.key,
  });


  final CommitmentPeriod period;


  @override
  Widget build(BuildContext context) {

    return Directionality(
      textDirection: TextDirection.rtl,

      child: Scaffold(
        appBar: AppBar(
          title: Text(
            period.title,
          ),
        ),

        body: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [

                      Text(
                        period.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),


                      const SizedBox(
                        height: 8,
                      ),


                      Text(
                        'تاریخ دوره: '
                        '${period.startDate.year}/'
                        '${period.startDate.month}/'
                        '${period.startDate.day}'
                        ' تا '
                        '${period.endDate.year}/'
                        '${period.endDate.month}/'
                        '${period.endDate.day}',
                      ),


                      const SizedBox(
                        height: 12,
                      ),


                      Text(
                        'تعداد تعهدات: '
                        '${period.commitmentCount}',
                      ),


                      const SizedBox(
                        height: 6,
                      ),


                      Text(
                        'جمع مبلغ: '
                        '${period.totalAmount} ریال',
                      ),

                    ],
                  ),
                ),
              ),


              const SizedBox(
                height: 16,
              ),


              const Text(
                'تعهدات این دوره',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),


              const SizedBox(
                height: 8,
              ),


              const Expanded(
                child: Center(
                  child: Text(
                    'لیست تعهدات دوره در این بخش نمایش داده می‌شود',
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}