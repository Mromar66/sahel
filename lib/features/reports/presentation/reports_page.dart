import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:safwa/app/shell/app_top_bar.dart';
import 'package:safwa/app/theme/shop_colors.dart';
import 'package:safwa/app/widgets/hover_widgets.dart';

const Color _kGreen = ShopColors.panelGreen;
const Color _kYellow = ShopColors.yellow;
const Color _kInk = ShopColors.ink;
const Color _kBlue = Color(0xFF1E5FC7);
const Color _kGreyText = Color(0xFF8A8A8A);
const Color _kRowLine = Color(0xFFEAEAEA);

/// The Safwa reports launcher.
///
/// The page is deliberately a plain white list, exactly like the reference:
/// a green title on the right, a close button on the left and four report
/// rows whose icon sits at the far right of the row.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _focusNode = FocusScopeNode(debugLabel: 'reports-page');

  static const List<_ReportEntry> _entries = [
    _ReportEntry(
      title: 'تقرير الحركة اليومية',
      description: 'ملخص حركة الخزينة والأصناف خلال اليوم',
      asset: 'assets/icons/report_daily.png',
      route: '/daily-movement',
    ),
    _ReportEntry(
      title: 'تقرير تحليل المبيعات',
      description: 'تحليل المبيعات والأرباح حسب المخزن والحساب والصنف',
      asset: 'assets/icons/report_sales.png',
      route: '/sales-analysis',
    ),
    _ReportEntry(
      title: 'تقرير تحليل المشتريات',
      description: 'تحليل المشتريات والمرتجعات وتكلفة الشراء',
      asset: 'assets/icons/op_buy.png',
      route: '/purchase-analysis',
    ),
    _ReportEntry(
      title: 'الأرباح والخسائر',
      description: 'صافي الربح من الإيرادات وتكلفة البضاعة والمصروفات',
      asset: 'assets/icons/hero_treasury.png',
      route: '/profit-loss',
    ),
  ];

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _close() {
    removeCurrentAppTab(context);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return withPlainInputs(
      FocusScope(
        node: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: AppShell(
          activeTab: AppTab.home,
          homeTabActive: false,
          extraTabLabel: 'تقارير',
          extraTabColor: Colors.white,
          extraTabTextColor: _kInk,
          onExtraTabClose: _close,
          hideActiveTab: true,
          extraTabWidth: 180,
          child: Container(
            color: Colors.white,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 1018,
                    height: 618,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 4),
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: _entries.length,
                            itemBuilder: (context, index) => _reportRow(
                              _entries[index],
                              selected: index == 0,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildHeader() {
    return SizedBox(
      height: 54,
      child: Stack(
        children: [
          const Positioned(
            right: 28,
            top: 10,
            child: Text(
              'تقارير',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _kGreen,
                height: 1.05,
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 10,
            child: HoverBuilder(
              builder: (context, hovered) => Tooltip(
                message: 'إغلاق (Esc)',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: Container(
                    width: 86,
                    height: 24,
                    decoration: BoxDecoration(
                      color: hovered ? kHoverYellow : ShopColors.soft,
                      border: Border.all(color: const Color(0xFFD7D7D7)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      textDirection: TextDirection.rtl,
                      children: const [
                        Text(
                          'إغلاق',
                          style: TextStyle(fontSize: 11.5, color: _kInk),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.power_settings_new,
                          size: 14,
                          color: Color(0xFF2F2F2F),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportRow(_ReportEntry entry, {required bool selected}) {
    return HoverBuilder(
      builder: (context, hovered) {
        final highlighted = hovered || selected;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go(entry.route),
            mouseCursor: SystemMouseCursors.click,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: Container(
              height: 92,
              margin: const EdgeInsets.symmetric(horizontal: 26),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _kRowLine)),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: highlighted ? _kYellow : const Color(0xFFE7E7E7),
                    ),
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Image.asset(
                        entry.asset,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, error, stackTrace) => const Icon(
                          Icons.analytics_outlined,
                          color: _kBlue,
                          size: 38,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 19,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            color: highlighted
                                ? const Color(0xFF154EAA)
                                : _kBlue,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          entry.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.2,
                            color: _kGreyText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 26),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReportEntry {
  const _ReportEntry({
    required this.title,
    required this.description,
    required this.asset,
    required this.route,
  });

  final String title;
  final String description;
  final String asset;
  final String route;
}
