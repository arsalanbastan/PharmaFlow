import 'package:flutter/material.dart';

typedef QuickActionLauncher =
    Future<void> Function({required bool replaceCurrent});

class QuickActionsEdgePanel extends StatefulWidget {
  const QuickActionsEdgePanel({
    super.key,
    required this.child,
    required this.onAddCheque,
    required this.onAddCashPayment,
  });

  final Widget child;
  final QuickActionLauncher onAddCheque;
  final QuickActionLauncher onAddCashPayment;

  @override
  State<QuickActionsEdgePanel> createState() => _QuickActionsEdgePanelState();
}

class _QuickActionsEdgePanelState extends State<QuickActionsEdgePanel> {
  final GlobalKey _expandedPanelKey = GlobalKey();

  bool _isOpen = false;

  // Tracks only routes launched by this Edge Panel.
  // If another quick action is selected while one of these routes is still
  // active, the new form replaces the old quick-action form instead of
  // stacking underneath it.
  bool _quickActionRouteActive = false;
  int _quickActionGeneration = 0;

  // -1 = top, 0 = center, 1 = bottom.
  double _handleAlignmentY = 0;
  double _dragStartAlignmentY = 0;

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
    });
  }

  void _close() {
    if (!_isOpen) {
      return;
    }

    setState(() {
      _isOpen = false;
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_isOpen) {
      return;
    }

    final panelContext = _expandedPanelKey.currentContext;
    final renderObject = panelContext?.findRenderObject();

    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }

    final panelRect =
        renderObject.localToGlobal(Offset.zero) & renderObject.size;

    if (!panelRect.contains(event.position)) {
      // Listener does not consume the pointer event. The underlying page/menu
      // still receives the same tap while the panel closes automatically.
      _close();
    }
  }

  void _startHandleDrag(LongPressStartDetails details) {
    _dragStartAlignmentY = _handleAlignmentY;
  }

  void _updateHandleDrag(
    LongPressMoveUpdateDetails details,
    double availableHeight,
  ) {
    if (availableHeight <= 0) {
      return;
    }

    final alignmentDelta = (details.offsetFromOrigin.dy * 2) / availableHeight;

    final next = (_dragStartAlignmentY + alignmentDelta)
        .clamp(-1.0, 1.0)
        .toDouble();

    if (next == _handleAlignmentY) {
      return;
    }

    setState(() {
      _handleAlignmentY = next;
    });
  }

  Future<void> _run(QuickActionLauncher action) async {
    _close();

    final replaceCurrent = _quickActionRouteActive;

    _quickActionRouteActive = true;
    final generation = ++_quickActionGeneration;

    try {
      await action(replaceCurrent: replaceCurrent);
    } finally {
      // When route A is replaced by route B, A completes first. The generation
      // check prevents A from incorrectly marking B as inactive.
      if (mounted && generation == _quickActionGeneration) {
        _quickActionRouteActive = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment(1, _handleAlignmentY),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final offset = Tween<Offset>(
                        begin: const Offset(0.35, 0),
                        end: Offset.zero,
                      ).animate(animation);

                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: offset, child: child),
                      );
                    },
                    child: _isOpen
                        ? _ExpandedPanel(
                            key: _expandedPanelKey,
                            onClose: _close,
                            onAddCheque: () => _run(widget.onAddCheque),
                            onAddCashPayment: () =>
                                _run(widget.onAddCashPayment),
                          )
                        : _CollapsedHandle(
                            key: const ValueKey('quick-actions-collapsed'),
                            onTap: _toggle,
                            onLongPressStart: _startHandleDrag,
                            onLongPressMoveUpdate: (details) {
                              _updateHandleDrag(details, constraints.maxHeight);
                            },
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedHandle extends StatelessWidget {
  const _CollapsedHandle({
    super.key,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressMoveUpdate,
  });

  final VoidCallback onTap;
  final GestureLongPressStartCallback onLongPressStart;
  final GestureLongPressMoveUpdateCallback onLongPressMoveUpdate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'باز کردن میانبرها',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: onLongPressStart,
        onLongPressMoveUpdate: onLongPressMoveUpdate,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(24),
            ),
            child: Container(
              width: 22,
              height: 76,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.88),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(24),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 8,
                    offset: Offset(-2, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.chevron_left_rounded,
                size: 18,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedPanel extends StatelessWidget {
  const _ExpandedPanel({
    super.key,
    required this.onClose,
    required this.onAddCheque,
    required this.onAddCashPayment,
  });

  final VoidCallback onClose;
  final VoidCallback onAddCheque;
  final VoidCallback onAddCashPayment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 10,
      color: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 205,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'میانبرها',
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const Divider(height: 10),
                _QuickActionTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'ثبت چک',
                  onTap: onAddCheque,
                ),
                const SizedBox(height: 6),
                _QuickActionTile(
                  icon: Icons.account_balance_outlined,
                  label: 'ثبت واریزی',
                  onTap: onAddCashPayment,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.chevron_left_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
