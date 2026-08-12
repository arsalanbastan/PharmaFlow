import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:pharmaflow/core/config/app_config.dart';
import 'package:pharmaflow/core/config/app_environment.dart';
import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/core/network/api_constants.dart';
import 'package:pharmaflow/core/settings/connection_settings_repository.dart';
import 'package:pharmaflow/data/models/bank_account.dart';
import 'package:pharmaflow/data/models/cheque.dart';
import 'package:pharmaflow/data/models/company.dart';
import 'package:pharmaflow/data/repositories/local/local_bank_account_repository.dart';
import 'package:pharmaflow/data/repositories/local/local_cheque_repository.dart';
import 'package:pharmaflow/data/repositories/local/local_company_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_cheque_repository.dart';

class _RemoteCompanyRecord {
  const _RemoteCompanyRecord({
    required this.uuid,
    required this.name,
    required this.nationalId,
    required this.economicCode,
  });

  final String uuid;
  final String name;
  final String? nationalId;
  final String? economicCode;
}

class _RemoteBankAccountRecord {
  const _RemoteBankAccountRecord({
    required this.uuid,
    required this.iban,
    required this.accountNumber,
    required this.cardNumber,
    required this.bankName,
    required this.accountTitle,
  });

  final String uuid;
  final String? iban;
  final String? accountNumber;
  final String? cardNumber;
  final String? bankName;
  final String? accountTitle;
}

class _Decision {
  const _Decision({
    required this.entityType,
    required this.localId,
    required this.oldServerUuid,
    required this.matchedRemoteUuid,
    required this.matchConfidence,
    required this.reason,
  });

  final String entityType;
  final int localId;
  final String? oldServerUuid;
  final String? matchedRemoteUuid;
  final String matchConfidence;
  final String reason;

  bool get isMatched => matchedRemoteUuid != null;

  Map<String, dynamic> toJson() {
    return {
      'entityType': entityType,
      'localId': localId,
      'oldServerUuid': oldServerUuid,
      'matchedRemoteUuid': matchedRemoteUuid,
      'matchConfidence': matchConfidence,
      'reason': reason,
    };
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.initialize();

  final settingsRepository = ConnectionSettingsRepository();
  final settings = await settingsRepository.load();
  final apiClient = ApiClient(
    appConfig: AppConfig(
      currentEnvironment: AppEnvironment.development,
      settings: settings,
    ),
  );

  final localCompanyRepository = LocalCompanyRepository(
    DatabaseService.instance,
  );
  final localBankAccountRepository = LocalBankAccountRepository(
    DatabaseService.instance,
  );
  final localChequeRepository = LocalChequeRepository(DatabaseService.instance);
  final remoteChequeRepository = RemoteChequeRepository(apiClient);

  final localCompanies = await localCompanyRepository.getAll(
    includeArchived: true,
  );
  final localBankAccounts = await localBankAccountRepository.getAll(
    includeArchived: true,
  );
  final localCheques = await localChequeRepository.getAll(
    includeArchived: true,
    includeCancelled: true,
  );

  final remoteCompanies = await _fetchRemoteCompanies(apiClient);
  final remoteBankAccounts = await _fetchRemoteBankAccounts(apiClient);
  final remoteCheques = await remoteChequeRepository.getAll();

  final companyDecisions = <_Decision>[];
  final bankDecisions = <_Decision>[];
  final chequeDecisions = <_Decision>[];

  for (final company in localCompanies) {
    final localId = company.id;
    if (localId == null) {
      continue;
    }

    final existingUuid = _trimOrNull(company.serverUuid);
    if (existingUuid != null) {
      continue;
    }

    companyDecisions.add(_reconcileCompany(company, remoteCompanies));
  }

  for (final bankAccount in localBankAccounts) {
    final localId = bankAccount.id;
    if (localId == null) {
      continue;
    }

    final existingUuid = _trimOrNull(bankAccount.serverUuid);
    if (existingUuid != null) {
      continue;
    }

    bankDecisions.add(_reconcileBankAccount(bankAccount, remoteBankAccounts));
  }

  final bankUuidByLocalId = <int, String>{
    for (final bank in localBankAccounts)
      if (bank.id != null && _trimOrNull(bank.serverUuid) != null)
        bank.id!: _trimOrNull(bank.serverUuid)!,
  };

  for (final decision in bankDecisions.where((entry) => entry.isMatched)) {
    bankUuidByLocalId[decision.localId] = decision.matchedRemoteUuid!;
  }

  for (final cheque in localCheques) {
    final existingUuid = _trimOrNull(cheque.serverUuid);
    if (existingUuid != null) {
      continue;
    }

    chequeDecisions.add(
      _reconcileCheque(
        cheque,
        bankUuidByLocalId: bankUuidByLocalId,
        remoteCheques: remoteCheques,
      ),
    );
  }

  final allDecisions = <_Decision>[
    ...companyDecisions,
    ...bankDecisions,
    ...chequeDecisions,
  ];

  final reportFile = File('reconciliation_report.json');
  final reportPayload = {
    'generatedAt': DateTime.now().toIso8601String(),
    'summary': {
      'companies': {
        'matched': companyDecisions.where((entry) => entry.isMatched).length,
        'unresolved': companyDecisions
            .where((entry) => !entry.isMatched)
            .length,
      },
      'bankAccounts': {
        'matched': bankDecisions.where((entry) => entry.isMatched).length,
        'unresolved': bankDecisions.where((entry) => !entry.isMatched).length,
      },
      'cheques': {
        'matched': chequeDecisions.where((entry) => entry.isMatched).length,
        'unresolved': chequeDecisions.where((entry) => !entry.isMatched).length,
      },
    },
    'entries': allDecisions.map((entry) => entry.toJson()).toList(),
  };

  await reportFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(reportPayload),
  );

