class BootstrapMatch {
  const BootstrapMatch({
    required this.localId,
    required this.serverUuid,
    required this.strategy,
  });

  final int localId;
  final String serverUuid;
  final String strategy;
}

class BootstrapConflict {
  const BootstrapConflict({
    required this.localId,
    required this.strategy,
    required this.candidateServerUuids,
  });

  final int localId;
  final String strategy;
  final List<String> candidateServerUuids;
}

class BootstrapUnresolved {
  const BootstrapUnresolved({required this.localId, required this.reason});

  final int localId;
  final String reason;
}

class BootstrapResult {
  const BootstrapResult({
    required this.matchedCompanies,
    required this.matchedBankAccounts,
    required this.companyConflicts,
    required this.bankConflicts,
    required this.companyUnresolved,
    required this.bankUnresolved,
  });

  final List<BootstrapMatch> matchedCompanies;
  final List<BootstrapMatch> matchedBankAccounts;
  final List<BootstrapConflict> companyConflicts;
  final List<BootstrapConflict> bankConflicts;
  final List<BootstrapUnresolved> companyUnresolved;
  final List<BootstrapUnresolved> bankUnresolved;
}
