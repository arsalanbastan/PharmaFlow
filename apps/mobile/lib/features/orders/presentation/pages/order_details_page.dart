import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../../core/network/api_client.dart';
import '../../data/manager_orders_repository.dart';
import '../../domain/manager_order_details.dart';

class OrderDetailsPage extends StatefulWidget {
  const OrderDetailsPage({
    required this.orderId,
    required this.repository,
    super.key,
  });

  final String orderId;
  final ManagerOrdersRepository repository;

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  ManagerOrderDetails? _order;
  ManagerOrderPhoto? _photo;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final order = await widget.repository.getById(widget.orderId);
      ManagerOrderPhoto? photo;

      if (order.status == 'PENDING') {
        photo = await widget.repository.getPhoto(widget.orderId);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _order = order;
        _photo = photo;
        _loading = false;
      });
    } on ApiHttpException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = switch (error.statusCode) {
          401 || 403 => 'نشست مدیر معتبر نیست. دوباره وارد شوید.',
          404 => 'این سفارش دیگر در دسترس نیست.',
          _ => error.message,
        };
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = 'بارگذاری جزئیات سفارش انجام نشد.';
      });
    }
  }

  Future<void> _showFullPhoto(String url) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5,
                    child: Center(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) {
                          return const Text(
                            'نمایش عکس انجام نشد.',
                            style: TextStyle(color: Colors.white),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 8,
                  end: 8,
                  child: IconButton.filledTonal(
                    tooltip: 'بستن',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('جزئیات سفارش'),
          actions: [
            IconButton(
              tooltip: 'بروزرسانی',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _order == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final errorMessage = _errorMessage;

    if (errorMessage != null && _order == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44),
              const SizedBox(height: 10),
              Text(errorMessage, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('تلاش مجدد'),
              ),
            ],
          ),
        ),
      );
    }

    final order = _order!;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          _OrderDetailsHeader(order: order),
          const SizedBox(height: 8),
          _DetailsSection(
            title: 'اطلاعات درخواست',
            children: [
              _DetailRow(label: 'قلم', value: order.itemText),
              _DetailRow(
                label: 'دسته',
                value: order.category == 'DRUG' ? 'دارو' : 'کالا',
              ),
              _DetailRow(
                label: 'تعداد درخواستی',
                value: _formatQuantity(order.requestedQuantity),
              ),
              _DetailRow(label: 'ثبت‌کننده', value: order.requestedByName),
              _DetailRow(
                label: 'تاریخ ثبت',
                value: _formatDateTime(order.createdAt),
              ),
              _DetailRow(
                label: 'شرکت پیشنهادی',
                value: order.suggestedCompanyText ?? '—',
              ),
              _DetailRow(label: 'یادداشت', value: order.notes ?? '—'),
              _DetailRow(
                label: 'احتمال تکراری بودن',
                value: order.possibleDuplicate ? 'بله' : 'خیر',
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailsSection(
            title: 'وضعیت و پیگیری',
            children: [
              _DetailRow(
                label: 'شرکت نهایی',
                value: order.assignedCompanyName ?? '—',
              ),
              _DetailRow(
                label: 'تعداد سفارش‌شده',
                value: _formatQuantity(order.orderedQuantity),
              ),
              _DetailRow(
                label: 'سفارش‌دهنده',
                value: order.orderedByName ?? '—',
              ),
              _DetailRow(
                label: 'زمان سفارش',
                value: _formatDateTime(order.orderedAt),
              ),
              _DetailRow(
                label: 'تحویل‌گیرنده',
                value: order.receivedByName ?? '—',
              ),
              _DetailRow(
                label: 'زمان تحویل',
                value: _formatDateTime(order.receivedAt),
              ),
              _DetailRow(label: 'لغوکننده', value: order.canceledByName ?? '—'),
              _DetailRow(
                label: 'زمان لغو',
                value: _formatDateTime(order.canceledAt),
              ),
              _DetailRow(
                label: 'آخرین تغییر',
                value: _formatDateTime(order.updatedAt),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildPhotoSection(order),
          const SizedBox(height: 8),
          _DetailsSection(
            title: 'شناسه',
            children: [
              _DetailRow(
                label: 'شناسه سفارش',
                value: order.id,
                selectable: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(ManagerOrderDetails order) {
    final photo = _photo;

    if (photo != null) {
      return _DetailsSection(
        title: 'عکس پیوست',
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showFullPhoto(photo.downloadUrl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.network(
                  photo.downloadUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) {
                      return child;
                    }

                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (_, __, ___) {
                    return const Center(child: Text('بارگذاری عکس انجام نشد.'));
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _DetailRow(label: 'حجم فایل', value: _formatFileSize(photo.fileSize)),
          const Text(
            'برای مشاهده بزرگ‌تر روی عکس بزنید.',
            style: TextStyle(fontSize: 11),
          ),
        ],
      );
    }

    if (order.photoWasDeleted) {
      return const _DetailsSection(
        title: 'عکس پیوست',
        children: [
          Text(
            'عکس پیوست پس از تغییر وضعیت سفارش طبق چرخه نگهداری حذف شده است.',
          ),
        ],
      );
    }

    return const _DetailsSection(
      title: 'عکس پیوست',
      children: [Text('عکس پیوستی برای این سفارش وجود ندارد.')],
    );
  }
}

class _OrderDetailsHeader extends StatelessWidget {
  const _OrderDetailsHeader({required this.order});

  final ManagerOrderDetails order;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        child: Row(
          children: [
            Expanded(
              child: Text(
                order.itemText,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusLabel(order.status),
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final valueWidget = selectable
        ? SelectableText(
            value,
            textAlign: TextAlign.left,
            style: const TextStyle(fontSize: 12),
          )
        : Text(
            value,
            textAlign: TextAlign.left,
            style: const TextStyle(fontSize: 12),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'PENDING' => 'در انتظار',
    'ORDERED' => 'سفارش‌شده',
    'RECEIVED' => 'تحویل‌شده',
    'CANCELED' => 'لغوشده',
    _ => status,
  };
}

String _formatQuantity(int? value) {
  return value == null ? '—' : _toPersianDigits(value.toString());
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return '—';
  }

  final local = value.toLocal();
  final jalali = Jalali.fromDateTime(local);
  final date =
      '${jalali.year}/${jalali.month.toString().padLeft(2, '0')}/${jalali.day.toString().padLeft(2, '0')}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

  return '${_toPersianDigits(date)} - ${_toPersianDigits(time)}';
}

String _formatFileSize(int? bytes) {
  if (bytes == null) {
    return '—';
  }

  if (bytes < 1024) {
    return '${_toPersianDigits(bytes.toString())} بایت';
  }

  final kilobytes = bytes / 1024;

  if (kilobytes < 1024) {
    return '${_toPersianDigits(kilobytes.toStringAsFixed(1))} کیلوبایت';
  }

  final megabytes = kilobytes / 1024;
  return '${_toPersianDigits(megabytes.toStringAsFixed(2))} مگابایت';
}

String _toPersianDigits(String value) {
  const english = '0123456789';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  var output = value;

  for (var index = 0; index < english.length; index++) {
    output = output.replaceAll(english[index], persian[index]);
  }

  return output;
}
