import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Whether [AppSelectField] requires a valid list match or allows free text.
enum AppSelectMode {
  /// Only valid list options are accepted. Typing filters the list.
  /// On blur / Tab with no match: restores the previous committed value.
  select,

  /// Free text is also accepted. Typing filters as a suggestion.
  autocomplete,
}

const double _kItemHeight = 40.0;
const int _kMaxVisibleItems = 8;

/// Overlay-based select / autocomplete field with full keyboard support.
///
/// Keyboard contract
/// -----------------
/// - **Tab** in → overlay opens, existing value pre-highlighted.
/// - **↑ / ↓** → move highlight (works even after typing because a parent
///   [Focus] intercepts arrow keys before the TextField cursor handler).
/// - **Enter** → confirm highlighted / sole match; overlay closes, focus stays.
/// - **Tab** → confirm match (same as Enter); if no match, restore (select mode)
///   and let Tab propagate naturally to the next widget.
/// - **Escape** → close without change, restore previous value.
/// - **Typing** → filters the list live in both modes.
class AppSelectField<T> extends HookWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  final List<T> options;
  final String Function(T) getLabel;
  final AppSelectMode mode;
  final FocusNode? focusNode;

  const AppSelectField({
    super.key,
    required this.controller,
    required this.label,
    required this.options,
    required this.getLabel,
    this.mode = AppSelectMode.select,
    this.required = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final internalFn = useFocusNode();
    final fn = focusNode ?? internalFn;

    // Overlay state
    final overlayEntry = useRef<OverlayEntry?>(null);
    final isOpen = useState(false);
    final highlightedIndex = useState(-1);

    // Value before the user started editing — restored on Escape / invalid blur
    final committedValue = useRef(controller.text);

    // Live filter text; kept separate from controller so controller always
    // holds the last confirmed selection.
    final filterText = useState('');

    // Refs that are always current even inside stale closures
    final optionsRef = useRef<List<T>>(options);
    optionsRef.value = options;
    final filteredRef = useRef<List<T>>(options);

    // ValueNotifier used to force the overlay's ValueListenableBuilder to rebuild
    // without tearing down and re-inserting the OverlayEntry.
    final overlayVersion = useMemoized(() => ValueNotifier<int>(0), []);

    // ── Filtered list ─────────────────────────────────────────────────────
    final filtered = useMemoized<List<T>>(() {
      final q = filterText.value.toLowerCase();
      if (q.isEmpty) return options;
      return options
          .where((o) => getLabel(o).toLowerCase().contains(q))
          .toList();
    }, [options, filterText.value]);

    // Keep ref current every build (stale-closure safety)
    filteredRef.value = filtered;

    // NOTE: overlayVersion is bumped directly in each state-changing handler
    // (openOverlay, closeOverlay, onChanged, arrow-key handlers).
    // A useEffect that bumps it here would fire during the build phase on first
    // init and cause "setState called during build" errors.

    // ── Core helpers ───────────────────────────────────────────────────────

    void closeOverlay() {
      overlayEntry.value?.remove();
      overlayEntry.value = null;
      isOpen.value = false;
      highlightedIndex.value = -1;
      overlayVersion.value++;
    }

    /// Confirms [option]: writes its label to the controller, closes the
    /// overlay.  Focus is NOT advanced programmatically — Tab / Enter
    /// propagation is handled by returning the correct [KeyEventResult] in
    /// the key handler.
    void confirmOption(T option) {
      final lbl = getLabel(option);
      controller.text = lbl;
      committedValue.value = lbl;
      filterText.value = '';
      closeOverlay();
      // Do NOT call fn.nextFocus() here — Enter should keep focus on this
      // field; Tab lets the event propagate naturally after we close.
    }

    void openOverlay() {
      if (isOpen.value) return;
      final rb = fn.context?.findRenderObject() as RenderBox?;
      if (rb == null) return;

      isOpen.value = true;
      // Pre-highlight the currently committed value if it's in the list
      final cur = controller.text;
      final idx = filteredRef.value.indexWhere((o) => getLabel(o) == cur);
      highlightedIndex.value = idx;
      overlayVersion.value++;

      final offset = rb.localToGlobal(Offset.zero);
      final size = rb.size;

      overlayEntry.value = OverlayEntry(builder: (_) {
        return Positioned(
          left: offset.dx,
          top: offset.dy + size.height + 2,
          width: size.width,
          child: TapRegion(
            onTapOutside: (_) {
              if (mode == AppSelectMode.select) {
                final text = controller.text;
                if (optionsRef.value.every((o) => getLabel(o) != text)) {
                  controller.text = committedValue.value;
                }
              }
              filterText.value = '';
              closeOverlay();
            },
            child: ValueListenableBuilder<int>(
              valueListenable: overlayVersion,
              builder: (ctx, __, ___) {
                final items = filteredRef.value;
                final hi = highlightedIndex.value;

                if (items.isEmpty) {
                  return Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: _kItemHeight,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Keine Treffer',
                            style:
                                TextStyle(color: Theme.of(context).disabledColor),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(4),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: _kItemHeight * _kMaxVisibleItems),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemExtent: _kItemHeight,
                      itemBuilder: (_, i) {
                        final isHi = i == hi;
                        return InkWell(
                          // onTapDown fires on mouse-press, BEFORE the TextField
                          // loses focus (which would close the overlay too early).
                          onTapDown: (_) => confirmOption(items[i]),
                          child: Container(
                            height: _kItemHeight,
                            color: isHi
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                            alignment: Alignment.centerLeft,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              getLabel(items[i]),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isHi
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        );
      });

      Overlay.of(context).insert(overlayEntry.value!);
    }

    // ── Focus listener ─────────────────────────────────────────────────────
    useEffect(() {
      void onFocus() {
        if (fn.hasFocus) {
          committedValue.value = controller.text;
          filterText.value = '';
          openOverlay();
        } else {
          // Restore on blur in select mode if text is not a valid option
          if (mode == AppSelectMode.select) {
            final text = controller.text;
            if (options.every((o) => getLabel(o) != text)) {
              controller.text = committedValue.value;
            }
          }
          filterText.value = '';
          closeOverlay();
        }
      }

      fn.addListener(onFocus);
      return () => fn.removeListener(onFocus);
    }, [fn]);

    // ── Key handler ────────────────────────────────────────────────────────
    // Attached to the parent Focus (canRequestFocus: false) so it intercepts
    // arrow keys BEFORE the TextField's cursor-movement handler.
    // All state is accessed via .value on ValueNotifiers or useRef → stale-safe.
    KeyEventResult handleKey(FocusNode _, KeyEvent event) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
        return KeyEventResult.ignored;
      }

      final key = event.logicalKey;
      final items = filteredRef.value;

      if (key == LogicalKeyboardKey.arrowDown) {
        if (!isOpen.value) openOverlay();
        if (items.isNotEmpty) {
          highlightedIndex.value =
              (highlightedIndex.value + 1).clamp(0, items.length - 1);
          overlayVersion.value++;
        }
        // Consume so it doesn't move the text cursor
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.arrowUp) {
        if (!isOpen.value) openOverlay();
        if (items.isNotEmpty) {
          highlightedIndex.value =
              (highlightedIndex.value - 1).clamp(0, items.length - 1);
          overlayVersion.value++;
        }
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.enter) {
        if (isOpen.value && items.isNotEmpty) {
          final hi = highlightedIndex.value;
          final target = hi >= 0 ? hi : (items.length == 1 ? 0 : -1);
          if (target >= 0) {
            confirmOption(items[target]);
            // Return handled: overlay closed, focus stays → Enter does NOT
            // activate any dialog Save button.
            return KeyEventResult.handled;
          }
        }
        // Overlay is closed or no match: don't consume Enter (allow dialog default)
        return KeyEventResult.ignored;
      }

      if (key == LogicalKeyboardKey.tab) {
        if (isOpen.value && items.isNotEmpty) {
          final hi = highlightedIndex.value;
          final target = hi >= 0 ? hi : (items.length == 1 ? 0 : -1);
          if (target >= 0) {
            confirmOption(items[target]);
          } else if (mode == AppSelectMode.select) {
            // No valid match — restore
            controller.text = committedValue.value;
          }
          filterText.value = '';
          closeOverlay();
        }
        // Always let Tab propagate so focus advances naturally
        return KeyEventResult.ignored;
      }

      if (key == LogicalKeyboardKey.escape) {
        controller.text = committedValue.value;
        filterText.value = '';
        closeOverlay();
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    }

    // ── Build ──────────────────────────────────────────────────────────────
    // The parent Focus(canRequestFocus: false) sits ABOVE the TextField in the
    // focus tree. Key events bubble up from the focused TextField to this node,
    // so arrow keys are intercepted before the TextField's cursor-movement
    // handler runs. The Focus node itself is NOT a tab stop.
    return Focus(
      canRequestFocus: false,
      onKeyEvent: handleKey,
      child: TextField(
        controller: controller,
        focusNode: fn,
        onChanged: (value) {
          filterText.value = value;
          highlightedIndex.value = -1;
          overlayVersion.value++;
          if (!isOpen.value) openOverlay();
        },
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          isDense: true,
          border: const OutlineInputBorder(),
          suffixIcon: ExcludeFocus(
            child: ValueListenableBuilder<int>(
              valueListenable: overlayVersion,
              builder: (_, __, ___) => Icon(
                isOpen.value ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
