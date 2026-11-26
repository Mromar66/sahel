import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safwa/app/shell/app_window_tabs.dart';
import 'package:safwa/app/theme/app_theme.dart';
import 'package:safwa/core/security/permission_catalog.dart';
import 'package:safwa/core/services/auth_session.dart';
import 'package:safwa/core/utils/constants.dart';
import 'package:safwa/features/home/presentation/home_page.dart';
import 'package:safwa/features/settings/data/settings_repository.dart';

const _userDashboardInk = Color(0xFF202124);
const _userDashboardBlue = Color(0xFF2878D0);

/// Current-user dashboard modeled after DEXEF's personal user window.
class UserDashboardPage extends StatefulWidget {
  const UserDashboardPage({super.key});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  static const _sections = <(String, IconData)>[
    ('لوحة المستخدم', Icons.dashboard_outlined),
    ('خصائص المستخدم', Icons.person_outline),
    ('الصلاحيات', Icons.admin_panel_settings_outlined),
    ('سجل الدخول', Icons.history),
    ('التعاملات', Icons.receipt_long_outlined),
    ('إغلاقات اليومية', Icons.event_available_outlined),
    ('الأجهزة', Icons.devices_outlined),
    ('طريقة عرض الفواتير', Icons.description_outlined),
  ];

