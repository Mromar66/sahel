import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:safwa/core/utils/constants.dart';
import 'package:safwa/core/services/auth_session.dart';
import 'package:safwa/app/theme/app_theme.dart';
import 'package:safwa/app/shell/program_search_dialog.dart';
import 'package:safwa/app/shell/app_window_tabs.dart';

export 'app_window_tabs.dart' show openAppWindowTab, removeCurrentAppTab;

/// Identifies which tab is currently active in the main shell.
enum AppTab { home, products, accounts }

class _TopNavEntry {
  const _TopNavEntry(this.label, this.route);

  final String label;
  final String route;
}

const Color _kNavText = Color(0xFF202124);
const MethodChannel _windowChannel = MethodChannel('safwa/window');

/// The Safwa reference client area. Every screen is laid out for exactly this
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
    this.showGlobalRail = true,
    this.showGlobalFooter = true,
    this.compactGlobalFooter = false,
    this.forceFrame = false,
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

  /// Allows report screens to keep the home tab inactive while a
  /// document tab is the active one.
  final bool homeTabActive;

  /// Width of the extra document tab (300 by default, 210 for vouchers).
  final double extraTabWidth;
  final bool showGlobalRail;
  final bool showGlobalFooter;
  final bool compactGlobalFooter;
  final bool forceFrame;

  @override
  Widget build(BuildContext context) {
    if (!forceFrame && DexefNavigationScope.maybeOf(context) != null) {
      return child;
    }
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
            Expanded(
              child: Row(
                textDirection: TextDirection.ltr,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: child),
                  if (showGlobalRail) const _DexefSideRail(),
                ],
              ),
            ),
            if (showGlobalFooter) _DexefFooter(compact: compactGlobalFooter),
          ],
        ),
      ),
    );
  }
}

class _DexefSideRail extends StatelessWidget {
  const _DexefSideRail();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      color: const Color(0xFFE7EAEE),
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          _RailAction(
            icon: Icons.home_filled,
            label: 'الرئيسية',
            onTap: () => openAppWindowTab(context, AppRoutes.home),
          ),
          _RailAction(
            icon: Icons.search,
            label: 'البحث في البرنامج',
            onTap: () => openProgramSearch(context),
          ),
          _RailAction(
            icon: Icons.grid_view_rounded,
            label: 'باقي المميزات',
            onTap: () => _showModules(context),
          ),
          _RailAction(
            icon: Icons.chat,
            label: 'خدمة العملاء',
            iconColor: const Color(0xFF43B5DB),
            onTap: () => _showTopBarMessage(
              context,
              'خدمة العملاء هتكون متاحة من هنا قريباً.',
            ),
          ),
          _RailAction(
            icon: Icons.people_alt,
            label: 'الحسابات',
            onTap: () => openAppWindowTab(context, AppRoutes.accounts),
          ),
        ],
      ),
    );
  }

  void _showModules(BuildContext context) {
    const modules = <(String, String)>[
      ('الأصناف', AppRoutes.products),
      ('العملاء والموردون', AppRoutes.accounts),
      ('فواتير المبيعات والمشتريات', AppRoutes.invoices),
      ('الخزينة', AppRoutes.treasury),
      ('المخازن', AppRoutes.warehouse),
      ('جرد مخزن', AppRoutes.stocktaking),
      ('تسوية مخزن', AppRoutes.adjustment),
      ('تحويل بين المخازن', AppRoutes.transfer),
      ('عروض الأسعار', AppRoutes.quotation),
      ('التقارير', AppRoutes.reports),
      ('الحركة اليومية', AppRoutes.dailyMovement),
      ('تحليل المبيعات', AppRoutes.salesAnalysis),
      ('الأرباح والخسائر', '/profit-loss'),
      ('الإعدادات', AppRoutes.settings),
      ('النسخ الاحتياطي', AppRoutes.backup),
    ];
    final available = modules
        .where((module) => AuthSession.instance.canOpenLocation(module.$2))
        .toList();
    if (available.isEmpty) return;
    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(20, 220, 44, 220),
      items: [
        for (final module in available)
          PopupMenuItem<String>(value: module.$2, child: Text(module.$1)),
      ],
    ).then((route) {
      if (route != null && context.mounted) openAppWindowTab(context, route);
    });
  }
}

