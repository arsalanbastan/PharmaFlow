# ADR-004: Cheque Module Domain Model

- Status: Approved
- Date: 2026-07-23

## Context

PharmaFlow needs a Cheque Management module to track pharmacy-issued cheques as financial commitments. A cheque always belongs to exactly one Company and one Bank Account. The module must support operational cheque handling, duplicate-number warning behavior, Sayad-related registration tracking, optional image capture, and list/query behavior optimized for daily work rather than long-term reporting.

## Decision

Cheque will be modeled as an independent Aggregate Root. Its business identity is the pair `BankAccountId + ChequeNumber`. This pair is used for duplicate detection and operator warnings, but it is not globally unique and does not block creation.

## 1. Entity Definition

Cheque is an independent Aggregate Root representing a single issued cheque and its lifecycle inside the pharmacy finance domain.

The aggregate is responsible for:

- preserving cheque identity and lifecycle state
- enforcing cheque-level validation rules
- handling duplicate-number detection signals
- managing optional cheque image attachment metadata/content
- exposing fields needed for operational listing and search

## 2. Required Fields

Required fields of the Cheque aggregate:

- `id`
- `companyId`
- `bankAccountId`
- `chequeNumber`
- `amountRial`
- `issueDate`
- `dueDate`
- `status`
- `isRegisteredInSayad`
- `createdAt`
- `updatedAt`

Field intent:

- `id`: technical primary identifier for the aggregate
- `companyId`: reference to the owning Company
- `bankAccountId`: reference to the issuing Bank Account
- `chequeNumber`: business-visible cheque number
- `amountRial`: cheque amount stored as integer Rial
- `issueDate`: date the cheque was issued
- `dueDate`: payable date
- `status`: Version 1 lifecycle state
- `isRegisteredInSayad`: explicit Sayad registration flag
- `createdAt`: record creation timestamp
- `updatedAt`: last modification timestamp

## 3. Optional Fields

Optional fields:

- `receiverName`
- `description`
- `archivedAt`
- `imageData`

Field intent:

- `receiverName`: payee/receiver label when needed operationally
- `description`: free-text note for operators
- `archivedAt`: soft-archive marker consistent with PharmaFlow archive patterns
- `imageData`: compressed binary image content stored in the database

## 4. Relationships

Relationships are reference-based, not ownership-based across aggregates.

- Cheque belongs to one Company.
- Cheque belongs to one Bank Account.
- One Company can have many Cheques.
- One Bank Account can have many Cheques.
- Company and Bank Account remain separate existing modules and are not modified by this ADR.

Constraints:

- `companyId` must reference an existing Company.
- `bankAccountId` must reference an existing Bank Account.
- A cheque cannot exist without both references.
- No additional child entities are introduced in Version 1.
- Maximum one image is associated with one cheque.

## 5. Business Rules

Core business rules:

- A cheque is a financial commitment issued by the pharmacy.
- Cheque is an independent Aggregate Root.
- A cheque always belongs to one Company and one Bank Account.
- Business identity is `BankAccountId + ChequeNumber`.
- Duplicate cheque numbers are allowed.
- Duplicate detection produces a warning, not a blocking error.
- The system should display existing cheque information when a duplicate is detected.
- The user may explicitly confirm and continue.
- Amount is stored in Rial only.
- Amount must be a positive integer greater than zero.
- Dates are date-only values with no timezone semantics.
- `dueDate` cannot be earlier than `issueDate`.
- Registered status and Sayad registration are independent concepts.
- A cheque can be `Registered` in PharmaFlow while `isRegisteredInSayad` remains `false`.
- Cancelled cheques are hidden by default from standard operational views.
- Archived cheques are hidden by default and can be included explicitly in search and reporting.
- Cancelled cheques are excluded from dashboard, commitments, and default reports.
- The default list is optimized for daily cheque management and Sayad registration tasks.
- Selecting a Bank Account during cheque creation should suggest the next cheque number based on the latest cheque for that bank account.
- The suggested cheque number is editable by the user and does not bypass duplicate checks.
- Image attachment is optional and may be added later during edit.
- Image data must be stored in a way that synchronizes across devices.

## 6. Validation Rules

Validation rules for Version 1:

Identity and references:

- `id` must be present.
- `companyId` must be present.
- `bankAccountId` must be present.
- referenced Company must exist
- referenced Bank Account must exist

Cheque number:

- `chequeNumber` must be present
- `chequeNumber` must be treated as user-entered business text/number value
- duplicate value under the same bank account triggers a warning workflow, not rejection

Amount:

- `amountRial` must be present
- `amountRial` must be an integer
- `amountRial` must be greater than zero

Dates:

- `issueDate` must be present
- `dueDate` must be present
- both are date-only values
- `dueDate >= issueDate`

Status:

- `status` must be one of the Version 1 states only:
  - `Issued`
  - `Registered`
  - `Cancelled`

Sayad:

- `isRegisteredInSayad` must be present as a boolean flag
- `isRegisteredInSayad` must be validated independently from `status`

Archive:

- `archivedAt` is optional
- when `archivedAt` is set, the cheque is hidden by default and only included when archive-aware search or reporting is explicitly requested

Image:

- zero or one image only
- image must be compressed before storage
- no local file path references may be persisted
- stored image must be database-resident binary content so it syncs with the record

Audit:

- `createdAt` must be set on creation
- `updatedAt` must be updated on every mutation

## 7. State Model

Version 1 supports exactly three states:

1. `Issued`
2. `Registered`
3. `Cancelled`

State semantics:

- `Issued`: cheque exists and is not yet marked registered
- `Registered`: cheque has been marked registered, typically via the card checkbox
- `Cancelled`: cheque is cancelled and excluded from normal operational flows

Allowed transitions:

- `Issued -> Registered`
- `Registered -> Issued`
- `Issued -> Cancelled`
- `Registered -> Cancelled`

Disallowed transition in Version 1:

- `Cancelled -> Issued`
- `Cancelled -> Registered`

Operational rules:

- checkbox checked: `Issued -> Registered`
- checkbox unchecked: `Registered -> Issued`
- cancellation is a separate menu action
- cancellation is terminal in Version 1

## 8. Duplicate Strategy

Duplicate strategy is warning-based, not constraint-based.

Duplicate definition:

- another cheque exists with the same `bankAccountId` and `chequeNumber`

System behavior on duplicate detection:

- show a warning to the user
- display the existing cheque information relevant for operator review
- allow the user to confirm and continue creation or edit
- do not treat duplicate as a validation failure
- do not prevent saving solely because of duplicate number

Reasoning:

- real-world cheque handling may require entry of repeated cheque numbers in exceptional or legacy cases
- operational visibility is needed, but blocking behavior is too strict for this domain

## 9. Query Strategy

Default list behavior:

- exclude cancelled cheques by default
- exclude archived cheques by default
- sort by `issueDate DESC`
- if equal, sort by `chequeNumber DESC`

Rationale:

- the list is optimized for daily cheque issuance and Sayad registration work
- future financial visibility is delegated to dashboard and reporting surfaces

Supported filters:

- date range filter:
  - from date
  - to date
- single search box for partial match over:
  - Company name
  - Cheque number

Combination behavior:

- filters are composable
- date range and search must work together in the same query flow

Optional filter behavior:

- optional user-controlled inclusion of cancelled cheques
- optional user-controlled inclusion of archived cheques for search and reporting views

Operational query expectations:

- retrieve latest cheque for a selected bank account to suggest next cheque number
- retrieve possible duplicate cheques by `bankAccountId + chequeNumber`
- retrieve lists suitable for default operational screens without including cancelled or archived items unless requested

## 10. Index Recommendations

Recommended indexes for Version 1:

- primary index on `id`
- composite index on `bankAccountId, chequeNumber`
  - used for duplicate detection
  - used for business-identity lookup
- composite index on default list ordering fields:
  - `issueDate`
  - `chequeNumber`
  - typically paired with `status` depending on storage/query engine
- index on `companyId`
  - supports company-related filtering and joins/lookups
- index on `bankAccountId`
  - supports bank-account-scoped queries and next-number suggestion
- index on `status`
  - supports exclusion of cancelled items in default views
- index on `archivedAt`
  - supports exclusion of archived items in default views and explicit archive-aware queries
- index on `dueDate`
  - supports future reporting/commitment queries
- if partial-match search infrastructure is later added, optimize separately for company-name and cheque-number search according to the chosen persistence engine

Design note:

- because default operational queries exclude cancelled and archived items and sort by issuance recency, indexing should favor those read paths over rarely used historical views

## 11. Image Storage Strategy

Image strategy for Version 1:

- image is optional
- at most one image per cheque
- image is compressed before persistence
- image is stored inside the database as part of persisted cheque data
- image must not be stored as a local file path reference
- image may be attached during creation or later during edit
- database-resident storage is required so the image synchronizes between devices with the cheque record

Rationale:

- local file paths are not portable across devices
- embedded database storage ensures sync consistency and simpler data portability
- single-image limit keeps aggregate scope and storage cost controlled in Version 1

## 12. Future Extension Points

This model intentionally leaves room for later evolution without changing the Version 1 decision.

Possible future extensions:

- richer cheque lifecycle states beyond `Issued`, `Registered`, `Cancelled`
- explicit cancellation metadata:
  - cancellation date
  - cancellation reason
  - cancelled by user
- stronger Sayad workflow fields beyond a single boolean
- multiple attachments or structured document metadata
- cheque settlement, clearance, bounce, or return flows
- reporting-specific projections for commitments and forecasting
- archive workflows using `archivedAt`
- duplicate-resolution audit trail or operator justification capture
- localized presentation fields separate from core domain values
- domain events for cheque created, registered, cancelled, image attached

## Consequences

Benefits:

- keeps Cheque independent and focused
- matches real operational behavior for pharmacies
- avoids over-constraining duplicate cheque numbers
- supports sync-safe image handling
- preserves clean boundaries with Company and Bank Account modules
- aligns archive behavior with existing PharmaFlow soft-archive patterns

Tradeoffs:

- warning-based duplicates require deliberate UI handling
- storing image data in the database increases record/storage size
- `isRegisteredInSayad` and `status` may overlap conceptually in UI discussions and must remain explicitly independent in application behavior unless later unified by a new ADR