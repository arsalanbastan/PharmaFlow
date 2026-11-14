import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('pharmaflow/price_ocr');

Future<Map<String, dynamic>?> reviewOfflinePriceImage(
  BuildContext context,
  Uint8List bytes,
) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1200);
  late final double ratio;
  try {
    final frame = await codec.getNextFrame();
    ratio = frame.image.width / frame.image.height;
    frame.image.dispose();
  } finally {
    codec.dispose();
  }
  if (!context.mounted) return null;
  return Navigator.of(context).push<Map<String, dynamic>>(
    MaterialPageRoute(
      builder: (_) => _PriceCells(image: bytes, ratio: ratio),
    ),
  );
}

class _PriceCells extends StatefulWidget {
  const _PriceCells({required this.image, required this.ratio});
  final Uint8List image;
  final double ratio;

  @override
  State<_PriceCells> createState() => _PriceCellsState();
}

class _PriceCellsState extends State<_PriceCells> {
  final _cells = <Rect>[];
  Offset? _start;
  Offset? _end;
  bool _busy = false;
  bool _zooming = false;
  int _tableRows = 1;
  String _unit = 'UNKNOWN';
  String? _error;

  Rect? get _draft {
    final start = _start;
    final end = _end;
    return start == null || end == null ? null : Rect.fromPoints(start, end);
  }

  Offset _relative(Offset point, Size size) => Offset(
    (point.dx / size.width).clamp(0.0, 1.0).toDouble(),
    (point.dy / size.height).clamp(0.0, 1.0).toDouble(),
  );

  String? _price(String raw) {
    const digits = '۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩';
    final text = raw.replaceAllMapped(
      RegExp('[۰-۹٠-٩]'),
      (match) => '${digits.indexOf(match[0]!) % 10}',
    );
    final match = RegExp(
      r'^\s*(\d{1,16}|\d{1,3}(?:[.,٬،]\d{3})+)\s*(?:ریال|تومان)?\s*$',
    ).firstMatch(text);
    return match?[1]?.replaceAll(RegExp('[.,٬،]'), '');
  }

  List<Rect> get _selectedCells {
    if (_tableRows == 1) return _cells;
    Rect row(Rect rect, int index) => Rect.fromLTRB(
      rect.left,
      rect.top + rect.height * index / _tableRows,
      rect.right,
      rect.top + rect.height * (index + 1) / _tableRows,
    );
    return [
      for (var index = 0; index < _tableRows; index++)
        for (final column in _cells) row(column, index),
    ];
  }

