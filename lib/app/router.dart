import 'package:go_router/go_router.dart';
import 'package:safwa/app/shell/dexef_workspace_shell.dart';
import 'package:safwa/core/security/permission_catalog.dart';
import 'package:safwa/core/services/auth_session.dart';
import 'package:safwa/features/auth/presentation/auth_pages.dart';
import 'package:safwa/features/home/presentation/home_page.dart';
import 'package:safwa/features/products/presentation/products_list_page.dart';
import 'package:safwa/features/accounts/presentation/accounts_list_page.dart';
import 'package:safwa/features/accounts/presentation/checks_page.dart';
import 'package:safwa/features/accounts/presentation/receipt_payment_page.dart';
import 'package:safwa/features/accounts/presentation/statement_page.dart';
import 'package:safwa/features/treasury/presentation/treasury_movement_page.dart';
import 'package:safwa/features/invoice_ops/domain/invoice_op_models.dart';
import 'package:safwa/features/invoice_ops/presentation/invoice_op_page.dart';
import 'package:safwa/features/invoices/presentation/invoice_archive_page.dart';
import 'package:safwa/features/purchases/presentation/purchases_page.dart';
import 'package:safwa/features/stocktaking/presentation/stocktaking_page.dart';
import 'package:safwa/features/warehouse_ops/domain/warehouse_op_models.dart';
import 'package:safwa/features/warehouse_ops/presentation/warehouse_op_page.dart';
import 'package:safwa/features/warehouse/presentation/warehouse_page.dart';
import 'package:safwa/features/reports/presentation/reports_page.dart';
import 'package:safwa/features/reports/presentation/daily_movement_page.dart';
import 'package:safwa/features/reports/presentation/sales_analysis_page.dart';
import 'package:safwa/features/reports/presentation/purchase_analysis_page.dart';
import 'package:safwa/features/reports/presentation/profit_loss_page.dart';
import 'package:safwa/features/settings/presentation/settings_page.dart';
import 'package:safwa/features/settings/presentation/user_dashboard_page.dart';
import 'package:safwa/features/backup/presentation/backup_page.dart';

const List<String> _appBranchPaths = [
  '/',
  '/products',
  '/accounts',
  '/invoices',
  '/accounts/statement',
  '/accounts/items',
  '/accounts/checks',
  '/accounts/receipt',
  '/accounts/payment',
  '/treasury-movement',
  '/sales',
  '/sales-return',
  '/purchase-return',
  '/quotation',
  '/purchases',
  '/stocktaking',
  '/adjustment',
  '/transfer',
  '/warehouse',
  '/reports',
  '/daily-movement',
  '/sales-analysis',
  '/purchase-analysis',
  '/profit-loss',
  '/settings',
  '/user-dashboard',
  '/backup',
];

final List<StatefulShellBranch> _appBranches = [
  StatefulShellBranch(
    routes: [GoRoute(path: '/', builder: (context, state) => const HomePage())],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/products',
        builder: (context, state) => ProductsListPage(
          openNewOnStart: state.uri.queryParameters['new'] == '1',
        ),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/accounts',
        builder: (context, state) {
          final kind = state.uri.queryParameters['kind'];
          return AccountsListPage(
            initialKind: kind == 'customer' || kind == 'supplier' ? kind : null,
            openNewOnStart: state.uri.queryParameters['new'] == '1',
          );
        },
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/invoices',
        builder: (context, state) =>
            InvoiceArchivePage(initialType: state.uri.queryParameters['type']),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/accounts/statement',
        builder: (context, state) => StatementPage(
          accountId: _intParam(state.uri.queryParameters['id']),
        ),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/accounts/items',
        builder: (context, state) => StatementPage(
          accountId: _intParam(state.uri.queryParameters['id']),
          byItems: true,
        ),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/accounts/checks',
        builder: (context, state) =>
            ChecksPage(accountId: _intParam(state.uri.queryParameters['id'])),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/accounts/receipt',
        builder: (context, state) => ReceiptPaymentPage(
          accountId: _intParam(state.uri.queryParameters['id']),
          editId: _intOrNull(state.uri.queryParameters['edit']),
        ),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/accounts/payment',
        builder: (context, state) => ReceiptPaymentPage(
          isReceipt: false,
          accountId: _intParam(state.uri.queryParameters['id']),
          editId: _intOrNull(state.uri.queryParameters['edit']),
        ),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/treasury-movement',
        builder: (context, state) =>
            TreasuryMovementPage(newMovement: state.uri.queryParameters['new']),
      ),
      GoRoute(
        path: '/treasury',
        redirect: (context, state) => '/treasury-movement',
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/sales',
        builder: (context, state) => InvoiceOpPage(
          kind: InvoiceOpKind.sale,
          quotationId: _intOrNull(state.uri.queryParameters['quote']),
          editId: _intOrNull(state.uri.queryParameters['edit']),
        ),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/sales-return',
        builder: (context, state) => InvoiceOpPage(
          kind: InvoiceOpKind.salesReturn,
          editId: _intOrNull(state.uri.queryParameters['edit']),
        ),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/purchase-return',
        builder: (context, state) => InvoiceOpPage(
          kind: InvoiceOpKind.purchaseReturn,
          editId: _intOrNull(state.uri.queryParameters['edit']),
        ),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/quotation',
        builder: (context, state) => InvoiceOpPage(
          kind: InvoiceOpKind.quotation,
          editId: _intOrNull(state.uri.queryParameters['edit']),
        ),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/purchases',
        builder: (context, state) => PurchasesPage(
          editId: _intOrNull(state.uri.queryParameters['edit']),
        ),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/stocktaking',
        builder: (context, state) => StocktakingPage(
          editId: _intOrNull(state.uri.queryParameters['edit']),
        ),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/adjustment',
        builder: (context, state) => WarehouseOpPage(
          kind: WarehouseOpKind.adjustment,
          editId: _intOrNull(state.uri.queryParameters['edit']),
        ),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/transfer',
        builder: (context, state) => WarehouseOpPage(
          kind: WarehouseOpKind.transfer,
          editId: _intOrNull(state.uri.queryParameters['edit']),
        ),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/warehouse',
        builder: (context, state) => const WarehousePage(),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsPage(),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/daily-movement',
        builder: (context, state) => const DailyMovementPage(),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/sales-analysis',
        builder: (context, state) => const SalesAnalysisPage(),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/purchase-analysis',
        builder: (context, state) => const PurchaseAnalysisPage(),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/profit-loss',
        builder: (context, state) => const ProfitLossPage(),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/user-dashboard',
        builder: (context, state) => const UserDashboardPage(),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(path: '/backup', builder: (context, state) => const BackupPage()),
    ],
  ),
];

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
    const publicLocations = {'/', '/access-denied', '/user-dashboard'};
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
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => DexefWorkspaceShell(
        navigationShell: navigationShell,
        branchPaths: _appBranchPaths,
      ),
      branches: _appBranches,
    ),
  ],
);

int _intParam(String? value) => int.tryParse(value ?? '') ?? 0;

int? _intOrNull(String? value) {
  final parsed = int.tryParse(value ?? '');
  return parsed == null || parsed <= 0 ? null : parsed;
}
