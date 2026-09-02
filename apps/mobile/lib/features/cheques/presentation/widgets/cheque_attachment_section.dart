import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/database/database_service.dart';
import '../../../../data/models/cheque_attachment.dart';
import '../../../../data/repositories/local/local_cheque_attachment_repository.dart';
import '../../../../data/repositories/remote/remote_cheque_attachment_repository.dart';
import '../../../settings/presentation/providers/communication_settings_provider.dart';

class ChequeAttachmentDraft {
  ChequeAttachmentDraft({
    required this.kind,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    required this.sha256,
    required this.localPath,
  });

  final ChequeAttachmentKind kind;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final String sha256;
  final String localPath;

  bool _persisted = false;

  bool get isPersisted => _persisted;

  Future<void> persist(int chequeId) async {
    if (_persisted) {
      return;
    }

    final source = File(localPath);

    if (!await source.exists()) {
      throw StateError(
        'Temporary attachment file is missing before cheque save.',
      );
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();

    final destinationDirectory = Directory(
      p.join(
        documentsDirectory.path,
        'cheque_attachments',
        chequeId.toString(),
      ),
    );

    await destinationDirectory.create(recursive: true);

    var extension = p.extension(localPath).toLowerCase();

    if (extension.isEmpty) {
      extension = p.extension(fileName).toLowerCase();
    }

    final destinationName =
        '${kind.name}_${DateTime.now().microsecondsSinceEpoch}$extension';

    final destination = File(
      p.join(destinationDirectory.path, destinationName),
    );

    try {
      await source.rename(destination.path);
    } catch (_) {
      await source.copy(destination.path);

      if (await source.exists()) {
        await source.delete();
      }
    }

    final now = DateTime.now().toUtc();

    try {
      final repository = LocalChequeAttachmentRepository(
        DatabaseService.instance,
      );

      await repository.insert(
        ChequeAttachment(
          chequeId: chequeId,
          kind: kind,
          fileName: fileName,
          mimeType: mimeType,
          originalFileSize: fileSize,
          fileSize: fileSize,
          sha256: sha256,
          localPath: destination.path,
          createdAt: now,
          updatedAt: now,
        ),
      );

      _persisted = true;
    } catch (_) {
      try {
        if (await destination.exists()) {
          await destination.delete();
        }
      } catch (_) {}

      rethrow;
    }
  }

  void discardTemporaryFileSync() {
    if (_persisted) {
      return;
    }

    try {
      final file = File(localPath);

      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {
      // Best-effort cleanup only.
    }
  }
}

class ChequeAttachmentSection extends ConsumerStatefulWidget {
  const ChequeAttachmentSection({
    super.key,
    required this.chequeId,
    this.onDraftsChanged,
  });

  final int? chequeId;

  final ValueChanged<List<ChequeAttachmentDraft>>? onDraftsChanged;

  @override
  ConsumerState<ChequeAttachmentSection> createState() =>
      _ChequeAttachmentSectionState();
}

class _ChequeAttachmentSectionState
    extends ConsumerState<ChequeAttachmentSection> {
  static const int _maximumBytes = 25 * 1024 * 1024;

  final ImagePicker _imagePicker = ImagePicker();

  late final LocalChequeAttachmentRepository _repository;

  List<ChequeAttachment> _attachments = const [];

  final List<ChequeAttachmentDraft> _drafts = [];

  bool _isLoading = true;
  bool _isBusy = false;

  String? _loadError;

  @override
  void initState() {
    super.initState();

    _repository = LocalChequeAttachmentRepository(DatabaseService.instance);

    _load();
  }

  @override
  void didUpdateWidget(ChequeAttachmentSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.chequeId != widget.chequeId) {
      _load();
    }
  }

  Future<void> _load() async {
    final chequeId = widget.chequeId;

    if (chequeId == null) {
      if (mounted) {
        setState(() {
          _attachments = const [];
          _isLoading = false;
          _loadError = null;
        });
      }

      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final attachments = await _repository.findByChequeId(chequeId);

      if (!mounted) {
        return;
      }

      setState(() {
        _attachments = attachments;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('ChequeAttachmentSection._load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError = 'بارگذاری پیوست‌ها با خطا مواجه شد.';
      });
    }
  }

  Future<void> _addAttachment(ChequeAttachmentKind kind) async {
    if (_isBusy) {
      return;
    }

    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.camera_alt_outlined),
                    title: const Text('دوربین'),
                    subtitle: const Text('گرفتن عکس جدید از صورتحساب'),
                    onTap: () {
                      Navigator.of(sheetContext).pop('camera');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_open_outlined),
                    title: const Text('گالری / فایل PDF'),
                    subtitle: const Text('انتخاب یک یا چند تصویر یا فایل PDF'),
                    onTap: () {
                      Navigator.of(sheetContext).pop('files');
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }

    if (source == 'camera') {
      await _addStatementFromCamera(kind);
      return;
    }

    await _addStatementFiles(kind);
  }

  Future<void> _addStatementFromCamera(ChequeAttachmentKind kind) async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
      );