  for (final decision in companyDecisions.where((entry) => entry.isMatched)) {
    await localCompanyRepository.updateServerUuid(
      localId: decision.localId,
      serverUuid: decision.matchedRemoteUuid!,
    );
  }

  for (final decision in bankDecisions.where((entry) => entry.isMatched)) {
    await localBankAccountRepository.updateServerUuid(
      localId: decision.localId,
      serverUuid: decision.matchedRemoteUuid!,
    );
  }

  for (final decision in chequeDecisions.where((entry) => entry.isMatched)) {
    await localChequeRepository.updateServerUuid(
      id: decision.localId,
      serverUuid: decision.matchedRemoteUuid!,
    );
  }

  stdout.writeln('Companies:');
  stdout.writeln(
    'matched count = ${companyDecisions.where((entry) => entry.isMatched).length}',
  );
  stdout.writeln(
    'unresolved count = ${companyDecisions.where((entry) => !entry.isMatched).length}',
  );

  stdout.writeln('Bank Accounts:');
  stdout.writeln(
    'matched count = ${bankDecisions.where((entry) => entry.isMatched).length}',
  );
  stdout.writeln(
    'unresolved count = ${bankDecisions.where((entry) => !entry.isMatched).length}',
  );

  stdout.writeln('Cheques:');
  stdout.writeln(
    'matched count = ${chequeDecisions.where((entry) => entry.isMatched).length}',
  );
  stdout.writeln(
    'unresolved count = ${chequeDecisions.where((entry) => !entry.isMatched).length}',
  );

  stdout.writeln('Report file: ${reportFile.absolute.path}');
}

_Decision _reconcileCompany(Company local, List<_RemoteCompanyRecord> remotes) {
  final localId = local.id!;

  final normalizedLocalName = _normalizeText(local.name);
  final byName = remotes
      .where((remote) {
        return _normalizeText(remote.name) == normalizedLocalName;
      })
      .toList(growable: false);

  if (byName.length == 1) {
    return _Decision(
      entityType: 'Company',
      localId: localId,
      oldServerUuid: _trimOrNull(local.serverUuid),
      matchedRemoteUuid: byName.first.uuid,
      matchConfidence: 'high',
      reason: 'Unique normalized name match.',
    );
  }

  if (byName.length > 1) {
    final bySecondary = _filterCompaniesBySecondary(local, byName);
    if (bySecondary.length == 1) {
      return _Decision(
        entityType: 'Company',
        localId: localId,
        oldServerUuid: _trimOrNull(local.serverUuid),
        matchedRemoteUuid: bySecondary.first.uuid,
        matchConfidence: 'medium',
        reason:
            'Ambiguous name resolved by secondary identity (nationalId/economicCode).',
      );
    }

    return _Decision(
      entityType: 'Company',
      localId: localId,
      oldServerUuid: _trimOrNull(local.serverUuid),
      matchedRemoteUuid: null,
      matchConfidence: 'none',
      reason:
          'Multiple normalized name matches and secondary identity is not unique.',
    );
  }

  final bySecondary = _filterCompaniesBySecondary(local, remotes);
  if (bySecondary.length == 1) {
    return _Decision(
      entityType: 'Company',
      localId: localId,
      oldServerUuid: _trimOrNull(local.serverUuid),
      matchedRemoteUuid: bySecondary.first.uuid,
      matchConfidence: 'medium',
      reason: 'Unique secondary identity match (nationalId/economicCode).',
    );
  }

  if (bySecondary.length > 1) {
    return _Decision(
      entityType: 'Company',
      localId: localId,
      oldServerUuid: _trimOrNull(local.serverUuid),
      matchedRemoteUuid: null,
      matchConfidence: 'none',
      reason: 'Multiple secondary identity matches.',
    );
  }

  return _Decision(
    entityType: 'Company',
    localId: localId,
    oldServerUuid: _trimOrNull(local.serverUuid),
    matchedRemoteUuid: null,
    matchConfidence: 'none',
    reason: 'No normalized name or secondary identity match.',
  );
}

