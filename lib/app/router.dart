import 'package:go_router/go_router.dart';
import 'package:inventory_app/core/security/permission_catalog.dart';
import 'package:inventory_app/core/services/auth_session.dart';
import 'package:inventory_app/features/auth/presentation/auth_pages.dart';
import 'package:inventory_app/features/home/presentation/home_page.dart';
import 'package:inventory_app/features/products/presentation/products_list_page.dart';
import 'package:inventory_app/features/accounts/presentation/accounts_list_page.dart';
import 'package:inventory_app/features/accounts/presentation/checks_page.dart';
import 'package:inventory_app/features/accounts/presentation/receipt_payment_page.dart';
import 'package:inventory_app/features/accounts/presentation/statement_page.dart';
import 'package:inventory_app/features/treasury/presentation/treasury_movement_page.dart';
import 'package:inventory_app/features/invoice_ops/domain/invoice_op_models.dart';
import 'package:inventory_app/features/invoice_ops/presentation/invoice_op_page.dart';
import 'package:inventory_app/features/invoices/presentation/invoice_archive_page.dart';
import 'package:inventory_app/features/purchases/presentation/purchases_page.dart';
import 'package:inventory_app/features/stocktaking/presentation/stocktaking_page.dart';
import 'package:inventory_app/features/warehouse_ops/domain/warehouse_op_models.dart';
import 'package:inventory_app/features/warehouse_ops/presentation/warehouse_op_page.dart';
import 'package:inventory_app/features/warehouse/presentation/warehouse_page.dart';
import 'package:inventory_app/features/reports/presentation/reports_page.dart';
import 'package:inventory_app/features/reports/presentation/daily_movement_page.dart';
import 'package:inventory_app/features/reports/presentation/sales_analysis_page.dart';
import 'package:inventory_app/features/reports/presentation/purchase_analysis_page.dart';
import 'package:inventory_app/features/reports/presentation/profit_loss_page.dart';
import 'package:inventory_app/features/settings/presentation/settings_page.dart';
import 'package:inventory_app/features/backup/presentation/backup_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: AuthSession.instance,
  redirect: (context, state) {
    final auth = AuthSession.instance;
    final location = state.uri.path;
    if (!auth.initialized) return '/login';
    if (auth.setupRequired) {
      return location == '/initial-setup' ? null : '/initial-setup';
    }
    if (!auth.isAuthenticated) return location == '/login' ? null : '/login';
    if (location == '/login' || location == '/initial-setup') return '/';
    if (location == '/settings' && !auth.isAdmin) return '/';
    final permission = permissionForLocation(location);
    const publicLocations = {'/', '/access-denied'};
    if (permission == null && !publicLocations.contains(location)) {
      return '/access-denied';
    }
    if (permission != null && !auth.hasPermission(permission)) {
      return '/access-denied';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/initial-setup',
      builder: (context, state) => const InitialAdminSetupPage(),
    ),
    GoRoute(
      path: '/access-denied',
      builder: (context, state) => const AccessDeniedPage(),
    ),
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductsListPage(),
    ),
    GoRoute(
      path: '/accounts',
      builder: (context, state) => const AccountsListPage(),
    ),
    GoRoute(
      path: '/invoices',
      builder: (context, state) => const InvoiceArchivePage(),
    ),
    GoRoute(
      path: '/accounts/statement',
      builder: (context, state) =>
          StatementPage(accountId: _intParam(state.uri.queryParameters['id'])),
    ),
    GoRoute(
      path: '/accounts/items',
      builder: (context, state) => StatementPage(
        accountId: _intParam(state.uri.queryParameters['id']),
        byItems: true,
      ),
    ),
    GoRoute(
      path: '/accounts/checks',
      builder: (context, state) =>
          ChecksPage(accountId: _intParam(state.uri.queryParameters['id'])),
    ),
    GoRoute(
      path: '/accounts/receipt',
      builder: (context, state) => ReceiptPaymentPage(
        accountId: _intParam(state.uri.queryParameters['id']),
        editId: _intOrNull(state.uri.queryParameters['edit']),
      ),
    ),
    GoRoute(
      path: '/accounts/payment',
      builder: (context, state) => ReceiptPaymentPage(
        isReceipt: false,
        accountId: _intParam(state.uri.queryParameters['id']),
        editId: _intOrNull(state.uri.queryParameters['edit']),
      ),
    ),
    GoRoute(
      path: '/treasury',
      redirect: (context, state) => '/treasury-movement',
    ),
    GoRoute(
      path: '/treasury-movement',
      builder: (context, state) => const TreasuryMovementPage(),
    ),
    GoRoute(
      path: '/sales',
      builder: (context, state) => InvoiceOpPage(
        kind: InvoiceOpKind.sale,
        quotationId: _intOrNull(state.uri.queryParameters['quote']),
        editId: _intOrNull(state.uri.queryParameters['edit']),
      ),
    ),
    GoRoute(
      path: '/sales-return',
      builder: (context, state) => InvoiceOpPage(
        kind: InvoiceOpKind.salesReturn,
        editId: _intOrNull(state.uri.queryParameters['edit']),
      ),
    ),
    GoRoute(
      path: '/purchase-return',
      builder: (context, state) => InvoiceOpPage(
        kind: InvoiceOpKind.purchaseReturn,
        editId: _intOrNull(state.uri.queryParameters['edit']),
      ),
    ),
    GoRoute(
      path: '/quotation',
      builder: (context, state) => InvoiceOpPage(
        kind: InvoiceOpKind.quotation,
        editId: _intOrNull(state.uri.queryParameters['edit']),
      ),
    ),
    GoRoute(
      path: '/purchases',
      builder: (context, state) =>
          PurchasesPage(editId: _intOrNull(state.uri.queryParameters['edit'])),
    ),
    GoRoute(
      path: '/stocktaking',
      builder: (context, state) => StocktakingPage(
        editId: _intOrNull(state.uri.queryParameters['edit']),
      ),
    ),
    GoRoute(
      path: '/adjustment',
      builder: (context, state) => WarehouseOpPage(
        kind: WarehouseOpKind.adjustment,
        editId: _intOrNull(state.uri.queryParameters['edit']),
      ),
    ),
    GoRoute(
      path: '/transfer',
      builder: (context, state) => WarehouseOpPage(
        kind: WarehouseOpKind.transfer,
        editId: _intOrNull(state.uri.queryParameters['edit']),
      ),
    ),
    GoRoute(
      path: '/warehouse',
      builder: (context, state) => const WarehousePage(),
    ),
    GoRoute(path: '/reports', builder: (context, state) => const ReportsPage()),
    GoRoute(
      path: '/daily-movement',
      builder: (context, state) => const DailyMovementPage(),
    ),
    GoRoute(
      path: '/sales-analysis',
      builder: (context, state) => const SalesAnalysisPage(),
    ),
    GoRoute(
      path: '/purchase-analysis',
      builder: (context, state) => const PurchaseAnalysisPage(),
    ),
    GoRoute(
      path: '/profit-loss',
      builder: (context, state) => const ProfitLossPage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(path: '/backup', builder: (context, state) => const BackupPage()),
  ],
);

int _intParam(String? value) => int.tryParse(value ?? '') ?? 0;

int? _intOrNull(String? value) {
  final parsed = int.tryParse(value ?? '');
  return parsed == null || parsed <= 0 ? null : parsed;
}