      if (picked == null) {
        return;
      }

      final bytes = await picked.readAsBytes();

      final originalName = picked.name.trim().isEmpty
          ? p.basename(picked.path)
          : picked.name.trim();

      await _persistPickedAttachment(
        kind: kind,
        fileName: originalName,
        pathHint: picked.path,
        bytes: bytes,
      );

      if (widget.chequeId != null) {
        await _load();
      }

      if (!mounted) {
        return;
      }

      final message = widget.chequeId == null
          ? 'تصویر صورتحساب آماده است و همراه با ذخیره چک ثبت می‌شود.'
          : 'تصویر صورتحساب ذخیره شد و در صف همگام‌سازی قرار گرفت.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message, textAlign: TextAlign.right)),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'ChequeAttachmentSection._addStatementFromCamera failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      final message = error is StateError
          ? error.message.toString()
          : 'ثبت تصویر صورتحساب با خطا مواجه شد.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message, textAlign: TextAlign.right)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _addStatementFiles(ChequeAttachmentKind kind) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      allowMultiple: true,
    );

    final pickedFiles = result?.files ?? const <PlatformFile>[];

    if (pickedFiles.isEmpty || !mounted) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    var added = 0;
    var failed = 0;

    try {
      for (final picked in pickedFiles) {
        try {
          final bytes = await picked.xFile.readAsBytes();

          await _persistPickedAttachment(
            kind: kind,
            fileName: picked.name,
            pathHint: picked.name,
            bytes: bytes,
          );

          added += 1;
        } catch (error, stackTrace) {
          failed += 1;

          debugPrint(
            'ChequeAttachmentSection._addStatementFiles '
            'skipped ${picked.name}: $error',
          );
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      if (widget.chequeId != null && added > 0) {
        await _load();
      }

      if (!mounted) {
        return;
      }

      final message = failed == 0
          ? '$added فایل صورتحساب افزوده شد.'
          : '$added فایل افزوده شد و $failed فایل قابل ثبت نبود.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message, textAlign: TextAlign.right)),
      );
    } catch (error, stackTrace) {
      debugPrint('ChequeAttachmentSection._addStatementFiles failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'افزودن صورتحساب‌ها با خطا مواجه شد.',
              textAlign: TextAlign.right,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _persistPickedAttachment({
    required ChequeAttachmentKind kind,
    required String fileName,
    required String pathHint,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) {
      throw StateError('فایل انتخاب‌شده خالی است.');
    }

    if (bytes.lengthInBytes > _maximumBytes) {
      throw StateError('حجم فایل بیشتر از ۲۵ مگابایت است.');
    }

    final mimeType = _mimeTypeForPath(pathHint);

    if (mimeType == null) {
      throw StateError(
        'فرمت فایل پشتیبانی نمی‌شود. '
        'فرمت‌های مجاز: JPG، PNG، WEBP و PDF.',
      );
    }

    final chequeId = widget.chequeId;
    late final Directory attachmentDirectory;

    if (chequeId == null) {
      final temporaryDirectory = await getTemporaryDirectory();
      attachmentDirectory = Directory(
        p.join(temporaryDirectory.path, 'cheque_attachment_drafts'),
      );
    } else {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      attachmentDirectory = Directory(
        p.join(
          documentsDirectory.path,
          'cheque_attachments',
          chequeId.toString(),
        ),
      );
    }

    await attachmentDirectory.create(recursive: true);

    final extension = _normalizedExtension(pathHint, mimeType);
    final durableName =
        '${kind.name}_${DateTime.now().microsecondsSinceEpoch}$extension';
    final durableFile = File(p.join(attachmentDirectory.path, durableName));

    try {
      await durableFile.writeAsBytes(bytes, flush: true);

      final normalizedFileName = fileName.trim().isEmpty
          ? durableName
          : p.basename(fileName.trim());
      final now = DateTime.now().toUtc();
      final digest = sha256.convert(bytes).toString();

      if (chequeId == null) {
        final draft = ChequeAttachmentDraft(
          kind: kind,
          fileName: normalizedFileName,
          mimeType: mimeType,
          fileSize: bytes.lengthInBytes,
          sha256: digest,
          localPath: durableFile.path,
        );

        if (mounted) {
          setState(() {
            _drafts.add(draft);
          });
        } else {
          _drafts.add(draft);
        }

        widget.onDraftsChanged?.call(
          List<ChequeAttachmentDraft>.unmodifiable(_drafts),
        );
        return;
      }

      await _repository.insert(
        ChequeAttachment(
          chequeId: chequeId,
          kind: kind,
          fileName: normalizedFileName,
          mimeType: mimeType,
          originalFileSize: bytes.lengthInBytes,
          fileSize: bytes.lengthInBytes,
          sha256: digest,
          localPath: durableFile.path,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } catch (_) {
      try {
        if (await durableFile.exists()) {
          await durableFile.delete();
        }
      } catch (_) {
        // Best-effort cleanup only.
      }

      rethrow;
    }
  }

  Future<void> _shareAttachment(ChequeAttachment attachment) async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      final file = await _ensureLocalAttachmentFile(attachment);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: attachment.mimeType)],
          fileNameOverrides: [attachment.fileName],
        ),
      );

      await _load();
    } catch (error, stackTrace) {
      debugPrint('ChequeAttachmentSection._shareAttachment failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      final message = error is StateError
          ? error.message.toString()
          : 'اشتراک‌گذاری پیوست با خطا مواجه شد.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message, textAlign: TextAlign.right)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _requestDelete(ChequeAttachment attachment) async {
    final id = attachment.id;

    if (id == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('حذف پیوست'),
            content: Text(
              'آیا ${_kindLabel(attachment.kind)} حذف شود؟\n\n'
              'حذف پس از همگام‌سازی روی سرور نیز اعمال می‌شود.',
              textAlign: TextAlign.right,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      // Do not delete local bytes here.
      // An unsynced/processing CREATE may still need the source file.
      await _repository.requestDelete(id);

      await _load();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'پیوست در صف حذف قرار گرفت.',
            textAlign: TextAlign.right,
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'ChequeAttachmentSection._requestDelete failed: '
        '$error',
      );
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'حذف پیوست با خطا مواجه شد.',
            textAlign: TextAlign.right,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<File> _ensureLocalAttachmentFile(ChequeAttachment attachment) async {
    final localPath = attachment.localPath?.trim();

    if (localPath != null && localPath.isNotEmpty) {
      final localFile = File(localPath);

      if (await localFile.exists()) {
        return localFile;
      }
    }

    final localId = attachment.id;
    final serverUuid = attachment.serverUuid?.trim();

    if (localId == null || serverUuid == null || serverUuid.isEmpty) {
      throw StateError('این پیوست هنوز روی سرور قابل دریافت نیست.');
    }

    final remoteRepository = RemoteChequeAttachmentRepository(
      ref.read(apiClientProvider),
    );

    try {
      final downloadInfo = await remoteRepository.getDownloadInfo(serverUuid);

      final downloadUri = Uri.tryParse(downloadInfo.downloadUrl);

      if (downloadUri == null) {
        throw StateError('آدرس دانلود پیوست معتبر نیست.');
      }

      final response = await http
          .get(downloadUri)
          .timeout(const Duration(seconds: 90));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'دانلود پیوست با خطا مواجه شد '
          '(HTTP ${response.statusCode}).',
        );
      }

      final bytes = response.bodyBytes;

      if (bytes.lengthInBytes != attachment.fileSize) {
        throw StateError('اندازه فایل دانلودشده با اطلاعات سرور مطابقت ندارد.');
      }

      final downloadedSha = sha256.convert(bytes).toString().toLowerCase();
      final expectedSha = attachment.sha256.trim().toLowerCase();

      if (downloadedSha != expectedSha) {
        throw StateError('صحت فایل دانلودشده تأیید نشد (SHA256 mismatch).');
      }

      final documentsDirectory = await getApplicationDocumentsDirectory();

      final attachmentDirectory = Directory(
        p.join(
          documentsDirectory.path,
          'cheque_attachments',
          attachment.chequeId.toString(),
        ),
      );

      await attachmentDirectory.create(recursive: true);

      var extension = p.extension(attachment.fileName).toLowerCase();

      if (extension.isEmpty) {
        switch (attachment.mimeType.toLowerCase()) {
          case 'image/png':
            extension = '.png';
            break;
          case 'image/webp':
            extension = '.webp';
            break;
          case 'application/pdf':
            extension = '.pdf';
            break;
          default:
            extension = '.jpg';
        }
      }

      final file = File(
        p.join(
          attachmentDirectory.path,
          '${serverUuid.toLowerCase()}$extension',
        ),
      );

      await file.writeAsBytes(bytes, flush: true);

      await _repository.applyDownloadedLocalPath(
        id: localId,
        localPath: file.path,
      );

      return file;
    } finally {
      remoteRepository.close();
    }
  }

  Future<void> _preview(ChequeAttachment attachment) async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      final file = await _ensureLocalAttachmentFile(attachment);

      if (!mounted) {
        return;
      }

      if (attachment.mimeType.startsWith('image/')) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5,
                      child: Center(
                        child: Image.file(file, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: IconButton.filledTonal(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'فایل دریافت شد و برای اشتراک‌گذاری آماده است.',
              textAlign: TextAlign.right,
            ),
          ),
        );
      }

      await _load();
    } catch (error, stackTrace) {
      debugPrint('ChequeAttachmentSection._preview failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      final message = error is StateError
          ? error.message.toString()
          : 'دریافت پیوست با خطا مواجه شد.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message, textAlign: TextAlign.right)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  String? _mimeTypeForPath(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';

      case '.png':
        return 'image/png';

      case '.webp':
        return 'image/webp';

      case '.pdf':
        return 'application/pdf';
    }

    return null;
  }

  String _normalizedExtension(String path, String mimeType) {
    final extension = p.extension(path).toLowerCase();

    if (extension.isNotEmpty) {
      return extension;
    }

    switch (mimeType) {
      case 'image/png':
        return '.png';

      case 'image/webp':
        return '.webp';

      case 'application/pdf':
        return '.pdf';

      default:
        return '.jpg';
    }
  }

  String _kindLabel(ChequeAttachmentKind kind) {
    switch (kind) {
      case ChequeAttachmentKind.statement:
        return 'صورتحساب';
    }
  }

  String _statusLabel(ChequeAttachment attachment) {
    final localPath = attachment.localPath?.trim();
    final storageKey = attachment.storageKey?.trim();

    if (storageKey == null || storageKey.isEmpty) {
      return 'در انتظار همگام‌سازی';
    }

    if (localPath == null ||
        localPath.isEmpty ||
        !File(localPath).existsSync()) {
      return 'همگام‌شده • آماده دانلود';
    }

    return 'همگام‌شده';
  }

  String _fileSizeText(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    final kilobytes = bytes / 1024;

    if (kilobytes < 1024) {
      return '${kilobytes.toStringAsFixed(1)} KB';
    }

    final megabytes = kilobytes / 1024;

    return '${megabytes.toStringAsFixed(1)} MB';
  }

  Future<void> _shareDraft(ChequeAttachmentDraft draft) async {
    final file = File(draft.localPath);

    if (!await file.exists()) {
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: draft.mimeType)],
        fileNameOverrides: [draft.fileName],
      ),
    );
  }

  Future<void> _deleteDraft(ChequeAttachmentDraft draft) async {
    draft.discardTemporaryFileSync();

    if (!mounted) {
      return;
    }

    setState(() {
      _drafts.remove(draft);
    });

    widget.onDraftsChanged?.call(
      List<ChequeAttachmentDraft>.unmodifiable(_drafts),
    );
  }

  Widget _draftTile(ChequeAttachmentDraft draft) {
    final file = File(draft.localPath);
    final isImage = draft.mimeType.startsWith('image/');

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        onTap: () async {
          if (!await file.exists() || !mounted) {
            return;
          }

          if (!isImage) {
            await _shareDraft(draft);
            return;
          }

          await showDialog<void>(
            context: context,
            builder: (dialogContext) {
              return Dialog(
                insetPadding: const EdgeInsets.all(16),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 5,
                        child: Center(
                          child: Image.file(file, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: IconButton.filledTonal(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 54,
            height: 54,
            child: isImage
                ? Image.file(file, fit: BoxFit.cover)
                : const Icon(Icons.picture_as_pdf_outlined, size: 32),
          ),
        ),
        title: Text(
          _kindLabel(draft.kind),
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${draft.fileName}\n'
            '${_fileSizeText(draft.fileSize)} • آماده ذخیره',
            textAlign: TextAlign.right,
          ),
        ),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              tooltip: 'اشتراک‌گذاری',
              onPressed: () => _shareDraft(draft),
              icon: const Icon(Icons.share_outlined),
            ),
            IconButton(
              tooltip: 'حذف پیوست',
              onPressed: () => _deleteDraft(draft),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachmentTile(ChequeAttachment attachment) {
    final localPath = attachment.localPath?.trim();

    final hasLocalImage =
        attachment.mimeType.startsWith('image/') &&
        localPath != null &&
        localPath.isNotEmpty &&
        File(localPath).existsSync();

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        onTap: () => _preview(attachment),
        leading: SizedBox(
          width: 54,
          height: 54,
          child: hasLocalImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(localPath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) {
                      return const Icon(Icons.image_not_supported_outlined);
                    },
                  ),
                )
              : Icon(
                  attachment.mimeType == 'application/pdf'
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined,
                  size: 32,
                ),
        ),
        title: Text(
          _kindLabel(attachment.kind),
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${attachment.fileName}\n'
            '${_fileSizeText(attachment.fileSize)} • '
            '${_statusLabel(attachment)}',
            textAlign: TextAlign.right,
          ),
        ),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              tooltip: 'اشتراک‌گذاری',
              onPressed: _isBusy ? null : () => _shareAttachment(attachment),
              icon: const Icon(Icons.share_outlined),
            ),
            IconButton(
              tooltip: 'حذف پیوست',
              onPressed: _isBusy ? null : () => _requestDelete(attachment),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.discardTemporaryFileSync();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'صورتحساب‌های چک',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'بازخوانی',
                  onPressed: _isBusy ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isBusy
                      ? null
                      : () => _addAttachment(ChequeAttachmentKind.statement),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('افزودن صورتحساب'),
                ),
              ],
            ),
            if (_isBusy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_isLoading) ...[
              const SizedBox(height: 18),
              const Center(child: CircularProgressIndicator()),
            ] else if (_loadError != null) ...[
              const SizedBox(height: 12),
              Text(_loadError!, textAlign: TextAlign.right),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('تلاش مجدد'),
                ),
              ),
            ] else if (_attachments.isEmpty &&
                _drafts.where((draft) => !draft.isPersisted).isEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'هنوز صورتحسابی برای این چک ثبت نشده است.',
                textAlign: TextAlign.right,
              ),
            ] else ...[
              const SizedBox(height: 6),
              ..._drafts.where((draft) => !draft.isPersisted).map(_draftTile),
              ..._attachments.map(_attachmentTile),
            ],
          ],
        ),
      ),
    );
  }
}
