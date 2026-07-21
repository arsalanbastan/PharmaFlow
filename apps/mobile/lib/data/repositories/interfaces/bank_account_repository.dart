import '../../models/bank_account.dart';

abstract class BankAccountRepository {
  Future<List<BankAccount>> getAll({
    bool includeArchived = false,
  });

  Future<BankAccount?> getById(int id);

  Future<int> insert(BankAccount account);

  Future<void> update(BankAccount account);

  Future<void> archive(int id);

  Future<void> restore(int id);

  Future<void> delete(int id);
}