  String _section = _sections.first.$1;

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const HomePage(),
      const ModalBarrier(color: Colors.transparent, dismissible: false),
      Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(1080.0, constraints.maxWidth - 24);
            final height = math.min(740.0, constraints.maxHeight - 24);
            return SizedBox(
              width: width,
              height: height,
              child: Material(
                color: Colors.white,
                elevation: 12,
                clipBehavior: Clip.antiAlias,
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    children: [
                      _UserDashboardTitleBar(onClose: _close),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 230,
                              child: _profilePanel(),
                            ),
                            const VerticalDivider(width: 1, thickness: 1),
                            Expanded(
                              child: Column(
                                children: [
                                  _sectionBar(),
                                  Expanded(child: _sectionBody()),
                                ],
                              ),
                            ),
                          ],
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
    ],
  );

  Widget _profilePanel() {
    final user = AuthSession.instance.user;
    final role = user?.isAdmin == true ? 'مدير النظام' : 'مستخدم';
    return Container(
      color: const Color(0xFFF2F4F7),
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CircleAvatar(
            radius: 37,
            backgroundColor: const Color(0xFFE4F0FC),
            child: const Icon(Icons.person, size: 42, color: _userDashboardBlue),
          ),
          const SizedBox(height: 12),
          Text(
            user?.displayName ?? 'المستخدم',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _userDashboardInk,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            user?.username ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 14),
          _profileValue('نوع الحساب', role),
          _profileValue('حالة الاتصال', 'متصل'),
          const Divider(height: 22),
          Expanded(
            child: ListView(
              children: [
                for (final (label, icon) in _sections)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Material(
                      color: _section == label
                          ? const Color(0xFFDCEBFA)
                          : Colors.transparent,
                      child: ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: Icon(icon, size: 19, color: _userDashboardBlue),
                        title: Text(label, style: const TextStyle(fontSize: 11.5)),
                        selected: _section == label,
                        onTap: () => setState(() => _section = label),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileValue(String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 10.5, color: _userDashboardInk)),
      ],
    ),
  );

  Widget _sectionBar() => Container(
    height: 46,
    padding: const EdgeInsets.symmetric(horizontal: 15),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFD7DCE2))),
    ),
    alignment: Alignment.centerRight,
    child: Text(
      _section,
      style: const TextStyle(
        color: _userDashboardInk,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _sectionBody() => Padding(
    padding: const EdgeInsets.all(16),
    child: switch (_section) {
      'لوحة المستخدم' => _overview(),
      'خصائص المستخدم' => _preferences(),
      'الصلاحيات' => _permissions(),
      'سجل الدخول' => _loginHistory(),
      'التعاملات' => _transactions(),
      'إغلاقات اليومية' => _shifts(),
      'الأجهزة' => _devices(),
      'طريقة عرض الفواتير' => _invoiceDisplay(),
      _ => const SizedBox.shrink(),
    },
  );

  Widget _overview() {
    final user = AuthSession.instance.user;
    final permissionCount = user?.isAdmin == true
        ? appPermissionGroups.fold<int>(
            0,
            (count, group) => count + group.permissions.length,
          )
        : user?.permissions.length ?? 0;
    return ListView(
      children: [
        _infoHeader(
          'أهلاً ${user?.displayName ?? ''}',
          'لوحة المستخدم وإعداداته الشخصية.',
          Icons.waving_hand_outlined,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _summaryCard('الصلاحيات', '$permissionCount شاشة', Icons.verified_user_outlined),
            _summaryCard('الحالة', 'نشط', Icons.circle, color: const Color(0xFF43B5DB)),
            _summaryCard('تسجيل الدخول', 'محمي بكلمة سر', Icons.lock_outline),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'روابط سريعة',
          textAlign: TextAlign.right,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _routeButton('الفواتير', AppRoutes.invoices, Icons.receipt_long),
            _routeButton('الحسابات', AppRoutes.accounts, Icons.people_alt),
            _routeButton('الحركة اليومية', AppRoutes.dailyMovement, Icons.today),
          ],
        ),
      ],
    );
  }

  Widget _preferences() {
    final user = AuthSession.instance.user;
    if (user == null) return const SizedBox.shrink();
    return ListView(
      children: [
        _infoHeader('خصائص المستخدم', 'تفضيلات محفوظة للحساب الحالي.', Icons.tune),
        const SizedBox(height: 10),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: AppThemeController.mode,
          builder: (context, mode, _) => Material(
            color: Colors.white,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('استخدام الواجهة الفاتحة'),
              subtitle: Text(mode == ThemeMode.light ? 'الوضع الفاتح' : 'الوضع الداكن'),
              value: mode == ThemeMode.light,
              onChanged: (light) => _setTheme(light),
            ),
          ),
        ),
        _userPreferenceTile(
          keyName: 'confirm_save',
          title: 'التأكيد قبل حفظ التعاملات',
          defaultValue: false,
        ),
        _userPreferenceTile(
          keyName: 'preview_after_save',
          title: 'معاينة الفاتورة بعد الحفظ',
          defaultValue: true,
        ),
        const SizedBox(height: 8),
        const Text(
          'التأكيد والمعاينة محفوظين كتفضيلات للحساب. ربط تأثيرهم بكل نماذج المستندات لسه محتاج استكمال.',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _userPreferenceTile({
    required String keyName,
    required String title,
    required bool defaultValue,
  }) {
    final userId = AuthSession.instance.user?.id;
    if (userId == null) return const SizedBox.shrink();
    final repository = SettingsRepository.instance;
    final current = repository.readUserPreference(
      userId,
      keyName,
      defaultValue ? '1' : '0',
    );
    return Material(
      color: Colors.white,
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        value: current == '1',
        title: Text(title),
        onChanged: (value) async {
          await repository.saveUserPreference(
            userId,
            keyName,
            value == true ? '1' : '0',
          );
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _setTheme(bool light) async {
    AppThemeController.mode.value = light ? ThemeMode.light : ThemeMode.dark;
    await AuthSession.instance.saveCurrentUserPreference(
      'theme',
      light ? 'light' : 'dark',
    );
  }

  Widget _permissions() {
    final user = AuthSession.instance.user;
    if (user == null) return const SizedBox.shrink();
    final configuredUser = SettingsRepository.instance
        .users()
        .where((row) => row.id == user.id)
        .firstOrNull;
    final roles = SettingsRepository.instance
        .roles()
        .where((role) => configuredUser?.roleIds.contains(role.id) ?? false)
        .map((role) => role.name)
        .toList();
    return ListView(
      children: [
        _infoHeader(
          user.isAdmin ? 'مدير النظام' : 'الصلاحيات المسندة للحساب',
          user.isAdmin
              ? 'مدير النظام مسموح له فتح كل الصفحات.'
              : 'الصلاحيات بتتجمع من المجموعات المضافة والصلاحيات المباشرة.',
          Icons.admin_panel_settings_outlined,
        ),
        if (roles.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('مجموعات الصلاحيات: ${roles.join('، ')}'),
        ],
        for (final group in appPermissionGroups)
          ExpansionTile(
            title: Text(group.title),
            initiallyExpanded: true,
            children: [
              for (final permission in group.permissions)
                ListTile(
                  dense: true,
                  leading: Icon(
                    user.isAdmin || user.permissions.contains(permission.code)
                        ? Icons.check_circle
                        : Icons.block,
                    size: 17,
                    color:
                        user.isAdmin || user.permissions.contains(permission.code)
                        ? const Color(0xFF43B5DB)
                        : Colors.grey,
                  ),
                  title: Text(permission.label, style: const TextStyle(fontSize: 11)),
                  trailing: Text(
                    user.isAdmin || user.permissions.contains(permission.code)
                        ? 'مسموح'
                        : 'غير مسموح',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _loginHistory() {
    final rows = AuthSession.instance.loginHistoryForCurrentUser();
    if (rows.isEmpty) {
      return _emptyInfo('سجل الدخول', 'لسه مفيش حركات دخول محفوظة للحساب ده.');
    }
    return ListView(
      children: [
        _infoHeader('سجل الدخول', 'آخر محاولات الدخول والخروج للحساب الحالي.', Icons.history),
        const SizedBox(height: 8),
        for (final row in rows)
          ListTile(
            dense: true,
            leading: Icon(_eventIcon('${row['event_type']}'), size: 18),
            title: Text(_eventLabel('${row['event_type']}')),
            subtitle: Text('${row['event_time']}'),
          ),
      ],
    );
  }

  Widget _transactions() => _emptyInfo(
    'التعاملات',
    'صفو بيسجل الفواتير والحركات، بس ربط كل حركة باسم الموظف لسه مش مكتمل.',
    action: _routeButton('فتح أرشيف الفواتير', AppRoutes.invoices, Icons.receipt_long),
  );

  Widget _shifts() => _emptyInfo(
    'إغلاقات اليومية',
    'فتح وإغلاق الوردية مش متنفذ في صفو حالياً. تقدر تراجع الحركة اليومية من هنا.',
    action: _routeButton('فتح الحركة اليومية', AppRoutes.dailyMovement, Icons.today),
  );

  Widget _devices() => _emptyInfo(
    'الأجهزة',
    'صفو بيستخدم الطابعات المتاحة في ويندوز، وإدارة أجهزة المستخدم الخاصة لسه مش مربوطة.',
    action: _routeButton('فتح إعدادات الطباعة', AppRoutes.settings, Icons.print_outlined),
  );

  Widget _invoiceDisplay() => _emptyInfo(
    'طريقة عرض الفواتير',
    'إعدادات العرض التفصيلية لكل مستخدم لسه مش موجودة. تقدر تراجع الفواتير من الأرشيف.',
    action: _routeButton('فتح أرشيف الفواتير', AppRoutes.invoices, Icons.receipt_long),
  );

  Widget _infoHeader(String title, String subtitle, IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F6FB),
      border: Border.all(color: const Color(0xFFD8E4EF)),
    ),
    child: Row(
      children: [
        Icon(icon, color: _userDashboardBlue, size: 27),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _summaryCard(String title, String value, IconData icon, {Color? color}) =>
      SizedBox(
        width: 200,
        child: Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: color ?? _userDashboardBlue),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 11)),
                    Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _emptyInfo(String title, String message, {Widget? action}) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 36, color: Colors.blueGrey.shade400),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          if (action != null) ...[const SizedBox(height: 12), action],
        ],
      ),
    ),
  );

  Widget _routeButton(String label, String route, IconData icon) => OutlinedButton.icon(
    onPressed: () => openAppWindowTab(context, route),
    icon: Icon(icon, size: 18),
    label: Text(label),
  );

  IconData _eventIcon(String event) => switch (event) {
    'login_success' => Icons.login,
    'logout' => Icons.logout,
    _ => Icons.warning_amber_outlined,
  };

  String _eventLabel(String event) => switch (event) {
    'login_success' => 'دخول ناجح',
    'logout' => 'تسجيل خروج',
    _ => 'محاولة دخول غير ناجحة',
  };
}

class _UserDashboardTitleBar extends StatelessWidget {
  const _UserDashboardTitleBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    color: const Color(0xFFE7EAEE),
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Row(
      children: [
        IconButton(
          tooltip: 'إغلاق',
          onPressed: onClose,
          icon: const Icon(Icons.close, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 28, height: 26),
        ),
        const Spacer(),
        const Text(
          'إعدادات المستخدم',
          style: TextStyle(color: _userDashboardInk, fontSize: 11),
        ),
      ],
    ),
  );
}
