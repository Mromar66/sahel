import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_app/app/shell/app_top_bar.dart';
import 'package:inventory_app/core/utils/constants.dart';
import 'package:inventory_app/core/services/auth_session.dart';

/// Home dashboard built to match the reference design pixel-for-pixel.
///
/// Layout constants are taken from the reference screenshot (1279 px wide):
/// an 8-column grid of 120 px tiles with 6 px gaps, right-aligned with an
/// 8 px margin, for a total content width of 1002 px.
const double _kTileSize = 120;
const double _kTileGap = 6;
const double _kContentWidth = 1002;
const double _kGridOffset = 126; // one empty column + gap
const double _kQuickWidth = 498; // four columns + three gaps
const double _kReportWidth = 246; // two columns + one gap

const Color _kHoverYellow = Color(0xFFFBBC04);
const Color _kGreenTile = Color(0xFF34A853);
const Color _kReportsTile = Color(0xFF174EA6);
const Color _kQuickTile = Color(0xFF4285F4);

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      activeTab: AppTab.home,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Textured dark background (generated from the reference
          // texture with the exact vertical shading).
          Image.asset(
            'assets/images/page_background.png',
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
            errorBuilder: (_, error, stackTrace) =>
                const ColoredBox(color: Color(0xFF1E1E1E)),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.only(top: 8, right: 8, bottom: 24),
            child: Align(
              alignment: Alignment.topRight,
              child: SizedBox(
                width: _kContentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroRow(context),
                    const SizedBox(height: 22),
                    _buildSectionTitles(),
                    const SizedBox(height: 7),
                    _buildQuickAndReportsRow(context),
                    const SizedBox(height: 12),
                    _buildOperationsTitle(),
                    const SizedBox(height: 7),
                    _buildOperationsRowOne(context),
                    const SizedBox(height: 7),
                    _buildOperationsRowTwo(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero row: five green tiles + brand text + logo.
  // ---------------------------------------------------------------------------
  Widget _buildHeroRow(BuildContext context) {
    final tiles = <_TileSpec>[
      _TileSpec(
        'تقارير',
        'assets/icons/tile_hero_reports.png',
        _kGreenTile,
        AppRoutes.reports,
      ),
      _TileSpec(
        'الفواتير',
        'assets/icons/tile_hero_invoices.png',
        _kGreenTile,
        AppRoutes.invoices,
      ),
      _TileSpec(
        'الخزينة',
        'assets/icons/tile_hero_treasury.png',
        _kGreenTile,
        AppRoutes.treasury,
      ),
      _TileSpec(
        'الحسابات',
        'assets/icons/tile_hero_accounts.png',
        _kGreenTile,
        AppRoutes.accounts,
      ),
      _TileSpec(
        'البضاعة',
        'assets/icons/tile_hero_goods.png',
        _kGreenTile,
        AppRoutes.products,
      ),
    ];

    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) children.add(const SizedBox(width: _kTileGap));
      children.add(_DashboardTile(spec: tiles[i], width: _kTileSize));
    }
    children.add(const _BrandBlock());
    children.add(const _LogoBlock());

    return SizedBox(
      height: _kTileSize,
      child: Row(textDirection: TextDirection.ltr, children: children),
    );
  }

  // ---------------------------------------------------------------------------
  // Section titles row (reports on the second column group, quick actions on
  // the rightmost four columns).
  // ---------------------------------------------------------------------------
  Widget _buildSectionTitles() {
    return SizedBox(
      height: 19,
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          const SizedBox(width: _kGridOffset),
          SizedBox(
            width: _kReportWidth,
            child: _sectionTitle('تقارير', rightPadding: 1),
          ),
          const SizedBox(width: 132),
          SizedBox(
            width: _kQuickWidth,
            child: _sectionTitle('ابدأ بمشاهدة الجولة السريعة'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, {double rightPadding = 4}) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(right: rightPadding),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFEDEDED),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Reports tiles + quick actions tiles.
  // ---------------------------------------------------------------------------
  Widget _buildQuickAndReportsRow(BuildContext context) {
    final reports = <_TileSpec>[
      _TileSpec(
        'تحليل المبيعات',
        'assets/icons/tile_report_sales.png',
        _kReportsTile,
        AppRoutes.salesAnalysis,
      ),
      _TileSpec(
        'الحركة اليومية',
        'assets/icons/tile_report_daily.png',
        _kReportsTile,
        AppRoutes.dailyMovement,
      ),
    ];

    final quick = <_TileSpec>[
      _TileSpec(
        'إدخال الحسابات',
        'assets/icons/tile_quick_accounts.png',
        _kQuickTile,
        AppRoutes.accounts,
      ),
      _TileSpec(
        'إدخال الأصناف',
        'assets/icons/tile_quick_products.png',
        _kQuickTile,
        AppRoutes.products,
      ),
      _TileSpec(
        'إعداد صفو',
        'assets/icons/tile_quick_settings.png',
        _kQuickTile,
        AppRoutes.settings,
      ),
      _TileSpec(
        'أهلا بكم',
        'assets/icons/tile_quick_welcome.png',
        _kQuickTile,
        '',
      ),
    ];

    final children = <Widget>[
      const SizedBox(width: _kGridOffset),
      _DashboardTile(spec: reports[0], width: _kTileSize),
      const SizedBox(width: _kTileGap),
      _DashboardTile(spec: reports[1], width: _kTileSize),
      const SizedBox(width: 132),
    ];

    for (var i = 0; i < quick.length; i++) {
      if (i > 0) children.add(const SizedBox(width: _kTileGap));
      children.add(_DashboardTile(spec: quick[i], width: _kTileSize));
    }

    return SizedBox(
      height: _kTileSize,
      child: Row(textDirection: TextDirection.ltr, children: children),
    );
  }

  // ---------------------------------------------------------------------------
  // Operations.
  // ---------------------------------------------------------------------------
  Widget _buildOperationsTitle() {
    return SizedBox(
      height: 19,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Text(
            'حدد نوع المستند',
            style: const TextStyle(
              color: Color(0xFFEDEDED),
              fontSize: 13.2,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOperationsRowOne(BuildContext context) {
    final specs = <_TileSpec>[
      _TileSpec(
        'جرد مخزن',
        'assets/icons/tile_op_stocktake.png',
        const Color(0xFF188038),
        AppRoutes.stocktaking,
      ),
      _TileSpec(
        'صرف',
        'assets/icons/tile_op_expense.png',
        const Color(0xFFEA4335),
        '/accounts/payment',
      ),
      _TileSpec(
        'شراء',
        'assets/icons/tile_op_buy.png',
        const Color(0xFFEA4335),
        AppRoutes.purchases,
      ),
      _TileSpec(
        'بيع',
        'assets/icons/tile_op_sell.png',
        const Color(0xFF34A853),
        AppRoutes.sales,
      ),
    ];
    final widths = <double>[
      _kReportWidth,
      _kTileSize,
      _kReportWidth,
      _kReportWidth,
    ];

    final children = <Widget>[const SizedBox(width: _kGridOffset)];
    for (var i = 0; i < specs.length; i++) {
      if (i > 0) children.add(const SizedBox(width: _kTileGap));
      children.add(_DashboardTile(spec: specs[i], width: widths[i]));
    }

    return SizedBox(
      height: _kTileSize,
      child: Row(textDirection: TextDirection.ltr, children: children),
    );
  }

  Widget _buildOperationsRowTwo(BuildContext context) {
    final specs = <_TileSpec?>[
      _TileSpec(
        'تسوية مخزن',
        'assets/icons/tile_op_adjust.png',
        const Color(0xFF34A853),
        AppRoutes.adjustment,
      ),
      _TileSpec(
        'تحويل لمخزن',
        'assets/icons/tile_op_transfer.png',
        const Color(0xFF188038),
        AppRoutes.transfer,
      ),
      _TileSpec(
        'قبض',
        'assets/icons/tile_op_receive.png',
        const Color(0xFF34A853),
        '/accounts/receipt',
      ),
      null, // intentional empty column, exactly as in the reference
      _TileSpec(
        'مرتجع شراء',
        'assets/icons/tile_op_return_buy.png',
        const Color(0xFFB3261E),
        AppRoutes.purchaseReturn,
      ),
      _TileSpec(
        'عرض أسعار',
        'assets/icons/tile_op_quote.png',
        const Color(0xFF4285F4),
        AppRoutes.quotation,
      ),
      _TileSpec(
        'مرتجع بيع',
        'assets/icons/tile_op_return_sell.png',
        const Color(0xFF34A853),
        AppRoutes.salesReturn,
      ),
    ];

    final children = <Widget>[const SizedBox(width: _kGridOffset)];
    for (var i = 0; i < specs.length; i++) {
      if (i > 0) children.add(const SizedBox(width: _kTileGap));
      final spec = specs[i];
      if (spec == null) {
        children.add(const SizedBox(width: _kTileSize, height: _kTileSize));
      } else {
        children.add(_DashboardTile(spec: spec, width: _kTileSize));
      }
    }

    return SizedBox(
      height: _kTileSize,
      child: Row(textDirection: TextDirection.ltr, children: children),
    );
  }
}

// -----------------------------------------------------------------------------
// Brand text + logo.
// -----------------------------------------------------------------------------
class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 258,
      height: _kTileSize,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, right: 9, left: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'صفو لإدارة الأعمال',
              textAlign: TextAlign.right,
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Times New Roman',
                fontSize: 34.5,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            const SizedBox(height: 15),
            const SizedBox(
              width: double.infinity,
              child: Text(
                'إدارة المبيعات والمخازن\nوالحسابات بسهولة',
                textAlign: TextAlign.right,
                maxLines: 2,
                style: TextStyle(
                  color: Color(0xFFD8D8D8),
                  fontFamily: 'Times New Roman',
                  fontSize: 15.5,
                  height: 0.95,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoBlock extends StatelessWidget {
  const _LogoBlock();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kTileSize,
      height: _kTileSize,
      child: Image.asset(
        'assets/icons/logo.png',
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Dashboard tile.
// -----------------------------------------------------------------------------
class _DashboardTile extends StatelessWidget {
  const _DashboardTile({required this.spec, required this.width});

  final _TileSpec spec;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (spec.route.isNotEmpty &&
        !AuthSession.instance.canOpenLocation(spec.route)) {
      return SizedBox(width: width, height: _kTileSize);
    }
    return SizedBox(
      width: width,
      height: _kTileSize,
      child: _HoverTile(
        color: spec.color,
        onTap: () {
          if (spec.route.isEmpty) {
            _showMessage(context, 'أهلاً بكم في صفو لإدارة الأعمال.');
          } else if (spec.route == '/accounts/receipt' ||
              spec.route == '/accounts/payment') {
            // Keep the previous page underneath so «إغلاق» returns to it.
            context.push(spec.route);
          } else {
            context.go(spec.route);
          }
        },
        child: Column(
          children: [
            const SizedBox(height: 18),
            SizedBox(
              height: 81,
              width: double.infinity,
              child: Center(
                child: Image.asset(
                  spec.iconAsset,
                  width: 120,
                  height: 81,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (_, error, stackTrace) => const Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ),
            ),
            Text(
              spec.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Shared hover tile.
// -----------------------------------------------------------------------------
class _HoverTile extends StatefulWidget {
  const _HoverTile({required this.color, required this.child, this.onTap});

  final Color color;
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_HoverTile> createState() => _HoverTileState();
}

class _HoverTileState extends State<_HoverTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          mouseCursor: widget.onTap != null
              ? SystemMouseCursors.click
              : MouseCursor.defer,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: _hovered ? _kHoverYellow : widget.color,
              borderRadius: const BorderRadius.all(Radius.circular(2)),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Data holders + helpers.
// -----------------------------------------------------------------------------
class _TileSpec {
  const _TileSpec(this.label, this.iconAsset, this.color, this.route);

  final String label;
  final String iconAsset;
  final Color color;
  final String route;
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(fontSize: 13)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}
