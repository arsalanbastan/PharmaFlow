enum WarningLevel {
  info,
  warning,
  critical,
}


class DashboardWarning {
  final String message;
  final WarningLevel level;

  const DashboardWarning({
    required this.message,
    required this.level,
  });
}