import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_service.dart';
import '../../../../data/models/bank_account.dart';
import '../../../../data/models/company.dart';
import '../../../../data/models/cheque.dart';
import '../../../../data/repositories/local/local_bank_account_repository.dart';
import '../../../../data/repositories/local/local_cheque_repository.dart';
import '../../../../data/repositories/local/local_company_repository.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/sqlite_dashboard_repository.dart';
import '../../domain/models/commitment_day_summary.dart';
import '../../domain/models/commitment_company_summary.dart';
import '../../domain/models/dashboard_summary.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return SqliteDashboardRepository();
});

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);

  return repository.getDashboardSummary();
});

class CommitmentPeriodRange {
  final DateTime startDate;
  final DateTime endDate;

  const CommitmentPeriodRange({required this.startDate, required this.endDate});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is CommitmentPeriodRange &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(startDate, endDate);
}

final commitmentDaysByPeriodProvider =
    FutureProvider.family<List<CommitmentDaySummary>, CommitmentPeriodRange>((
      ref,
      range,
    ) async {
      final repository = ref.watch(dashboardRepositoryProvider);

      return repository.getCommitmentDaysByPeriod(
        range.startDate,
        range.endDate,
      );
    });

class CommitmentDayRange {
  final DateTime dayStart;
  final DateTime dayEnd;

  const CommitmentDayRange({required this.dayStart, required this.dayEnd});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is CommitmentDayRange &&
        other.dayStart == dayStart &&
        other.dayEnd == dayEnd;
  }

  @override
  int get hashCode => Object.hash(dayStart, dayEnd);
}

final commitmentCompaniesByDayProvider =
    FutureProvider.family<List<CommitmentCompanySummary>, CommitmentDayRange>((
      ref,
      range,
    ) async {
      final repository = ref.watch(dashboardRepositoryProvider);

      return repository.getCommitmentCompaniesByDay(
        range.dayStart,
        range.dayEnd,
      );
    });

typedef UnregisteredChequesCardData = ({
  List<Cheque> cheques,
  Map<int, String> companyNames,
  Map<int, String> bankAccountNames,
});

final unregisteredChequesCardProvider =
    FutureProvider<UnregisteredChequesCardData>((ref) async {
      final dashboardRepository = ref.watch(dashboardRepositoryProvider);
      final companyRepository = LocalCompanyRepository(
        DatabaseService.instance,
      );
      final bankAccountRepository = LocalBankAccountRepository(
        DatabaseService.instance,
      );

      final results = await Future.wait([
        dashboardRepository.getUnregisteredCheques(),
        companyRepository.getAll(),
        bankAccountRepository.getAll(),
      ]);

      final cheques = results[0] as List<Cheque>;
      final companies = results[1] as List<Company>;
      final bankAccounts = results[2] as List<BankAccount>;

      final companyNames = <int, String>{
        for (final company in companies)
          if (company.id != null) company.id!: company.name,
      };

      final bankAccountNames = <int, String>{
        for (final account in bankAccounts)
          if (account.id != null) account.id!: account.accountTitle,
      };

      return (
        cheques: cheques,
        companyNames: companyNames,
        bankAccountNames: bankAccountNames,
      );
    });

final markChequeAsRegisteredProvider =
    Provider<Future<void> Function(Cheque cheque)>((ref) {
      final chequeRepository = LocalChequeRepository(DatabaseService.instance);

      return (Cheque cheque) async {
        await chequeRepository.update(
          cheque.copyWith(isRegisteredInSayad: true, updatedAt: DateTime.now()),
        );

        ref.invalidate(unregisteredChequesCardProvider);
        ref.invalidate(dashboardSummaryProvider);
      };
    });
