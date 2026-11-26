import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:safwa/app/shell/app_top_bar.dart';
import 'package:safwa/core/services/auth_session.dart';
import 'package:safwa/core/utils/constants.dart';

const double _tileGap = 8;

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      activeTab: AppTab.home,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/home_wood_background.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: Color(0xFFF5F4F1)),
            ),
          ),
          const Positioned.fill(child: _HomeMosaic()),
        ],
      ),
    );
  }
}

class _HomeMosaic extends StatelessWidget {
  const _HomeMosaic();

  static const List<_HomeTileData> _tiles = [
    _HomeTileData(
      label: 'التقارير',
      icon: Icons.insert_chart_outlined,
      color: Color(0xFF424B5D),
      route: AppRoutes.reports,
      column: 0,
      row: 0,
      columnSpan: 2,
      rowSpan: 2,
    ),
    _HomeTileData(
      label: 'فاتورة مشتريات',
      icon: Icons.receipt_long_outlined,
      color: Color(0xFF087DD2),
      route: AppRoutes.purchases,
      reviewRoute: '/invoices?type=purchase',
      column: 2,
      row: 0,
      columnSpan: 2,
    ),
    _HomeTileData(
      label: 'فاتورة مبيعات',
      icon: Icons.receipt_outlined,
      color: Color(0xFFD25532),
      route: AppRoutes.sales,
      reviewRoute: '/invoices?type=sale',
      column: 4,
      row: 0,
      columnSpan: 2,
    ),
    _HomeTileData(
      label: 'إضافة صنف',
      icon: Icons.layers_outlined,
      color: Color(0xFF43B5DB),
      route: AppRoutes.products,
      reviewRoute: AppRoutes.products,
      addRoute: '/products?new=1',
      column: 6,
      row: 0,
      columnSpan: 2,
    ),
    _HomeTileData(
      label: 'مرتجع مشتريات',
      icon: Icons.sync_outlined,
      color: Color(0xFF6B6B6B),
      route: AppRoutes.purchaseReturn,
      reviewRoute: '/invoices?type=purchaseReturn',
      column: 2,
      row: 1,
    ),
    _HomeTileData(
      label: 'دفع نقدية',
      icon: Icons.payments_outlined,
      color: Color(0xFF5D3CB5),
      route: '/accounts/payment',
      reviewRoute: '/invoices?type=payment',
      column: 3,
      row: 1,
    ),
    _HomeTileData(
      label: 'مرتجع مبيعات',
      icon: Icons.currency_exchange_outlined,
      color: Color(0xFF8DCDE2),
      route: AppRoutes.salesReturn,
      reviewRoute: '/invoices?type=salesReturn',
      column: 4,
      row: 1,
    ),
    _HomeTileData(
      label: 'استلام نقدية',
      icon: Icons.account_balance_wallet_outlined,
      color: Color(0xFF354DB8),
      route: '/accounts/receipt',
      reviewRoute: '/invoices?type=receipt',
      column: 5,
      row: 1,
    ),
    _HomeTileData(
      label: 'إضافة مورد',
      icon: Icons.groups_2_outlined,
      color: Color(0xFF424B5D),
      route: AppRoutes.accounts,
      reviewRoute: '/accounts?kind=supplier',
      addRoute: '/accounts?kind=supplier&new=1',
      column: 6,
      row: 1,
    ),
    _HomeTileData(
      label: 'إضافة عميل',
      icon: Icons.people_alt_outlined,
      color: Color(0xFF5D3CB5),
      route: AppRoutes.accounts,
      reviewRoute: '/accounts?kind=customer',
      addRoute: '/accounts?kind=customer&new=1',
      column: 7,
      row: 1,
    ),
    _HomeTileData(
      label: 'المصروفات',
      icon: Icons.money_outlined,
      color: Color(0xFF4D4D4D),
      route: AppRoutes.treasury,
      reviewRoute: AppRoutes.treasury,
      addRoute: '/treasury-movement?new=expense',
      column: 3,
      row: 2,
    ),
    _HomeTileData(
      label: 'الحركة اليومية',
      icon: Icons.trending_up,
      color: Color(0xFF2389E8),
      route: AppRoutes.dailyMovement,
      reviewRoute: AppRoutes.dailyMovement,
      addRoute: '/treasury-movement?new=receive',
      column: 5,
      row: 2,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.max(0.0, constraints.maxWidth - 64);
        final tileSize = math.min(
          120.0,
          math.min(
            (maxWidth - 72) / 8,
            (constraints.maxHeight - 40 - _tileGap * 2) / 3,
          ),
        );
        if (!tileSize.isFinite || tileSize <= 0) {
          return const SizedBox.shrink();
        }
        final gridWidth = tileSize * 8 + 72;
        final gridHeight = tileSize * 3 + _tileGap * 2;

        return Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Center(
            child: SizedBox(
              width: gridWidth,
              height: gridHeight,
              child: Stack(
                textDirection: TextDirection.ltr,
                children: [
                  for (final tile in _tiles)
                    if (AuthSession.instance.canOpenLocation(tile.route))
                      Positioned(
                        left: _columnPosition(tile.column, tileSize),
                        top: tile.row * (tileSize + _tileGap),
                        width:
                            tile.columnSpan * tileSize +
                            (tile.columnSpan - 1) * _tileGap,
                        height:
                            tile.rowSpan * tileSize +
                            (tile.rowSpan - 1) * _tileGap,
                        child: _HomeTile(
                          data: tile,
                          large: tile.columnSpan > 1 && tile.rowSpan > 1,
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

  double _columnPosition(int column, double tileSize) {
    const List<double> extraGaps = [0, 8, 24, 32, 40, 48, 64, 72];
    return column * tileSize + extraGaps[column];
  }
}

class _HomeTileData {
  const _HomeTileData({
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
    this.reviewRoute,
    this.addRoute,
    required this.column,
    required this.row,
    this.columnSpan = 1,
    this.rowSpan = 1,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String route;
  final String? reviewRoute;
  final String? addRoute;
  final int column;
  final int row;
  final int columnSpan;
  final int rowSpan;
}

class _HomeTile extends StatefulWidget {
  const _HomeTile({required this.data, this.large = false});

  final _HomeTileData data;
  final bool large;

  @override
  State<_HomeTile> createState() => _HomeTileState();
}

class _HomeTileState extends State<_HomeTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: data.color,
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          onTap: () => _goToHomeAction(context, data.route),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: _hovered && !widget.large ? 0 : 1,
                      child: Icon(
                        data.icon,
                        color: Colors.white,
                        size: widget.large ? 48 : 36,
                      ),
                    ),
                    SizedBox(height: widget.large ? 9 : 7),
                    Text(
                      data.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.large ? 14 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.large)
                Positioned(
                  top: 3,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: !_hovered,
                    child: Opacity(
                      opacity: _hovered ? 1 : 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _HomeTileAction(
                            label: 'مراجعة',
                            icon: Icons.format_list_bulleted,
                            accentColor: data.color,
                            onTap: data.reviewRoute == null
                                ? null
                                : () => _goToHomeAction(
                                    context,
                                    data.reviewRoute!,
                                  ),
                          ),
                          const SizedBox(width: 8),
                          _HomeTileAction(
                            label: 'إضافة',
                            icon: Icons.note_add_outlined,
                            accentColor: data.color,
                            onTap: () => _goToHomeAction(
                              context,
                              data.addRoute ?? data.route,
                            ),
                          ),
                        ],
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

class _HomeTileAction extends StatefulWidget {
  const _HomeTileAction({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  State<_HomeTileAction> createState() => _HomeTileActionState();
}

class _HomeTileActionState extends State<_HomeTileAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: widget.onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: SizedBox(
          width: 45,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                width: _hovered ? 42 : 40,
                height: _hovered ? 42 : 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _hovered ? Colors.white : Colors.transparent,
                  border: Border.all(color: Colors.white, width: 1.8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  widget.icon,
                  color: _hovered ? widget.accentColor : Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.label,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _goToHomeAction(BuildContext context, String route) {
  openAppWindowTab(context, route);
}
