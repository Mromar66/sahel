import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_app/core/utils/constants.dart';
import 'package:inventory_app/core/security/permission_catalog.dart';
import 'package:inventory_app/core/services/auth_session.dart';

/// Identifies which tab is currently active in the main shell.
enum AppTab { home, products, accounts }

const Color _kNavBackground = Color(0xFFF8F9FA);
const Color _kNavText = Color(0xFF202124);
// A small overdraw closes the 1–4 px background seam at adjacent trapezoid
// corners while keeping the original left edge and centered label.
const double _kTabCornerBleed = 4;

/// The reference «صفو» client area. Every screen is laid out for exactly this
/// canvas and then scaled uniformly to whatever the window size is, so nothing
/// is ever stretched, clipped or distorted when the window is resized.
const Size kDesignCanvas = Size(1018, 673);

/// Shared application shell: the top navigation bar followed by the page.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.activeTab,
    required this.child,
    this.extraTabLabel,
    this.extraTabColor,
    this.extraTabTextColor,
    this.onExtraTabClose,
    this.hideActiveTab = false,
    this.homeTabActive = true,
    this.extraTabWidth = 300,
  });

  final AppTab activeTab;
  final Widget child;
  final String? extraTabLabel;
  final Color? extraTabColor;
  final Color? extraTabTextColor;
  final VoidCallback? onExtraTabClose;

  /// Hides the module tab (e.g. «الحسابات») so only the home pill and the
  /// document tab are shown, as in the voucher reference screens.
  final bool hideActiveTab;

  /// Allows report screens to keep the «ابدأ مع صفو» pill inactive while a
  /// document tab is the active one.
  final bool homeTabActive;

  /// Width of the extra document tab (300 by default, 210 for vouchers).
  final double extraTabWidth;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            AppTopBar(
              activeTab: activeTab,
              extraTabLabel: extraTabLabel,
              extraTabColor: extraTabColor,
              extraTabTextColor: extraTabTextColor,
              onExtraTabClose: onExtraTabClose,
              hideActiveTab: hideActiveTab,
              homeTabActive: homeTabActive,
              extraTabWidth: extraTabWidth,
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Top navigation bar with the application menu and the document tabs.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.activeTab,
    this.extraTabLabel,
    this.extraTabColor,
    this.extraTabTextColor,
    this.onExtraTabClose,
    this.hideActiveTab = false,
    this.homeTabActive = true,
    this.extraTabWidth = 300,
  });

  final AppTab activeTab;
  final String? extraTabLabel;
  final Color? extraTabColor;
  final Color? extraTabTextColor;
  final VoidCallback? onExtraTabClose;
  final bool hideActiveTab;
  final bool homeTabActive;
  final double extraTabWidth;

  static const List<String> _navLabels = [
    'برنامج صفو',
    'البضاعة',
    'الحسابات',
    'الخزينة',
    'الفواتير',
    'تقارير',
    'مساعدة',
    'خدمة العملاء',
    'اشتراكى',
  ];

  @override
  Widget build(BuildContext context) {
    final productsActive = activeTab == AppTab.products;
    final accountsActive = activeTab == AppTab.accounts;
    final hasDocTab = (productsActive || accountsActive) && !hideActiveTab;
    final extraTabRight = hasDocTab ? 421.0 : 211.0;
    final extraTabBleed = hasDocTab ? _kTabCornerBleed + 8 : _kTabCornerBleed;
    final extraTabPaintRight = extraTabLabel == null
        ? extraTabRight
        : extraTabRight - extraTabBleed;
    final extraTabPaintWidth = extraTabLabel == null
        ? extraTabWidth
        : extraTabWidth + extraTabBleed;

    final plusRight = extraTabLabel != null
        ? extraTabRight + extraTabWidth
        : (hasDocTab ? 421.0 : 221.0);

    return Container(
      height: 55,
      decoration: const BoxDecoration(
        color: _kNavBackground,
        border: Border(bottom: BorderSide(color: Color(0xFFDADCE0), width: 1)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 1,
            right: 11,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _buildNavItems(context),
            ),
          ),
          Positioned(
            top: 0,
            left: 8,
            child: PopupMenuButton<String>(
              tooltip: 'المستخدم الحالي',
              onSelected: (value) {
                if (value == 'logout') {
                  AuthSession.instance.logout();
                  context.go('/login');
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text(AuthSession.instance.user?.displayName ?? ''),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Text('تسجيل الخروج'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person, size: 14, color: _kNavText),
                    const SizedBox(width: 4),
                    Text(
                      AuthSession.instance.user?.displayName ?? '',
                      style: const TextStyle(color: _kNavText, fontSize: 11),
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: _kNavText,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Home tab (the "ابدأ مع صفو" pill).
          Positioned(
            right: 9,
            bottom: 0,
            width: 212,
            height: 31,
            child: _DocTab(
              label: 'ابدأ مع صفو',
              active: activeTab == AppTab.home && homeTabActive,
              onTap: () {
                if (activeTab != AppTab.home) {
                  context.go(AppRoutes.home);
                }
              },
              onClose: null,
            ),
          ),

          // Products / accounts tab.
          if (hasDocTab)
            Positioned(
              right: 211 - _kTabCornerBleed,
              bottom: 0,
              width: 212 + _kTabCornerBleed,
              height: 31,
              child: _DocTab(
                label: productsActive ? 'البضاعة' : 'الحسابات',
                active: true,
                onTap: () {},
                onClose: () => context.go(AppRoutes.home),
                contentShiftX: -_kTabCornerBleed / 2,
              ),
            ),

          // Optional extra document tab (statement / checks / voucher).
          if (extraTabLabel != null)
            Positioned(
              right: extraTabPaintRight,
              bottom: 0,
              width: extraTabPaintWidth,
              height: 31,
              child: _DocTab(
                label: extraTabLabel!,
                active: true,
                fillColor: extraTabColor,
                textColor: extraTabTextColor,
                onTap: () {},
                onClose: onExtraTabClose ?? () => context.go(AppRoutes.home),
                contentShiftX: -extraTabBleed / 2,
              ),
            ),

          // "+" small slanted button.
          Positioned(
            right: plusRight,
            bottom: 6,
            child: _PlusButton(
              onTap: () {
                if (!productsActive) {
                  context.go(AppRoutes.products);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNavItems(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < _navLabels.length; i++) {
      final route = _routeForNav(_navLabels[i]);
      if (route != null) {
        final permission = permissionForLocation(route);
        if (permission != null &&
            !AuthSession.instance.hasPermission(permission)) {
          continue;
        }
      }
      if (children.isNotEmpty) children.add(const SizedBox(width: 15.5));
      children.add(_navLink(context, _navLabels[i], bold: i == 0));
    }
    return children;
  }

  Widget _navLink(BuildContext context, String label, {bool bold = false}) {
    final route = _routeForNav(label);
    final text = Text(
      label,
      style: TextStyle(
        color: _kNavText,
        fontSize: bold ? 12 : 11.5,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        height: 1.2,
      ),
    );

    if (route == null) {
      return GestureDetector(
        onTap: () =>
            _showTopBarMessage(context, 'خدمة "$label" ستكون متاحة قريباً.'),
        child: MouseRegion(cursor: SystemMouseCursors.click, child: text),
      );
    }

    return GestureDetector(
      onTap: () => context.go(route),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: text),
    );
  }

  static String? _routeForNav(String label) {
    switch (label) {
      case 'البضاعة':
        return AppRoutes.products;
      case 'الحسابات':
        return AppRoutes.accounts;
      case 'الخزينة':
        return AppRoutes.treasury;
      case 'الفواتير':
        return AppRoutes.invoices;
      case 'تقارير':
        return AppRoutes.reports;
      default:
        return null;
    }
  }
}

/// A document tab drawn as a trapezoid, matching the reference program.
class _DocTab extends StatelessWidget {
  const _DocTab({
    required this.label,
    required this.active,
    required this.onTap,
    required this.onClose,
    this.fillColor,
    this.textColor,
    this.contentShiftX = 0,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClose;
  final Color? fillColor;
  final Color? textColor;
  final double contentShiftX;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: CustomPaint(
          painter: _DocTabPainter(active: active, fillColor: fillColor),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                bottom: 0,
                right: 14,
                left: onClose != null ? 27 : 12,
                child: Center(
                  child: Transform.translate(
                    offset: Offset(contentShiftX, 0),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor ?? const Color(0xFF1A1A1A),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
              if (onClose != null)
                Positioned(
                  left: 8,
                  top: 9,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onClose,
                    child: SizedBox(
                      width: 16,
                      height: 14,
                      child: CustomPaint(
                        painter: const _CloseGlyphPainter(
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocTabPainter extends CustomPainter {
  const _DocTabPainter({required this.active, this.fillColor});

  final bool active;
  final Color? fillColor;

  static const Color _activeFill = Colors.white;
  static const Color _inactiveFill = Color(0xFFE8F0FE);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const inset = 13.0;
    const r = 10.0;
    final len = math.sqrt(inset * inset + h * h);
    final dx = inset * r / len;
    final dy = h * r / len;

    final path = Path()
      ..moveTo(inset + r, 0)
      ..lineTo(w - inset - r, 0)
      ..quadraticBezierTo(w - inset, 0, w - inset + dx, dy)
      ..lineTo(w - dx, h - dy)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..lineTo(dx, h - dy)
      ..quadraticBezierTo(0, h, inset - dx, dy)
      ..lineTo(inset + r, 0)
      ..close();

    canvas.drawPath(
      path,
      Paint()..color = active ? (fillColor ?? _activeFill) : _inactiveFill,
    );

    final border = Paint()
      ..color = active ? const Color(0xFF4285F4) : const Color(0xFFAECBFA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawPath(
      Path()
        ..moveTo(w - inset - r, 0.6)
        ..quadraticBezierTo(w - inset, 0.6, w - inset + dx, dy)
        ..lineTo(w - 0.6, h),
      border,
    );
    canvas.drawPath(
      Path()
        ..moveTo(inset + r, 0.6)
        ..quadraticBezierTo(inset, 0.6, inset - dx, dy)
        ..lineTo(0.6, h),
      border,
    );

    canvas.drawLine(
      Offset(inset + r, 0.6),
      Offset(w - inset - r, 0.6),
      Paint()
        ..color = active ? const Color(0xFF1A73E8) : const Color(0xFFD2E3FC)
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_DocTabPainter oldDelegate) =>
      oldDelegate.active != active || oldDelegate.fillColor != fillColor;
}

class _PlusButton extends StatefulWidget {
  const _PlusButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_PlusButton> createState() => _PlusButtonState();
}

class _PlusButtonState extends State<_PlusButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: CustomPaint(
          painter: _SlantButtonPainter(
            fill: _hovered ? const Color(0xFFFBBC04) : const Color(0xFFF1F3F4),
            border: const Color(0xFFDADCE0),
          ),
          child: const SizedBox(
            width: 36,
            height: 19,
            child: Stack(
              children: [
                Positioned(
                  left: 12.5,
                  top: 4.5,
                  child: SizedBox(
                    width: 10,
                    height: 10,
                    child: CustomPaint(painter: _PlusGlyphPainter()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Slanted rounded rectangle used for the small "+" button.
class _SlantButtonPainter extends CustomPainter {
  const _SlantButtonPainter({required this.fill, required this.border});

  final Color fill;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const inset = 4.0;
    const r = 3.5;

    final len = math.sqrt(inset * inset + h * h);
    final sx = inset * r / len;
    final sy = h * r / len;

    final path = Path()
      ..moveTo(inset + r, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w - sx, sy)
      ..lineTo(w - inset + sx, h - sy)
      ..quadraticBezierTo(w - inset, h, w - inset - r, h)
      ..lineTo(r, h)
      ..quadraticBezierTo(0, h, sx, h - sy)
      ..lineTo(inset - sx, sy)
      ..quadraticBezierTo(inset, 0, inset + r, 0)
      ..close();

    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_SlantButtonPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.border != border;
}

class _PlusGlyphPainter extends CustomPainter {
  const _PlusGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.butt;

    final c = size.width / 2;
    canvas.drawLine(Offset(c - 4.5, c), Offset(c + 4.5, c), white);
    canvas.drawLine(Offset(c, c - 4.5), Offset(c, c + 4.5), white);
  }

  @override
  bool shouldRepaint(_PlusGlyphPainter oldDelegate) => false;
}

class _CloseGlyphPainter extends CustomPainter {
  const _CloseGlyphPainter({this.color = const Color(0xFF666666)});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    const pad = 4.0;
    canvas.drawLine(
      const Offset(pad, pad),
      Offset(size.width - pad, size.height - pad),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - pad, pad),
      Offset(pad, size.height - pad),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CloseGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}

void _showTopBarMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(fontSize: 13)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}