class _RailAction extends StatefulWidget {
  const _RailAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = const Color(0xFF2877E6),
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  State<_RailAction> createState() => _RailActionState();
}

class _RailActionState extends State<_RailAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOut,
            width: 44,
            height: 58,
            color: _hovered ? const Color(0xFFD5E5FA) : Colors.transparent,
            alignment: Alignment.center,
            child: Icon(widget.icon, size: 24, color: widget.iconColor),
          ),
        ),
      ),
    );
  }
}

class _DexefFooter extends StatelessWidget {
  const _DexefFooter({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact)
          Container(
            height: 42,
            width: double.infinity,
            color: Colors.white,
            alignment: Alignment.center,
            child: const Text(
              'Safwa',
              style: TextStyle(
                color: Color(0xFF43B5DB),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Container(
          height: 28,
          color: const Color(0xFFF0F2F4),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            textDirection: TextDirection.ltr,
            children: [
              Text(
                AuthSession.instance.user?.displayName ?? 'المستخدم',
                style: const TextStyle(fontSize: 11, color: Color(0xFF41464B)),
              ),
              const Spacer(),
              const Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FooterCell(label: 'اشتراك'),
                    _FooterCell(label: 'Safwa'),
                    _FooterCell(label: 'فرع', icon: Icons.check_box),
                    _FooterCell(label: 'الفرع الرئيسي', icon: Icons.storefront),
                    _FooterCell(
                      label: 'الخزينة الرئيسية',
                      icon: Icons.account_balance_wallet,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FooterCell extends StatelessWidget {
  const _FooterCell({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFFD2D7DD))),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF41464B)),
          ),
          if (icon != null) ...[
            const SizedBox(width: 4),
            Icon(icon, size: 13, color: const Color(0xFF2182D5)),
          ],
        ],
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
    'ملف',
    'الفهرس',
    'الإضافات',
    'المبيعات',
    'المشتريات',
    'المخازن',
    'الحسابات',
    'العملاء والموردين',
    'التقارير',
  ];

  static const Map<String, List<_TopNavEntry>> _navEntries = {
    'ملف': [
      _TopNavEntry('الرئيسية', AppRoutes.home),
      _TopNavEntry('الإعدادات', AppRoutes.settings),
      _TopNavEntry('النسخ الاحتياطي', AppRoutes.backup),
    ],
    'الفهرس': [
      _TopNavEntry('الأصناف', AppRoutes.products),
      _TopNavEntry('إضافة صنف', '/products?new=1'),
      _TopNavEntry('العملاء', '/accounts?kind=customer'),
      _TopNavEntry('إضافة عميل', '/accounts?kind=customer&new=1'),
      _TopNavEntry('الموردون', '/accounts?kind=supplier'),
      _TopNavEntry('إضافة مورد', '/accounts?kind=supplier&new=1'),
      _TopNavEntry('حساب الأستاذ', '/accounts/statement'),
      _TopNavEntry('الشيكات', '/accounts/checks'),
    ],
    'الإضافات': [_TopNavEntry('الخصائص', AppRoutes.settings)],
    'المبيعات': [
      _TopNavEntry('فاتورة مبيعات', AppRoutes.sales),
      _TopNavEntry('مرتجع مبيعات', AppRoutes.salesReturn),
      _TopNavEntry('عروض الأسعار', AppRoutes.quotation),
      _TopNavEntry('مراجعة التعاملات', '/invoices?type=sale'),
    ],
    'المشتريات': [
      _TopNavEntry('فاتورة مشتريات', AppRoutes.purchases),
      _TopNavEntry('مرتجع مشتريات', AppRoutes.purchaseReturn),
      _TopNavEntry('مراجعة التعاملات', '/invoices?type=purchase'),
    ],
    'المخازن': [
      _TopNavEntry('الأصناف والأسعار والباركود', AppRoutes.products),
      _TopNavEntry('مراجعة المخازن', AppRoutes.warehouse),
      _TopNavEntry('التسويات الجردية', AppRoutes.stocktaking),
      _TopNavEntry('تسوية مخزن', AppRoutes.adjustment),
      _TopNavEntry('تحويل بين المخازن', AppRoutes.transfer),
    ],
    'الحسابات': [
      _TopNavEntry('استلام نقدية', '/accounts/receipt'),
      _TopNavEntry('دفع نقدية', '/accounts/payment'),
      _TopNavEntry('المصروفات', '/treasury-movement?new=expense'),
      _TopNavEntry('الإيرادات', '/treasury-movement?new=receive'),
      _TopNavEntry('الشيكات', '/accounts/checks'),
      _TopNavEntry('مراجعة حركة الخزينة', '/treasury-movement'),
    ],
    'العملاء والموردين': [
      _TopNavEntry('العملاء', '/accounts?kind=customer'),
      _TopNavEntry('الموردون', '/accounts?kind=supplier'),
      _TopNavEntry('مراجعة حساب العميل أو المورد', AppRoutes.accounts),
      _TopNavEntry('كشف الحساب', '/accounts/statement'),
    ],
    'التقارير': [
      _TopNavEntry('مركز التقارير', AppRoutes.reports),
      _TopNavEntry('الحركة اليومية', AppRoutes.dailyMovement),
      _TopNavEntry('تحليل المبيعات', AppRoutes.salesAnalysis),
      _TopNavEntry('تحليل المشتريات', '/purchase-analysis'),
      _TopNavEntry('الأرباح والخسائر', '/profit-loss'),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [_buildWindowTabs(context), _buildHomeNavigationBar(context)],
    );
  }

  Widget _buildWindowTabs(BuildContext context) {
    final location = GoRouter.of(context).routeInformationProvider.value.uri;
    final currentRoute = location.toString();
    final currentLabel = extraTabLabel ?? _windowTitle(location);
    final navigation = DexefNavigationScope.maybeOf(context);
    final hasCustomWindowsTitlebar =
        Theme.of(context).platform == TargetPlatform.windows;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DexefWindowTabs.remember(
        currentRoute,
        currentLabel,
        branchIndex: navigation?.branchIndexFor(currentRoute),
      );
    });

    return Container(
      height: 31,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F3F4),
        border: Border(bottom: BorderSide(color: Color(0xFFDADCE0))),
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          if (hasCustomWindowsTitlebar) const _WindowControls(),
          _buildWindowQuickActions(context),
          if (hasCustomWindowsTitlebar) const _WindowDragArea(),
          Expanded(
            child: ValueListenableBuilder<List<DexefWindowTab>>(
              valueListenable: DexefWindowTabs.tabs,
              builder: (context, tabs, _) {
                final visibleTabs = tabs.any((tab) => tab.route == currentRoute)
                    ? tabs
                    : [
                        ...tabs,
                        DexefWindowTab(
                          route: currentRoute,
                          label: currentLabel,
                        ),
                      ];
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final tab in visibleTabs)
                          SizedBox(
                            width: _windowTabWidth(tab.label),
                            height: 31,
                            child: _DocTab(
                              label: tab.label,
                              active: tab.route == currentRoute,
                              onTap: () => openAppWindowTab(context, tab.route),
                              onClose: tab.route == AppRoutes.home
                                  ? null
                                  : () => _closeWindowTab(
                                      context,
                                      tab,
                                      currentRoute,
                                    ),
                            ),
                          ),
                        const SizedBox(width: 3),
                        _PlusButton(
                          onTap: () =>
                              openAppWindowTab(context, AppRoutes.products),
                        ),
                        const SizedBox(width: 6),
                      ],
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

  double _windowTabWidth(String label) =>
      (label.runes.length * 8.3 + 42).clamp(106.0, 205.0).toDouble();

  String _windowTitle(Uri uri) {
    if (uri.path == AppRoutes.home) return 'الرئيسية';
    if (uri.path == AppRoutes.products) {
      return uri.queryParameters['new'] == '1' ? 'إضافة صنف' : 'مراجعة الأصناف';
    }
    if (uri.path == AppRoutes.accounts) {
      final kind = uri.queryParameters['kind'];
      if (uri.queryParameters['new'] == '1') {
        return kind == 'customer' ? 'إضافة عميل' : 'إضافة مورد';
      }
      return kind == 'customer'
          ? 'مراجعة العملاء'
          : kind == 'supplier'
          ? 'مراجعة الموردين'
          : 'العملاء والموردين';
    }
    if (uri.path == AppRoutes.sales) return 'مبيعات';
    if (uri.path == AppRoutes.purchases) return 'فاتورة مشتريات';
    if (uri.path == AppRoutes.invoices) return 'مراجعة الفواتير';
    if (uri.path == AppRoutes.reports) return 'التقارير';
    if (uri.path == AppRoutes.userDashboard) return 'إعدادات المستخدم';
    if (uri.path == AppRoutes.treasury) return 'حركة الخزينة';
    if (uri.path == AppRoutes.warehouse) return 'المخازن';
    if (uri.path == AppRoutes.salesAnalysis) return 'تحليل المبيعات';
    return switch (activeTab) {
      AppTab.home => uri.path.split('/').last,
      AppTab.products => 'الفهرس',
      AppTab.accounts => 'الحسابات',
    };
  }

  void _closeWindowTab(
    BuildContext context,
    DexefWindowTab tab,
    String currentRoute,
  ) {
    DexefWindowTabs.close(tab.route);
    if (tab.route != currentRoute) return;
    if (onExtraTabClose != null) {
      onExtraTabClose!();
      return;
    }
    final nextRoute = DexefWindowTabs.tabs.value.last.route;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(nextRoute);
    }
  }

  Widget _buildWindowQuickActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _quickAction(
          icon: Icons.search,
          label: 'البحث في البرنامج',
          onTap: () => openProgramSearch(context),
        ),
        _themeModeButton(),
        _quickMenuButton(context),
        _languageMenuButton(context),
        _quickAction(
          icon: Icons.translate,
          label: 'ترجمة البرنامج',
          onTap: () => _showTopBarMessage(
            context,
            'الواجهة العربية متاحة. الترجمة الإنجليزية لسه مش مضافة.',
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'المستخدم الحالي',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 190, maxWidth: 260),
          icon: const Icon(Icons.person, size: 20, color: Color(0xFF2677C9)),
          onSelected: (value) async {
            switch (value) {
              case 'user_settings':
                openAppWindowTab(context, AppRoutes.userDashboard);
              case 'change_password':
                await _showChangePasswordDialog(context);
              case 'close_shift':
                _showShiftCloseInfo(context);
              case 'logout':
                AuthSession.instance.logout();
                if (context.mounted) context.go('/login');
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Text(AuthSession.instance.user?.displayName ?? ''),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'user_settings',
              child: Text('إعدادات المستخدم'),
            ),
            const PopupMenuItem<String>(
              value: 'change_password',
              child: Text('تعديل الرقم السري'),
            ),
            const PopupMenuItem<String>(
              value: 'close_shift',
              child: Text('إغلاق الوردية'),
            ),
            const PopupMenuItem<String>(
              value: 'logout',
              child: Text('خروج المستخدم'),
            ),
          ],
        ),
        _quickAction(
          icon: Icons.settings,
          label: 'الإعدادات',
          onTap: () => openAppWindowTab(context, AppRoutes.settings),
        ),
      ],
    );
  }

  Widget _quickMenuButton(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'المساعدة وأدوات البرنامج',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 190, maxWidth: 280),
      icon: const Icon(
        Icons.format_list_bulleted,
        size: 19,
        color: Color(0xFFE87922),
      ),
      onSelected: (action) => _handleHelpAction(context, action),
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'program_menus',
          child: Text('التعديل على قوائم البرنامج'),
        ),
        PopupMenuItem<String>(value: 'help_files', child: Text('ملفات الشرح')),
        PopupMenuItem<String>(value: 'repair', child: Text('ضبط وإصلاح')),
        PopupMenuItem<String>(
          value: 'suggestions',
          child: Text('الشكاوى والمقترحات'),
        ),
        PopupMenuItem<String>(value: 'registration', child: Text('التسجيل')),
        PopupMenuItem<String>(value: 'about_company', child: Text('عن الشركة')),
      ],
    );
  }

  Widget _themeModeButton() => ValueListenableBuilder<ThemeMode>(
    valueListenable: AppThemeController.mode,
    builder: (context, mode, _) {
      final isLight = mode == ThemeMode.light;
      return Tooltip(
        message: isLight ? 'التبديل للوضع الداكن' : 'التبديل للوضع الفاتح',
        child: SizedBox(
          width: 42,
          height: 30,
          child: Center(
            child: Switch(
              value: isLight,
              onChanged: (_) => AppThemeController.toggle(),
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF237FE2),
              inactiveThumbColor: const Color(0xFFB7C0C9),
              inactiveTrackColor: const Color(0xFFE3E7EB),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      );
    },
  );

  Widget _languageMenuButton(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'لغة البرنامج',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
      icon: const Text(
        'ع',
        style: TextStyle(
          color: Color(0xFF2677C9),
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
      ),
      onSelected: (language) {
        _showTopBarMessage(
          context,
          language == 'ar'
              ? 'لغة البرنامج الحالية هي العربية.'
              : 'الواجهة الإنجليزية غير متاحة في النسخة الحالية.',
        );
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'ar',
          child: Row(
            children: [
              Icon(Icons.check, size: 16, color: Color(0xFF2677C9)),
              SizedBox(width: 8),
              Text('العربية'),
            ],
          ),
        ),
        PopupMenuItem<String>(value: 'en', child: Text('English · غير متاحة')),
      ],
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 30),
      icon: Icon(icon, size: 19, color: const Color(0xFF2677C9)),
    );
  }

  Widget _buildHomeNavigationBar(BuildContext context) {
    return Container(
      height: 42,
      color: const Color(0xFF0B82D5),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          IconButton(
            tooltip: 'الإشعارات',
            onPressed: () =>
                _showTopBarMessage(context, 'مفيش إشعارات جديدة دلوقتي.'),
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            iconSize: 21,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            constraints: const BoxConstraints.tightFor(width: 42, height: 42),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _menuButton(context),
                    ..._buildNavItems(context, homeStyle: true),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuButton(BuildContext context) {
    final available = _navLabels
        .expand(
          (group) => _availableNavEntries(group).map(
            (entry) => _TopNavEntry('$group · ${entry.label}', entry.route),
          ),
        )
        .toList();
    return PopupMenuButton<String>(
      tooltip: 'القائمة',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      icon: const Icon(Icons.menu, color: Colors.white, size: 20),
      onSelected: (route) => openAppWindowTab(context, route),
      itemBuilder: (context) => [
        for (final entry in available)
          PopupMenuItem<String>(value: entry.route, child: Text(entry.label)),
      ],
    );
  }

  List<Widget> _buildNavItems(BuildContext context, {bool homeStyle = false}) {
    final children = <Widget>[];
    for (var i = 0; i < _navLabels.length; i++) {
      if (_availableNavEntries(_navLabels[i]).isEmpty) continue;
      if (children.isNotEmpty) children.add(const SizedBox(width: 15.5));
      children.add(
        _navLink(context, _navLabels[i], bold: i == 0, homeStyle: homeStyle),
      );
    }
    return children;
  }

  Widget _navLink(
    BuildContext context,
    String label, {
    bool bold = false,
    bool homeStyle = false,
  }) {
    final entries = _availableNavEntries(label);
    return PopupMenuButton<String>(
      tooltip: label,
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 1),
      color: Colors.white,
      elevation: 5,
      constraints: const BoxConstraints(minWidth: 190, maxWidth: 270),
      onSelected: (route) => openAppWindowTab(context, route),
      itemBuilder: (context) => [
        for (final entry in entries)
          PopupMenuItem<String>(
            value: entry.route,
            height: 36,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                entry.label,
                style: const TextStyle(fontSize: 12.5, color: _kNavText),
              ),
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        child: SizedBox(
          height: 42,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: homeStyle ? Colors.white : _kNavText,
                fontSize: bold ? 12 : 11.5,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<_TopNavEntry> _availableNavEntries(String label) {
    final auth = AuthSession.instance;
    return (_navEntries[label] ?? const <_TopNavEntry>[])
        .where(
          (entry) =>
              entry.route == AppRoutes.home ||
              !auth.isAuthenticated ||
              auth.canOpenLocation(entry.route),
        )
        .toList();
  }
}

class _WindowDragArea extends StatelessWidget {
  const _WindowDragArea();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'اسحب لتحريك النافذة',
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) =>
              unawaited(_windowChannel.invokeMethod<void>('beginDrag')),
          onDoubleTap: () =>
              unawaited(_windowChannel.invokeMethod<void>('toggleMaximize')),
          child: const SizedBox(width: 36, height: 31),
        ),
      ),
    );
  }
}

