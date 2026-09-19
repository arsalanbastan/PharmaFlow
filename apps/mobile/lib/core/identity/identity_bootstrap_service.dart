import '../../data/models/bank_account.dart';
import '../../data/models/company.dart';
import '../../data/repositories/local/local_bank_account_repository.dart';
import '../../data/repositories/local/local_company_repository.dart';
import '../network/api_client.dart';
import '../network/api_constants.dart';
import 'bootstrap_result.dart';

class IdentityBootstrapService {
  IdentityBootstrapService({
    required this._apiClient,
    required this._localCompanyRepository,
    required this._localBankAccountRepository,
  });

  final ApiClient _apiClient;
  final LocalCompanyRepository _localCompanyRepository;
  final LocalBankAccountRepository _localBankAccountRepository;

  Future<BootstrapResult> bootstrap() async {
    final remoteCompanies = await _fetchRemoteCompanies();
    final remoteBankAccounts = await _fetchRemoteBankAccounts();

    final localCompanies = await _localCompanyRepository.getAll(
      includeArchived: true,
    );
    final localBankAccounts = await _localBankAccountRepository.getAll(
      includeArchived: true,
    );

    final matchedCompanies = <BootstrapMatch>[];
    final matchedBankAccounts = <BootstrapMatch>[];
    final companyConflicts = <BootstrapConflict>[];
    final bankConflicts = <BootstrapConflict>[];
    final companyUnresolved = <BootstrapUnresolved>[];
    final bankUnresolved = <BootstrapUnresolved>[];

    for (final localCompany in localCompanies) {
      final localId = localCompany.id;
      if (localId == null) {
        companyUnresolved.add(
          const BootstrapUnresolved(
            localId: -1,
            reason: 'Local company id is null.',
          ),
        );
        continue;
      }

      final resolution = _resolveCompany(localCompany, remoteCompanies);
      switch (resolution) {
        case _BootstrapUniqueMatch():
          await _localCompanyRepository.updateServerUuid(
            localId: localId,
            serverUuid: resolution.serverUuid,
          );
          matchedCompanies.add(
            BootstrapMatch(
              localId: localId,
              serverUuid: resolution.serverUuid,
              strategy: resolution.strategy,
            ),
          );
        case _BootstrapConflict():
          companyConflicts.add(
            BootstrapConflict(
              localId: localId,
              strategy: resolution.strategy,
              candidateServerUuids: resolution.candidateServerUuids,
            ),
          );
        case _BootstrapUnresolved():
          companyUnresolved.add(
            BootstrapUnresolved(localId: localId, reason: resolution.reason),
          );
      }
    }

    for (final localBankAccount in localBankAccounts) {
      final localId = localBankAccount.id;
      if (localId == null) {
        bankUnresolved.add(
          const BootstrapUnresolved(
            localId: -1,
            reason: 'Local bank account id is null.',
          ),
        );
        continue;
      }

      final resolution = _resolveBankAccount(
        localBankAccount,
        remoteBankAccounts,
      );
      switch (resolution) {
        case _BootstrapUniqueMatch():
          await _localBankAccountRepository.updateServerUuid(
            localId: localId,
            serverUuid: resolution.serverUuid,
          );
          matchedBankAccounts.add(
            BootstrapMatch(
              localId: localId,
              serverUuid: resolution.serverUuid,
              strategy: resolution.strategy,
            ),
          );
        case _BootstrapConflict():
          bankConflicts.add(
            BootstrapConflict(
              localId: localId,
              strategy: resolution.strategy,
              candidateServerUuids: resolution.candidateServerUuids,
            ),
          );
        case _BootstrapUnresolved():
          bankUnresolved.add(
            BootstrapUnresolved(localId: localId, reason: resolution.reason),
          );
      }
    }

    return BootstrapResult(
      matchedCompanies: matchedCompanies,
      matchedBankAccounts: matchedBankAccounts,
      companyConflicts: companyConflicts,
      bankConflicts: bankConflicts,
      companyUnresolved: companyUnresolved,
      bankUnresolved: bankUnresolved,
    );
  }

