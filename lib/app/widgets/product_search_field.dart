import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:inventory_app/app/models/product_search_item.dart';
import 'package:inventory_app/app/theme/shop_colors.dart';
import 'package:inventory_app/app/widgets/hover_widgets.dart';

/// Search box with the yellow «1» badge and a live product suggestion overlay.
/// Shared by شراء and جرد مخزن; the item type only has to implement
/// [ProductSearchItem].
class ProductSearchField<T extends ProductSearchItem> extends StatefulWidget {
  const ProductSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.lookup,
    required this.search,
    required this.onAdd,
    required this.onMessage,
    required this.onSubmit,
    this.hint = 'ابحث عن الصنف',
    this.badge = '1',
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<T?> Function(String) lookup;
  final Future<List<T>> Function(String) search;
  final ValueChanged<T> onAdd;
  final ValueChanged<String> onMessage;
  final ValueChanged<String> onSubmit;
  final String hint;
  final String badge;

  @override
  State<ProductSearchField<T>> createState() => ProductSearchFieldState<T>();
}

class ProductSearchFieldState<T extends ProductSearchItem>
    extends State<ProductSearchField<T>> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  Timer? _debounce;

  List<T> _results = const [];
  String _query = '';
  bool _loading = false;
  double _width = 300;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.focusNode.removeListener(_onFocus);
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onFocus() {
    if (widget.focusNode.hasFocus && widget.controller.text.trim().isNotEmpty) {
      _runSearch(widget.controller.text);
    } else if (!widget.focusNode.hasFocus) {
      Future<void>.delayed(const Duration(milliseconds: 220), () {
        if (mounted && !widget.focusNode.hasFocus) _hide();
      });
    }
  }

  void _onTextChanged() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) {
      _debounce?.cancel();
      _hide();
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 230),
      () => _runSearch(text),
    );
  }

  Future<void> _runSearch(String text) async {
    final generation = ++_generation;
    setState(() {
      _query = text;
      _loading = true;
    });
    _show();
    try {
      final results = await widget.search(text);
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
      widget.onMessage('تعذر البحث: $e');
    }
  }

  void _show() {
    if (!_portal.isShowing) _portal.show();
  }

  void _hide() {
    if (_portal.isShowing) _portal.hide();
    if (mounted) {
      setState(() {
        _results = const [];
        _loading = false;
      });
    }
  }

  void _pick(T product) {
    _hide();
    widget.focusNode.requestFocus();
    widget.onAdd(product);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = math.max(200, constraints.maxWidth);
        return CompositedTransformTarget(
          link: _link,
          child: OverlayPortal(
            controller: _portal,
            overlayChildBuilder: (_) => _buildOverlay(),
            child: Container(
              height: 27,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFB8B8B8)),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    width: 23,
                    height: 27,
                    color: ShopColors.yellow,
                    alignment: Alignment.center,
                    child: Text(
                      widget.badge,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ShopColors.ink,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      textAlign: TextAlign.right,
                      onSubmitted: (value) {
                        _hide();
                        widget.onSubmit(value);
                      },
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: ShopColors.ink,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        hintText: widget.hint,
                        hintStyle: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9A9A9A),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 5,
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
    );
  }

  Widget _buildOverlay() {
    final showEmpty = _results.isEmpty && !_loading;
    return CompositedTransformFollower(
      link: _link,
      showWhenUnlinked: false,
      targetAnchor: Alignment.bottomRight,
      followerAnchor: Alignment.topRight,
      offset: const Offset(0, 1),
      // Overlay entries are laid out with tight constraints; Align keeps the
      // panel at its natural size instead of filling the whole screen.
      child: Align(
        alignment: Alignment.topRight,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: _width,
            constraints: const BoxConstraints(maxHeight: 212),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFF9A9A9A)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: _loading
                ? const SizedBox(
                    height: 42,
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : showEmpty
                ? SizedBox(
                    height: 40,
                    child: Center(
                      child: Text(
                        'لا توجد نتائج لـ «$_query»',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF777777),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemExtent: 27,
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final product = _results[index];
                      return HoverBuilder(
                        builder: (context, hovered) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _pick(product),
                          child: Container(
                            color: hovered
                                ? kHoverYellow
                                : (index.isEven
                                      ? Colors.white
                                      : const Color(0xFFF4F4F4)),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Row(
                              textDirection: TextDirection.rtl,
                              children: [
                                SizedBox(
                                  width: 62,
                                  child: Text(
                                    product.code,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    product.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: ShopColors.ink,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${product.purchasePrice}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF336641),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'متاح ${product.available}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: Color(0xFF777777),
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
  }
}