class _WindowControls extends StatelessWidget {
  const _WindowControls();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowChromeButton(
          icon: Icons.close,
          label: 'إغلاق',
          isClose: true,
          onPressed: () =>
              unawaited(_windowChannel.invokeMethod<void>('close')),
        ),
        _WindowChromeButton(
          icon: Icons.crop_square,
          label: 'تكبير أو استعادة',
          onPressed: () =>
              unawaited(_windowChannel.invokeMethod<void>('toggleMaximize')),
        ),
        _WindowChromeButton(
          icon: Icons.minimize,
          label: 'تصغير',
          onPressed: () =>
              unawaited(_windowChannel.invokeMethod<void>('minimize')),
        ),
      ],
    );
  }
}

class _WindowChromeButton extends StatefulWidget {
  const _WindowChromeButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isClose = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  State<_WindowChromeButton> createState() => _WindowChromeButtonState();
}

class _WindowChromeButtonState extends State<_WindowChromeButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final fill = widget.isClose && _hovered
        ? const Color(0xFFE81123)
        : _hovered
        ? const Color(0xFFE3E7EB)
        : const Color(0xFFF1F3F4);
    return Tooltip(
      message: widget.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            width: 38,
            height: 31,
            color: fill,
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: 14,
              color: widget.isClose && _hovered
                  ? Colors.white
                  : const Color(0xFF40454B),
            ),
          ),
        ),
      ),
    );
  }
}