  Future<void> _read() async {
    final cells = _selectedCells;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final values = await _channel.invokeListMethod<String>('readCells', {
        'image': widget.image,
        'cells': [
          for (final cell in cells)
            [cell.left, cell.top, cell.right, cell.bottom],
        ],
      });
      if (values == null || values.length != cells.length) {
        throw StateError('خواندن بخش‌های تصویر کامل نشد.');
      }
      if (!mounted) return;
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < values.length; i += 2) {
        final priceText = values[i + 1];
        final price = _price(priceText);
        rows.add({
          'name': values[i].replaceAll(RegExp(r'\s+'), ' ').trim(),
          'price': price,
          'unit': _unit,
          'requiresReview': true,
          'note': price == null
              ? 'عدد خوانا نبود. قیمت مصرف‌کننده را از روی عکس وارد کنید.'
              : null,
        });
      }
      Navigator.pop(context, {'rows': rows});
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('خواندن آفلاین اطلاعیه')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _tableRows > 1
                  ? (_cells.isEmpty
                        ? 'دور ستون نام اقلام، بدون عنوان ستون، کادر بکشید.'
                        : 'دور ستون قیمت جدید مصرف‌کننده، بدون عنوان ستون، کادر بکشید.')
                  : _cells.length.isEven
                  ? 'روی نام قلم ${_cells.length ~/ 2 + 1} کادر بکشید.'
                  : 'روی قیمت جدید مصرف‌کنندهٔ همین قلم کادر بکشید.',
            ),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('جدول با ردیف‌های هم‌اندازه'),
                selected: _tableRows > 1,
                onSelected: _busy
                    ? null
                    : (selected) => setState(() {
                        _tableRows = selected ? 2 : 1;
                        _cells.clear();
                      }),
              ),
              if (_tableRows > 1)
                DropdownButton<int>(
                  value: _tableRows,
                  items: [
                    for (var count = 2; count <= 50; count++)
                      DropdownMenuItem(
                        value: count,
                        child: Text('$count ردیف'),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _tableRows = value!),
                ),
              DropdownButton<String>(
                value: _unit,
                items: const [
                  DropdownMenuItem(
                    value: 'UNKNOWN',
                    child: Text('واحد نامشخص'),
                  ),
                  DropdownMenuItem(value: 'RIAL', child: Text('ریال')),
                  DropdownMenuItem(value: 'TOMAN', child: Text('تومان')),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _unit = value!),
              ),
              FilterChip(
                label: const Text('زوم و جابه‌جایی'),
                selected: _zooming,
                onSelected: _busy
                    ? null
                    : (value) => setState(() => _zooming = value),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) Text(_error!),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = width / widget.ratio;
                return InteractiveViewer(
                  panEnabled: _zooming,
                  scaleEnabled: _zooming,
                  minScale: 1,
                  maxScale: 6,
                  child: Center(
                    child: SizedBox(
                      width: width,
                      height: height
                          .clamp(0.0, constraints.maxHeight)
                          .toDouble(),
                      child: AspectRatio(
                        aspectRatio: widget.ratio,
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final actualWidth = (box.maxHeight * widget.ratio)
                                .clamp(0.0, box.maxWidth)
                                .toDouble();
                            final imageSize = Size(
                              actualWidth,
                              actualWidth / widget.ratio,
                            );
                            return Center(
                              child: SizedBox.fromSize(
                                size: imageSize,
                                child: GestureDetector(
                                  onPanStart:
                                      _busy ||
                                          _zooming ||
                                          _cells.length >=
                                              (_tableRows > 1 ? 2 : 100)
                                      ? null
                                      : (details) {
                                          setState(
                                            () => _start = _relative(
                                              details.localPosition,
                                              imageSize,
                                            ),
                                          );
                                        },
                                  onPanUpdate: (details) {
                                    if (_start != null) {
                                      setState(
                                        () => _end = _relative(
                                          details.localPosition,
                                          imageSize,
                                        ),
                                      );
                                    }
                                  },
                                  onPanCancel: () => setState(() {
                                    _start = null;
                                    _end = null;
                                  }),
                                  onPanEnd: (_) => setState(() {
                                    final rect = _draft;
                                    if (rect != null &&
                                        rect.width > .005 &&
                                        rect.height > .005) {
                                      _cells.add(rect);
                                    }
                                    _start = null;
                                    _end = null;
                                  }),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.memory(
                                        widget.image,
                                        fit: BoxFit.fill,
                                      ),
                                      for (final (index, rect) in [
                                        ..._cells,
                                        ?_draft,
                                      ].indexed)
                                        Positioned.fromRect(
                                          rect: Rect.fromLTRB(
                                            rect.left * actualWidth,
                                            rect.top * imageSize.height,
                                            rect.right * actualWidth,
                                            rect.bottom * imageSize.height,
                                          ),
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: index.isEven
                                                    ? Colors.blue
                                                    : Colors.green,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: _busy || _cells.isEmpty
                      ? null
                      : () => setState(() => _cells.removeLast()),
                  child: const Text('حذف آخرین کادر'),
                ),
                FilledButton(
                  onPressed: _busy || _cells.isEmpty || _cells.length.isOdd
                      ? null
                      : _read,
                  child: Text('خواندن ${_selectedCells.length ~/ 2} قلم'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
