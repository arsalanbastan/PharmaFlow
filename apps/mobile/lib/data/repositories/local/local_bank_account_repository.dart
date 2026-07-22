import '../interfaces/bank_account_repository.dart';
import '../sqlite/sqlite_bank_account_repository.dart';

class LocalBankAccountRepository extends SqliteBankAccountRepository
    implements BankAccountRepository {
  LocalBankAccountRepository(super.databaseService);
}