/// A document tab drawn as a trapezoid, matching the reference program.
class _DocTab extends StatelessWidget {
  const _DocTab({
    required this.label,
    required this.active,
    required this.onTap,
    required this.onClose,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: CustomPaint(
          painter: _DocTabPainter(active: active),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                bottom: 0,
                right: 14,
                left: onClose != null ? 27 : 12,
                child: Center(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
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
  const _DocTabPainter({required this.active});

  final bool active;

  static const Color _activeFill = Colors.white;
  static const Color _inactiveFill = Color(0xFFE8F0FE);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()..color = active ? _activeFill : _inactiveFill,
    );
    final border = Paint()
      ..color = const Color(0xFFD2D6DB)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), border);
    canvas.drawLine(Offset(0, 0), Offset(0, size.height), border);
    canvas.drawLine(
      Offset(size.width - 1, 0),
      Offset(size.width - 1, size.height),
      border,
    );
    if (!active) {
      canvas.drawLine(
        Offset(0, size.height - 1),
        Offset(size.width, size.height - 1),
        border,
      );
    }
  }

  @override
  bool shouldRepaint(_DocTabPainter oldDelegate) =>
      oldDelegate.active != active;
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

void _handleHelpAction(BuildContext context, String action) {
  switch (action) {
    case 'program_menus':
      openAppWindowTab(context, AppRoutes.settings);
    case 'help_files':
      _showTopBarInfo(
        context,
        'ملفات الشرح',
        'مركز الشروحات لسه مش متضاف في صفو. تقدر تفتح الأقسام المتاحة من القوائم الرئيسية والبحث.',
      );
    case 'repair':
      _showTopBarInfo(
        context,
        'ضبط وإصلاح',
        'أداة فحص وإصلاح قاعدة البيانات مش موجودة في صفو حالياً. النسخ الاحتياطي متاح من قائمة «ملف».',
      );
    case 'suggestions':
      _showTopBarInfo(
        context,
        'الشكاوى والمقترحات',
        'مفيش قناة إرسال مربوطة بصفو حالياً؛ مفيش حاجة هتتبعت من الجهاز.',
      );
    case 'registration':
      _showTopBarInfo(
        context,
        'التسجيل',
        'صفو مفيهوش تسجيل ترخيص أو اشتراك في النسخة الحالية.',
      );
    case 'about_company':
      _showTopBarHelp(context, about: true);
  }
}

void _showShiftCloseInfo(BuildContext context) {
  final canOpenDailyMovement = AuthSession.instance.canOpenLocation(
    AppRoutes.dailyMovement,
  );
  showDialog<void>(
    context: context,
    builder: (dialogContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('إغلاق الوردية'),
        content: const Text(
          'صفو معندوش إجراء إغلاق وردية أو تسوية عهدة حالياً. شاشة الحركة اليومية للمراجعة بس، ومش هتقفل الوردية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إغلاق'),
          ),
          if (canOpenDailyMovement)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                openAppWindowTab(context, AppRoutes.dailyMovement);
              },
              child: const Text('فتح الحركة اليومية'),
            ),
        ],
      ),
    ),
  );
}

