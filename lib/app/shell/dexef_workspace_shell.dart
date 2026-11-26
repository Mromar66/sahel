import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safwa/app/shell/app_top_bar.dart';
import 'package:safwa/app/shell/app_window_tabs.dart';

class DexefWorkspaceShell extends StatelessWidget {
  const DexefWorkspaceShell({
    super.key,
    required this.navigationShell,
    required this.branchPaths,
  });

  final StatefulNavigationShell navigationShell;
  final List<String> branchPaths;

  @override
  Widget build(BuildContext context) {
    final uri = GoRouter.of(context).routeInformationProvider.value.uri;
    return DexefNavigationScope(
      navigationShell: navigationShell,
      branchPaths: branchPaths,
      child: AppShell(
        forceFrame: true,
        activeTab: _activeTab(uri.path),
        extraTabLabel: _tabLabel(uri),
        compactGlobalFooter: uri.path == '/sales',
        child: navigationShell,
      ),
    );
  }

  AppTab _activeTab(String path) {
    if (path.startsWith('/accounts')) return AppTab.accounts;
    if (path == '/products' ||
        path == '/sales' ||
        path == '/purchases' ||
        path == '/invoices' ||
        path.endsWith('-return') ||
        path == '/quotation') {
      return AppTab.products;
    }
    return AppTab.home;
  }

  String _tabLabel(Uri uri) {
    final path = uri.path;
    if (path == '/') return 'الرئيسية';
    if (path == '/products') {
      return uri.queryParameters['new'] == '1' ? 'إضافة صنف' : 'مراجعة الأصناف';
    }
    if (path == '/accounts') {
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
    return switch (path) {
      '/sales' => 'فاتورة مبيعات',
      '/purchases' => 'فاتورة مشتريات',
      '/invoices' => 'مراجعة الفواتير',
      '/sales-return' => 'مرتجع مبيعات',
      '/purchase-return' => 'مرتجع مشتريات',
      '/quotation' => 'عروض الأسعار',
      '/accounts/receipt' => 'استلام نقدية',
      '/accounts/payment' => 'دفع نقدية',
      '/accounts/statement' => 'كشف حساب',
      '/accounts/items' => 'كشف حركة الأصناف',
      '/accounts/checks' => 'الشيكات',
      '/treasury' || '/treasury-movement' => 'حركة الخزينة',
      '/warehouse' => 'المخازن',
      '/stocktaking' => 'الجرد والتسوية',
      '/adjustment' => 'تسوية مخزن',
      '/transfer' => 'تحويل بين المخازن',
      '/reports' => 'تقارير',
      '/daily-movement' => 'الحركة اليومية',
      '/sales-analysis' => 'تحليل المبيعات',
      '/purchase-analysis' => 'تحليل المشتريات',
      '/profit-loss' => 'الأرباح والخسائر',
      '/settings' => 'الإعدادات',
      '/backup' => 'النسخ الاحتياطي',
      _ => path.split('/').last,
    };
  }
}
