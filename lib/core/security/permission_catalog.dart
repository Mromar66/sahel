/// Fine-grained page permissions stored per user.
class AppPermissionGroup {
  const AppPermissionGroup(this.title, this.permissions);

  final String title;
  final List<AppPermission> permissions;
}

class AppPermission {
  const AppPermission(this.code, this.label);

  final String code;
  final String label;
}

const List<AppPermissionGroup> appPermissionGroups = [
  AppPermissionGroup('الصفحات الرئيسية', [
    AppPermission('products', 'البضاعة والأصناف'),
    AppPermission('accounts', 'الحسابات'),
    AppPermission('invoices', 'أرشيف الفواتير'),
    AppPermission('treasury', 'الخزينة'),
    AppPermission('backup', 'النسخ الاحتياطي'),
  ]),
  AppPermissionGroup('المستندات', [
    AppPermission('sales', 'بيع'),
    AppPermission('purchases', 'شراء'),
    AppPermission('sales_return', 'مرتجع بيع'),
    AppPermission('purchase_return', 'مرتجع شراء'),
    AppPermission('quotation', 'عروض الأسعار'),
    AppPermission('receipts', 'سند قبض'),
    AppPermission('payments', 'سند صرف'),
  ]),
  AppPermissionGroup('المخازن', [
    AppPermission('stocktaking', 'جرد مخزن'),
    AppPermission('adjustment', 'تسوية مخزن'),
    AppPermission('transfer', 'تحويل لمخزن'),
    AppPermission('warehouse', 'إدارة المخازن'),
  ]),
  AppPermissionGroup('التقارير وكشوف الحساب', [
    AppPermission('reports', 'مركز التقارير'),
    AppPermission('daily_movement', 'الحركة اليومية'),
    AppPermission('sales_analysis', 'تحليل المبيعات'),
    AppPermission('purchase_analysis', 'تحليل المشتريات'),
    AppPermission('profit_loss', 'الأرباح والخسائر'),
    AppPermission('statements', 'كشوف الحساب'),
    AppPermission('checks', 'الشيكات والأقساط'),
  ]),
];

String? permissionForLocation(String location) {
  final path = Uri.tryParse(location)?.path ?? location;
  if (path == '/' || path == '/login' || path == '/initial-setup') return null;
  if (path == '/settings') return 'settings';
  if (path == '/products') return 'products';
  if (path == '/accounts') return 'accounts';
  if (path.startsWith('/accounts/statement') || path == '/accounts/items') {
    return 'statements';
  }
  if (path == '/accounts/checks') return 'checks';
  if (path == '/accounts/receipt') return 'receipts';
  if (path == '/accounts/payment') return 'payments';
  if (path == '/invoices') return 'invoices';
  if (path == '/treasury' || path == '/treasury-movement') return 'treasury';
  if (path == '/sales') return 'sales';
  if (path == '/sales-return') return 'sales_return';
  if (path == '/purchase-return') return 'purchase_return';
  if (path == '/quotation') return 'quotation';
  if (path == '/purchases') return 'purchases';
  if (path == '/stocktaking') return 'stocktaking';
  if (path == '/adjustment') return 'adjustment';
  if (path == '/transfer') return 'transfer';
  if (path == '/warehouse') return 'warehouse';
  if (path == '/reports') return 'reports';
  if (path == '/daily-movement') return 'daily_movement';
  if (path == '/sales-analysis') return 'sales_analysis';
  if (path == '/purchase-analysis') return 'purchase_analysis';
  if (path == '/profit-loss') return 'profit_loss';
  if (path == '/backup') return 'backup';
  return null;
}