List<_RemoteCompanyRecord> _filterCompaniesBySecondary(
  Company local,
  List<_RemoteCompanyRecord> candidates,
) {
  final localNationalId = _normalizeToken(local.nationalId);
  final localEconomicCode = _normalizeToken(local.economicCode);

  if (localNationalId == null && localEconomicCode == null) {
    return const <_RemoteCompanyRecord>[];
  }

  return candidates
      .where((remote) {
        final remoteNationalId = _normalizeToken(remote.nationalId);
        final remoteEconomicCode = _normalizeToken(remote.economicCode);

        final nationalMatched =
            localNationalId != null && remoteNationalId == localNationalId;
        final economicMatched =
            localEconomicCode != null &&
            remoteEconomicCode == localEconomicCode;

        return nationalMatched || economicMatched;
      })
      .toList(growable: false);
}

_Decision _reconcileBankAccount(
  BankAccount local,
  List<_RemoteBankAccountRecord> remotes,
) {
  final localId = local.id!;

  final checks =
      <
        ({
          String label,
          String? localValue,
          String? Function(_RemoteBankAccountRecord remote) remoteValue,
          String confidence,
        })
      >[
        (
          label: 'IBAN/Sheba',
          localValue: _normalizeToken(local.iban),
          remoteValue: (remote) => _normalizeToken(remote.iban),
          confidence: 'high',
        ),
        (
          label: 'Account Number',
          localValue: _normalizeToken(local.accountNumber),
          remoteValue: (remote) => _normalizeToken(remote.accountNumber),
          confidence: 'medium',
        ),
        (
          label: 'Card Number',
          localValue: _normalizeToken(local.cardNumber),
          remoteValue: (remote) => _normalizeToken(remote.cardNumber),
          confidence: 'medium',
        ),
        (
          label: 'Bank Name',
          localValue: _normalizeText(local.bankName),
          remoteValue: (remote) => _normalizeTextOrNull(remote.bankName),
          confidence: 'low',
        ),
        (
          label: 'Account Title',
          localValue: _normalizeText(local.accountTitle),
          remoteValue: (remote) => _normalizeTextOrNull(remote.accountTitle),
          confidence: 'low',
        ),
      ];

  for (final check in checks) {
    final localValue = check.localValue;
    if (localValue == null || localValue.isEmpty) {
      continue;
    }

    final matched = remotes
        .where((remote) {
          return check.remoteValue(remote) == localValue;
        })
        .toList(growable: false);

    if (matched.length == 1) {
      return _Decision(
        entityType: 'BankAccount',
        localId: localId,
        oldServerUuid: _trimOrNull(local.serverUuid),
        matchedRemoteUuid: matched.first.uuid,
        matchConfidence: check.confidence,
        reason: 'Unique ${check.label} match.',
      );
    }

    if (matched.length > 1) {
      return _Decision(
        entityType: 'BankAccount',
        localId: localId,
        oldServerUuid: _trimOrNull(local.serverUuid),
        matchedRemoteUuid: null,
        matchConfidence: 'none',
        reason: 'Ambiguous ${check.label} match (${matched.length} records).',
      );
    }
  }

  return _Decision(
    entityType: 'BankAccount',
    localId: localId,
    oldServerUuid: _trimOrNull(local.serverUuid),
    matchedRemoteUuid: null,
    matchConfidence: 'none',
    reason: 'No match found across IBAN/account/card/bank name/account title.',
  );
}