Future<void> _showChangePasswordDialog(BuildContext context) async {
  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirmPassword = TextEditingController();
  String? error;
  bool busy = false;
  var changed = false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('تعديل الرقم السري'),
          content: SizedBox(
            width: 370,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'الرقم السري الحالي',
                  ),
                ),
                const SizedBox(height: 9),
                TextField(
                  controller: newPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'الرقم السري الجديد',
                  ),
                ),
                const SizedBox(height: 9),
                TextField(
                  controller: confirmPassword,
                  obscureText: true,
                  onSubmitted: (_) async {
                    if (busy) return;
                    if (newPassword.text != confirmPassword.text) {
                      setDialogState(
                        () => error = 'تأكيد الرقم السري مش مطابق.',
                      );
                      return;
                    }
                    setDialogState(() {
                      busy = true;
                      error = null;
                    });
                    final result = await AuthSession.instance
                        .changeCurrentPassword(
                          currentPassword: currentPassword.text,
                          newPassword: newPassword.text,
                        );
                    if (!dialogContext.mounted) return;
                    setDialogState(() {
                      busy = false;
                      error = result;
                    });
                    if (result == null) {
                      changed = true;
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'تأكيد الرقم السري الجديد',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (newPassword.text != confirmPassword.text) {
                        setDialogState(
                          () => error = 'تأكيد الرقم السري مش مطابق.',
                        );
                        return;
                      }
                      setDialogState(() {
                        busy = true;
                        error = null;
                      });
                      final result = await AuthSession.instance
                          .changeCurrentPassword(
                            currentPassword: currentPassword.text,
                            newPassword: newPassword.text,
                          );
                      if (!dialogContext.mounted) return;
                      setDialogState(() {
                        busy = false;
                        error = result;
                      });
                      if (result == null) {
                        changed = true;
                        Navigator.of(dialogContext).pop();
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    ),
  );
  currentPassword.dispose();
  newPassword.dispose();
  confirmPassword.dispose();
  if (changed && context.mounted) {
    _showTopBarMessage(context, 'اتغير الرقم السري بنجاح.');
  }
}

void _showTopBarHelp(BuildContext context, {required bool about}) {
  _showTopBarInfo(
    context,
    about ? 'عن صفو' : 'مساعدة الشريط',
    about
        ? 'صفو لإدارة المبيعات والمشتريات والمخازن والحسابات. الإصدار 1.0.0.'
        : 'استخدم البحث للوصول للشاشات، والقائمة الرئيسية لفتح الأقسام.',
  );
}

void _showTopBarInfo(BuildContext context, String title, String message) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message, textDirection: TextDirection.rtl),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    ),
  );
}