  Future<List<_RemoteCompany>> _fetchRemoteCompanies() async {
    final payload = await _apiClient.get(ApiConstants.companiesEndpoint);

    if (payload is! List) {
      throw const ApiDecodingException(
        'Expected companies endpoint to return a JSON list.',
      );
    }

    return payload
        .whereType<Map<String, dynamic>>()
        .map(_RemoteCompany.fromJson)
        .where((company) => company.uuid.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<_RemoteBankAccount>> _fetchRemoteBankAccounts() async {
    final payload = await _apiClient.get(ApiConstants.bankAccountsEndpoint);

    if (payload is! List) {
      throw const ApiDecodingException(
        'Expected bank accounts endpoint to return a JSON list.',
      );
    }

    return payload
        .whereType<Map<String, dynamic>>()
        .map(_RemoteBankAccount.fromJson)
        .where((account) => account.uuid.isNotEmpty)
        .toList(growable: false);
  }

  _BootstrapResolution _resolveCompany(
    Company local,
    List<_RemoteCompany> remoteCompanies,
  ) {
    final byNationalId = _normalizedIdentifier(local.nationalId);
    if (byNationalId != null) {
      final candidates = remoteCompanies
          .where((remote) {
            return _normalizedIdentifier(remote.nationalId) == byNationalId;
          })
          .toList(growable: false);

      final nationalIdResult = _asResolution(
        candidates,
        strategy: 'nationalId',
      );

      if (nationalIdResult != null) {
        return nationalIdResult;
      }
    }

    final byEconomicCode = _normalizedIdentifier(local.economicCode);
    if (byEconomicCode != null) {
      final candidates = remoteCompanies
          .where((remote) {
            return _normalizedIdentifier(remote.economicCode) == byEconomicCode;
          })
          .toList(growable: false);

      final economicCodeResult = _asResolution(
        candidates,
        strategy: 'economicCode',
      );

      if (economicCodeResult != null) {
        return economicCodeResult;
      }
    }

    final byName = _normalizeName(local.name);
    if (byName.isNotEmpty) {
      final candidates = remoteCompanies
          .where((remote) {
            return _normalizeName(remote.name) == byName;
          })
          .toList(growable: false);

      final nameResult = _asResolution(candidates, strategy: 'name');
      if (nameResult != null) {
        return nameResult;
      }
    }

    return const _BootstrapUnresolved(
      reason: 'No unique company match found by nationalId/economicCode/name.',
    );
  }

  _BootstrapResolution _resolveBankAccount(
    BankAccount local,
    List<_RemoteBankAccount> remoteAccounts,
  ) {
    final byIban = _normalizeIban(local.iban);
    if (byIban != null) {
      final candidates = remoteAccounts
          .where((remote) {
            return _normalizeIban(remote.iban) == byIban;
          })
          .toList(growable: false);

      final ibanResult = _asResolution(candidates, strategy: 'iban');
      if (ibanResult != null) {
        return ibanResult;
      }
    }

    final byAccountNumber = _normalizeDigits(local.accountNumber);
    if (byAccountNumber != null) {
      final candidates = remoteAccounts
          .where((remote) {
            return _normalizeDigits(remote.accountNumber) == byAccountNumber;
          })
          .toList(growable: false);

      final accountNumberResult = _asResolution(
        candidates,
        strategy: 'accountNumber',
      );
      if (accountNumberResult != null) {
        return accountNumberResult;
      }
    }

    final byCardNumber = _normalizeDigits(local.cardNumber);
    if (byCardNumber != null) {
      final candidates = remoteAccounts
          .where((remote) {
            return _normalizeDigits(remote.cardNumber) == byCardNumber;
          })
          .toList(growable: false);

      final cardNumberResult = _asResolution(
        candidates,
        strategy: 'cardNumber',
      );
      if (cardNumberResult != null) {
        return cardNumberResult;
      }
    }

    final localBankName = _normalizeName(local.bankName);
    final localAccountTitle = _normalizeName(local.accountTitle);
    if (localBankName.isNotEmpty && localAccountTitle.isNotEmpty) {
      final candidates = remoteAccounts
          .where((remote) {
            return _normalizeName(remote.bankName) == localBankName &&
                _normalizeName(remote.accountTitle) == localAccountTitle;
          })
          .toList(growable: false);

      final namePairResult = _asResolution(
        candidates,
        strategy: 'bankName+accountTitle',
      );
      if (namePairResult != null) {
        return namePairResult;
      }
    }

    return const _BootstrapUnresolved(
      reason:
          'No unique bank account match found by iban/accountNumber/cardNumber/bankName+accountTitle.',
    );
  }

  _BootstrapResolution? _asResolution(
    Iterable<_RemoteIdentityRecord> candidates, {
    required String strategy,
  }) {
    final candidateList = candidates.toList(growable: false);

    if (candidateList.isEmpty) {
      return null;
    }

    if (candidateList.length == 1) {
      return _BootstrapUniqueMatch(
        serverUuid: candidateList.first.uuid,
        strategy: strategy,
      );
    }

    return _BootstrapConflict(
      strategy: strategy,
      candidateServerUuids: candidateList.map((item) => item.uuid).toList(),
    );
  }

  String _normalizeName(String value) {
    return value
        .trim()
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('ة', 'ه')
        .replaceAll('\u200c', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
  }

  String? _normalizedIdentifier(String? value) {
    if (value == null) {
      return null;
    }

    final normalized = _normalizeDigits(value)
        ?.replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('ة', 'ه')
        .replaceAll('\u200c', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  String? _normalizeDigits(String? value) {
    if (value == null) {
      return null;
    }

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final buffer = StringBuffer();
    for (final codeUnit in trimmed.codeUnits) {
      buffer.write(_toEnglishDigit(codeUnit));
    }

    return buffer.toString().replaceAll(RegExp(r'\s+'), '');
  }

  String? _normalizeIban(String? value) {
    final normalized = _normalizeDigits(
      value,
    )?.replaceAll('-', '').replaceAll(' ', '').toUpperCase();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  String _toEnglishDigit(int codeUnit) {
    if (codeUnit >= 0x06F0 && codeUnit <= 0x06F9) {
      return String.fromCharCode(codeUnit - 0x06F0 + 0x30);
    }

    if (codeUnit >= 0x0660 && codeUnit <= 0x0669) {
      return String.fromCharCode(codeUnit - 0x0660 + 0x30);
    }

    return String.fromCharCode(codeUnit);
  }
}

sealed class _BootstrapResolution {
  const _BootstrapResolution();
}

class _BootstrapUniqueMatch extends _BootstrapResolution {
  const _BootstrapUniqueMatch({
    required this.serverUuid,
    required this.strategy,
  });

  final String serverUuid;
  final String strategy;
}

class _BootstrapConflict extends _BootstrapResolution {
  const _BootstrapConflict({
    required this.strategy,
    required this.candidateServerUuids,
  });

  final String strategy;
  final List<String> candidateServerUuids;
}

class _BootstrapUnresolved extends _BootstrapResolution {
  const _BootstrapUnresolved({required this.reason});

  final String reason;
}

abstract class _RemoteIdentityRecord {
  const _RemoteIdentityRecord(this.uuid);

  final String uuid;
}

class _RemoteCompany extends _RemoteIdentityRecord {
  const _RemoteCompany({
    required String uuid,
    required this.name,
    required this.nationalId,
    required this.economicCode,
  }) : super(uuid);

  final String name;
  final String? nationalId;
  final String? economicCode;

  factory _RemoteCompany.fromJson(Map<String, dynamic> json) {
    return _RemoteCompany(
      uuid: _readString(json, 'id') ?? '',
      name: _readString(json, 'name') ?? '',
      nationalId: _readString(json, 'nationalId', fallbackKey: 'national_id'),
      economicCode: _readString(
        json,
        'economicCode',
        fallbackKey: 'economic_code',
      ),
    );
  }
}

class _RemoteBankAccount extends _RemoteIdentityRecord {
  const _RemoteBankAccount({
    required String uuid,
    required this.bankName,
    required this.accountTitle,
    required this.accountNumber,
    required this.cardNumber,
    required this.iban,
  }) : super(uuid);

  final String bankName;
  final String accountTitle;
  final String? accountNumber;
  final String? cardNumber;
  final String? iban;

  factory _RemoteBankAccount.fromJson(Map<String, dynamic> json) {
    return _RemoteBankAccount(
      uuid: _readString(json, 'id') ?? '',
      bankName: _readString(json, 'bankName', fallbackKey: 'bank_name') ?? '',
      accountTitle:
          _readString(json, 'accountTitle', fallbackKey: 'account_title') ?? '',
      accountNumber: _readString(
        json,
        'accountNumber',
        fallbackKey: 'account_number',
      ),
      cardNumber: _readString(json, 'cardNumber', fallbackKey: 'card_number'),
      iban:
          _readString(json, 'iban', fallbackKey: 'shebaNumber') ??
          _readString(json, 'sheba_number'),
    );
  }
}

String? _readString(
  Map<String, dynamic> json,
  String key, {
  String? fallbackKey,
}) {
  final value = json[key] ?? (fallbackKey == null ? null : json[fallbackKey]);

  if (value == null) {
    return null;
  }

  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  return value.toString();
}
