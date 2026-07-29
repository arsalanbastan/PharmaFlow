import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final today = Jalali.now();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              // سمت راست
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [

                  const Text(
                    'سلام ارسلان 👋',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      // TODO: open calendar
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        const Icon(
                          Icons.calendar_month_outlined,
                          size: 18,
                        ),

                        const SizedBox(
                          width: 6,
                        ),

                        Text(
                          '${today.year}/${today.month}/${today.day}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),


              // سمت چپ
              const Row(
                children: [

                  Icon(
                    Icons.cloud_done_outlined,
                    size: 17,
                  ),

                  SizedBox(
                    width: 5,
                  ),

                  Text(
                    'آخرین سینک: همین الان',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}