_Decision _reconcileCheque(
  Cheque local, {
  required Map<int, String> bankUuidByLocalId,
  required List<RemoteChequeRecord> remoteCheques,
}) {
  final bankUuid = bankUuidByLocalId[local.bankAccountId];

  if (bankUuid == null || bankUuid.trim().isEmpty) {
    return _Decision(
      entityType: 'Cheque',
      localId: local.id,
      oldServerUuid: _trimOrNull(local.serverUuid),
      matchedRemoteUuid: null,
      matchConfidence: 'none',
      reason:
          'Local bank account UUID is missing; cannot match by ADR-003 identity.',
    );
  }

  final normalizedChequeNumber = _normalizeToken(local.chequeNumber);
  final matched = remoteCheques
      .where((remote) {
        return remote.bankAccountId.trim() == bankUuid.trim() &&
            _normalizeToken(remote.chequeNumber) == normalizedChequeNumber;
      })
      .toList(growable: false);

  if (matched.length == 1) {
    return _Decision(
      entityType: 'Cheque',
      localId: local.id,
      oldServerUuid: _trimOrNull(local.serverUuid),
      matchedRemoteUuid: matched.first.id,
      matchConfidence: 'high',
      reason: 'Unique match by bankAccount UUID + chequeNumber.',
    );
  }

  if (matched.isEmpty) {
    return _Decision(
      entityType: 'Cheque',
      localId: local.id,
      oldServerUuid: _trimOrNull(local.serverUuid),
      matchedRemoteUuid: null,
      matchConfidence: 'none',
      reason: 'No remote cheque found by bankAccount UUID + chequeNumber.',
    );
  }

  return _Decision(
    entityType: 'Cheque',
    localId: local.id,
    oldServerUuid: _trimOrNull(local.serverUuid),
    matchedRemoteUuid: null,
    matchConfidence: 'none',
    reason: 'Multiple remote cheques found by bankAccount UUID + chequeNumber.',
  );
}

Future<List<_RemoteCompanyRecord>> _fetchRemoteCompanies(
  ApiClient client,
) async {
  final payload = await client.get(ApiConstants.companiesEndpoint);
  if (payload is! List) {
    return const <_RemoteCompanyRecord>[];
  }

  final results = <_RemoteCompanyRecord>[];

  for (final entry in payload) {
    if (entry is! Map<String, dynamic>) {
      continue;
    }

    final uuid = _readString(entry, 'id');
    final name = _readString(entry, 'name');

    if (uuid == null || uuid.isEmpty || name == null || name.isEmpty) {
      continue;
    }

    results.add(
      _RemoteCompanyRecord(
        uuid: uuid,
        name: name,
        nationalId: _readString(
          entry,
          'nationalId',
          fallbackKey: 'national_id',
        ),
        economicCode: _readString(
          entry,
          'economicCode',
          fallbackKey: 'economic_code',
        ),
      ),
    );
  }

  return results;
}

Future<List<_RemoteBankAccountRecord>> _fetchRemoteBankAccounts(
  ApiClient client,
) async {
  final payload = await client.get(ApiConstants.bankAccountsEndpoint);
  if (payload is! List) {
    return const <_RemoteBankAccountRecord>[];
  }

  final results = <_RemoteBankAccountRecord>[];

  for (final entry in payload) {
    if (entry is! Map<String, dynamic>) {
      continue;
    }

    final uuid = _readString(entry, 'id');
    if (uuid == null || uuid.isEmpty) {
      continue;
    }

    results.add(
      _RemoteBankAccountRecord(
        uuid: uuid,
        iban:
            _readString(entry, 'iban', fallbackKey: 'shebaNumber') ??
            _readString(entry, 'sheba_number'),
        accountNumber: _readString(
          entry,
          'accountNumber',
          fallbackKey: 'account_number',
        ),
        cardNumber: _readString(
          entry,
          'cardNumber',
          fallbackKey: 'card_number',
        ),
        bankName:
            _readString(entry, 'bankName', fallbackKey: 'bank_name') ??
            _readString(entry, 'bank'),
        accountTitle: _readString(
          entry,
          'accountTitle',
          fallbackKey: 'account_title',
        ),
      ),
    );
  }

  return results;
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

  final text = value.toString().trim();
  if (text.isEmpty) {
    return null;
  }

  return text;
}

String? _trimOrNull(String? value) {
  if (value == null) {
    return null;
  }

  final text = value.trim();
  return text.isEmpty ? null : text;
}

String _normalizeText(String value) {
  return value
      .trim()
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('\u200c', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase();
}

String? _normalizeTextOrNull(String? value) {
  final trimmed = _trimOrNull(value);
  if (trimmed == null) {
    return null;
  }

  return _normalizeText(trimmed);
}

String? _normalizeToken(String? value) {
  final trimmed = _trimOrNull(value);
  if (trimmed == null) {
    return null;
  }

  final normalizedDigits = _toEnglishDigits(trimmed)
      .replaceAll(RegExp(r'[\s\-_/]'), '')
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .toLowerCase();

  return normalizedDigits.isEmpty ? null : normalizedDigits;
}

String _toEnglishDigits(String input) {
  final buffer = StringBuffer();
  for (final codeUnit in input.codeUnits) {
    if (codeUnit >= 0x06F0 && codeUnit <= 0x06F9) {
      buffer.writeCharCode(codeUnit - 0x06F0 + 0x30);
      continue;
    }

    if (codeUnit >= 0x0660 && codeUnit <= 0x0669) {
      buffer.writeCharCode(codeUnit - 0x0660 + 0x30);
      continue;
    }

    buffer.writeCharCode(codeUnit);
  }

  return buffer.toString();
}
