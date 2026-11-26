import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safwa/app/shell/app_window_tabs.dart';
import 'package:safwa/app/theme/app_theme.dart';
import 'package:safwa/app/theme/shop_colors.dart';
import 'package:safwa/core/security/password_hasher.dart';
import 'package:safwa/core/security/permission_catalog.dart';
import 'package:safwa/core/services/auth_session.dart';
import 'package:safwa/core/utils/constants.dart';
import 'package:safwa/core/utils/currency_utils.dart';
import 'package:safwa/features/home/presentation/home_page.dart';
import 'package:safwa/features/settings/data/settings_repository.dart';
import 'package:safwa/features/settings/presentation/settings_dialogs.dart';

const _settingsBlue = Color(0xFF005EF4);
const _settingsGreen = Color(0xFF43B5DB);
const _settingsGray = Color(0xFFE8E8E8);
const _settingsInk = Color(0xFF171717);

/// Reference-style settings window shown over the existing dashboard.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _unlocked = false;
  int? _activeSettingsTab;
  String? _activeSettingsTitle;

  void _close() => context.go('/');

  void _openCategory(_SettingsCategory category) {
    if (category.tab != null) {
      setState(() {
        _activeSettingsTab = category.tab;
        _activeSettingsTitle = category.label;
      });
      return;
    }
    if (category.route != null) {
      if (category.routeNote != null) {
        showDialog<void>(
          context: context,
          builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(category.label),
              content: Text(category.routeNote!),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('رجوع'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    openAppWindowTab(context, category.route!);
                  },
                  child: const Text('فتح مركز التقارير'),
                ),
              ],
            ),
          ),
        );
        return;
      }
      openAppWindowTab(context, category.route!);
      return;
    }
    if (category.displaySettings) {
      _showDisplaySettings();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(category.label),
        content: Text(category.unavailableMessage ?? 'القسم غير متاح حالياً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noUnderlineTheme = theme.copyWith(
      textTheme: theme.textTheme.apply(
        decoration: TextDecoration.none,
        decorationColor: Colors.transparent,
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        labelStyle: theme.inputDecorationTheme.labelStyle?.copyWith(
          decoration: TextDecoration.none,
          decorationColor: Colors.transparent,
        ),
        hintStyle: theme.inputDecorationTheme.hintStyle?.copyWith(
          decoration: TextDecoration.none,
          decorationColor: Colors.transparent,
        ),
      ),
    );
    return Theme(
      data: noUnderlineTheme,
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          decoration: TextDecoration.none,
          decorationColor: Colors.transparent,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const HomePage(),
            const ModalBarrier(color: Colors.transparent, dismissible: false),
            Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = math.min(1002.0, constraints.maxWidth - 24);
                  final height = math.min(727.0, constraints.maxHeight - 24);
                  return Material(
                    type: MaterialType.transparency,
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: _unlocked
                          ? _activeSettingsTab == null
                                ? _SettingsCategoryWindow(
                                    onClose: _close,
                                    onSelect: _openCategory,
                                  )
                                : _SettingsWindow(
                                    initialTab: _activeSettingsTab!,
                                    title: _activeSettingsTitle ?? 'الخصائص',
                                    onClose: _close,
                                    onBack: () => setState(() {
                                      _activeSettingsTab = null;
                                      _activeSettingsTitle = null;
                                    }),
                                  )
                          : _SettingsPasswordWindow(
                              width: width,
                              onClose: _close,
                              onUnlocked: () =>
                                  setState(() => _unlocked = true),
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDisplaySettings() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('طريقة العرض'),
          content: ValueListenableBuilder<ThemeMode>(
            valueListenable: AppThemeController.mode,
            builder: (context, mode, _) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('استخدام الواجهة الفاتحة'),
              subtitle: Text(
                mode == ThemeMode.light
                    ? 'الوضع الفاتح شغال'
                    : 'الوضع الداكن شغال',
              ),
              value: mode == ThemeMode.light,
              onChanged: (_) => AppThemeController.toggle(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCategory {
  const _SettingsCategory({
    required this.label,
    required this.icon,
    required this.color,
    this.tab,
    this.route,
    this.routeNote,
    this.displaySettings = false,
    this.unavailableMessage,
  });

  final String label;
  final IconData icon;
  final Color color;
  final int? tab;
  final String? route;
  final String? routeNote;
  final bool displaySettings;
  final String? unavailableMessage;
}

const _settingsCategories = <_SettingsCategory>[
  _SettingsCategory(
    label: 'إعدادات النظام',
    icon: Icons.settings,
    color: Color(0xFF9BCBF1),
    tab: 0,
  ),
  _SettingsCategory(
    label: 'الفواتير',
    icon: Icons.description,
    color: Color(0xFFB982D9),
    tab: 2,
  ),
  _SettingsCategory(
    label: 'المخازن',
    icon: Icons.inventory_2,
    color: Color(0xFF74B9E7),
    tab: 0,
  ),
  _SettingsCategory(
    label: 'العملاء والموردين',
    icon: Icons.people_alt,
    color: Color(0xFF8B1E96),
    route: AppRoutes.accounts,
  ),
  _SettingsCategory(
    label: 'الضرائب',
    icon: Icons.account_balance_wallet,
    color: Color(0xFF9D1D2C),
    tab: 2,
  ),
  _SettingsCategory(
    label: 'صلاحيات المستخدمين',
    icon: Icons.person,
    color: Color(0xFF7DA6E5),
    tab: 0,
  ),
  _SettingsCategory(
    label: 'الأجهزة والطابعات',
    icon: Icons.devices,
    color: Color(0xFF1F4F8E),
    tab: 4,
  ),
  _SettingsCategory(
    label: 'طريقة العرض',
    icon: Icons.format_list_bulleted,
    color: Color(0xFFE28A6D),
    displaySettings: true,
  ),
  _SettingsCategory(
    label: 'شريط الأخبار',
    icon: Icons.rss_feed,
    color: Color(0xFF7185C5),
    unavailableMessage: 'إعداد شريط الأخبار مش موجود في صفو حالياً.',
  ),
  _SettingsCategory(
    label: 'الحقول الإضافية',
    icon: Icons.grid_view_rounded,
    color: Color(0xFF9A7A98),
    tab: 1,
  ),
  _SettingsCategory(
    label: 'الدورة المستندية',
    icon: Icons.autorenew,
    color: Color(0xFF80B7E8),
    unavailableMessage: 'إعداد مراحل الدورة المستندية مش موجود في صفو حالياً.',
  ),
  _SettingsCategory(
    label: 'الإضافات',
    icon: Icons.extension,
    color: Color(0xFF9A993E),
    unavailableMessage: 'إدارة إضافات خارجية مش موجودة في صفو حالياً.',
  ),
  _SettingsCategory(
    label: 'تصميم التقارير',
    icon: Icons.design_services,
    color: Color(0xFF334B9B),
    route: AppRoutes.reports,
    routeNote: 'صفو فيه مركز تقارير حالياً، لكن مصمم نماذج التقارير زي دكسف لسه مش متنفذ.',
  ),
];

class _SettingsCategoryWindow extends StatelessWidget {
  const _SettingsCategoryWindow({
    required this.onClose,
    required this.onSelect,
  });

  final VoidCallback onClose;
  final ValueChanged<_SettingsCategory> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFB7B7B7)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55000000),
          blurRadius: 18,
          offset: Offset(0, 7),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        _SettingsTitleBar(onClose: onClose, title: 'الخصائص'),
        Expanded(
          child: Center(
            child: SizedBox(
              width: 820,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisExtent: 142,
                ),
                itemCount: _settingsCategories.length,
                itemBuilder: (context, index) {
                  final category = _settingsCategories[index];
                  return _SettingsCategoryTile(
                    category: category,
                    onTap: () => onSelect(category),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SettingsCategoryTile extends StatefulWidget {
  const _SettingsCategoryTile({required this.category, required this.onTap});

  final _SettingsCategory category;
  final VoidCallback onTap;

  @override
  State<_SettingsCategoryTile> createState() => _SettingsCategoryTileState();
}

class _SettingsCategoryTileState extends State<_SettingsCategoryTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: InkWell(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.all(5),
        color: _hovered ? const Color(0xFFEAF4FC) : Colors.white,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.category.icon, size: 52, color: widget.category.color),
            const SizedBox(height: 10),
            Text(
              widget.category.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.black),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SettingsPasswordWindow extends StatefulWidget {
  const _SettingsPasswordWindow({
    required this.width,
    required this.onClose,
    required this.onUnlocked,
  });

  final double width;
  final VoidCallback onClose;
  final VoidCallback onUnlocked;

  @override
  State<_SettingsPasswordWindow> createState() =>
      _SettingsPasswordWindowState();
}

class _SettingsPasswordWindowState extends State<_SettingsPasswordWindow> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final valid = await AuthSession.instance.verifyAdminPassword(
      _password.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!valid) _error = 'كلمة مرور المدير غير صحيحة.';
    });
    if (valid) widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFB7B7B7)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55000000),
          blurRadius: 18,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: Column(
      children: [
        _SettingsTitleBar(onClose: widget.onClose),
        Expanded(
          child: Center(
            child: Container(
              width: math.min(750, widget.width - 40),
              height: 250,
              padding: const EdgeInsets.fromLTRB(40, 24, 40, 24),
              decoration: BoxDecoration(
                color: const Color(0xFF4C8BF0),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Icon(Icons.help_outline, size: 30, color: Colors.black),
                      SizedBox(width: 12),
                      Text(
                        'أدخل كلمة سر المدير',
                        style: TextStyle(
                          fontSize: 19,
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _password,
                      obscureText: true,
                      autofocus: true,
                      onSubmitted: (_) => _verify(),
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFF9D2417),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 40,
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _verify,
                          icon: _busy
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check, size: 19),
                          label: const Text('موافق'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF7D244),
                            foregroundColor: Colors.black,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 180,
                        height: 40,
                        child: ElevatedButton.icon(
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close, color: Colors.black54),
                          label: const Text('تراجع'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE7E7E7),
                            foregroundColor: Colors.black,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SettingsWindow extends StatefulWidget {
  const _SettingsWindow({
    required this.initialTab,
    required this.title,
    required this.onClose,
    required this.onBack,
  });

  final int initialTab;
  final String title;
  final VoidCallback onClose;
  final VoidCallback onBack;

  @override
  State<_SettingsWindow> createState() => _SettingsWindowState();
}

class _SettingsWindowState extends State<_SettingsWindow> {
  final _repo = SettingsRepository.instance;
  static const _tabs = [
    'عام',
    'حقول إضافية',
    'الضرائب والفوترة',
    'كلمات السر',
    'أخرى',
    'إعداد المطعم',
  ];
  late final Map<String, TextEditingController> _fields;
  late int _tab;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _warehouses = const [];
  List<Map<String, dynamic>> _treasuries = const [];
  List<Map<String, dynamic>> _paymentMethods = const [];
  List<Map<String, dynamic>> _currencies = const [];
  List<SettingsUser> _users = const [];
  int? _selectedWarehouse;
  String? _selectedOther;
  int? _selectedUser;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _fields = {
      'project_name': TextEditingController(
        text: _repo.read('settings.project_name', 'معرضنا'),
      ),
      'contact': TextEditingController(text: _repo.read('settings.contact')),
      'phone': TextEditingController(text: _repo.read('settings.phone')),
      'address': TextEditingController(text: _repo.read('settings.address')),
      'price_1': TextEditingController(
        text: _repo.read('settings.price_1', 'سعر البيع'),
      ),
      'price_2': TextEditingController(
        text: _repo.read('settings.price_2', 'سعر البيع الثاني'),
      ),
      'price_3': TextEditingController(
        text: _repo.read('settings.price_3', 'سعر البيع الثالث'),
      ),
      'price_4': TextEditingController(
        text: _repo.read('settings.price_4', 'سعر البيع الرابع'),
      ),
      'last_price_months': TextEditingController(
        text: _repo.read('settings.customer_last_price_months', '3'),
      ),
      'tax_number': TextEditingController(
        text: _repo.read('settings.tax_number'),
      ),
      'commercial_register': TextEditingController(
        text: _repo.read('settings.commercial_register'),
      ),
      'tax1_name': TextEditingController(
        text: _repo.read('settings.tax_1_name'),
      ),
      'tax1_percent': TextEditingController(
        text: _repo.read('settings.tax_1_percent', '0'),
      ),
      'tax2_name': TextEditingController(
        text: _repo.read('settings.tax_2_name'),
      ),
      'tax2_percent': TextEditingController(
        text: _repo.read('settings.tax_2_percent', '0'),
      ),
      'barcode_prefix': TextEditingController(
        text: _repo.read('settings.scale_barcode_prefix', '00'),
      ),
      'barcode_code_digits': TextEditingController(
        text: _repo.read('settings.scale_code_digits', '5'),
      ),
      'barcode_weight_digits': TextEditingController(
        text: _repo.read('settings.scale_weight_digits', '5'),
      ),
      'barcode_total_digits': TextEditingController(
        text: _repo.read('settings.scale_total_digits', '5'),
      ),
      'image_folder': TextEditingController(
        text: _repo.read('settings.product_image_folder', ''),
      ),
      'copies': TextEditingController(
        text: _repo.read('settings.invoice_print_copies', '1'),
      ),
      'expiry_after_buy': TextEditingController(
        text: _repo.read('settings.expiry_after_buy_days', '0'),
      ),
      'expiry_before': TextEditingController(
        text: _repo.read('settings.expiry_warning_days', '0'),
      ),
    };
    _reloadLists();
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _reloadLists() {
    setState(() {
      _warehouses = _repo.warehouses();
      _treasuries = _repo.treasuries();
      _paymentMethods = _repo.paymentMethods();
      _currencies = _repo.currencies();
      _users = _repo.users();
      _loading = false;
    });
  }

  Future<void> _run(
    Future<void> Function() operation, {
    String? message,
  }) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await operation();
      if (!mounted) return;
      _reloadLists();
      if (message != null) _toast(message);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst(
            'SettingsValidationException: ',
            '',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveValues(Map<String, String> values, {String? message}) =>
      _run(() => _repo.save(values), message: message ?? 'تم حفظ الإعدادات.');

  void _toast(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.right),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFB7B7B7)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55000000),
          blurRadius: 18,
          offset: Offset(0, 7),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          _SettingsTitleBar(onClose: widget.onClose, title: widget.title),
          _buildHeader(),
          _buildTabs(),
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              color: const Color(0xFFFFE2E0),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFF9D2417), fontSize: 11),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildTabBody(),
          ),
        ],
      ),
    ),
  );

  Widget _buildHeader() => SizedBox(
    height: 40,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: widget.onClose,
            icon: const Icon(
              Icons.power_settings_new,
              size: 18,
              color: Colors.black,
            ),
            label: const Text(
              'إغلاق',
              style: TextStyle(fontSize: 12, color: Colors.black),
            ),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFF7D244),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              fixedSize: const Size(126, 31),
            ),
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(
              Icons.arrow_forward,
              size: 16,
              color: Colors.black,
            ),
            label: const Text(
              'كل الخصائص',
              style: TextStyle(fontSize: 11, color: Colors.black),
            ),
          ),
          const Spacer(),
          Text(
            widget.title,
            style: TextStyle(
              color: Color(0xFF43B5DB),
              fontSize: 24,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildTabs() => SizedBox(
    height: 34,
    child: Row(
      children: [
        for (var i = 0; i < _tabs.length; i++)
          Expanded(
            child: _SettingsTab(
              label: _tabs[i],
              selected: _tab == i,
              disabled: i == 5,
              onTap: i == 5 ? null : () => setState(() => _tab = i),
            ),
          ),
      ],
    ),
  );

  Widget _buildTabBody() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
    child: switch (_tab) {
      0 => _generalTab(),
      1 => _additionalFieldsTab(),
      2 => _taxTab(),
      3 => _passwordTab(),
      4 => _otherTab(),
      _ => const Center(
        child: Text(
          'إعداد المطعم غير مستخدم.',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    },
  );

  Widget _generalTab() => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        width: 365,
        child: Column(
          children: [
            Expanded(
              child: _managePanel(
                title: 'المخازن / الفروع',
                rows: _warehouses,
                selectedKey: _selectedWarehouse?.toString(),
                keyOf: (row) => '${row['id']}',
                labelOf: (row) => '${row['name'] ?? ''}',
                activeOf: (row) =>
                    ((row['is_active'] as num?)?.toInt() ?? 1) == 1,
                select: (row) => setState(
                  () => _selectedWarehouse = (row['id'] as num).toInt(),
                ),
                toggle: (row, active) => _run(
                  () => _repo.saveWarehouse(
                    id: (row['id'] as num).toInt(),
                    name: '${row['name'] ?? ''}',
                    location: '${row['location'] ?? ''}',
                    description: '${row['description'] ?? ''}',
                    active: active,
                  ),
                ),
                add: _addWarehouse,
                edit: _editWarehouse,
                delete: _deleteWarehouse,
                moveUp: () => _moveWarehouse(-1),
                moveDown: () => _moveWarehouse(1),
              ),
            ),
            const SizedBox(height: 7),
            Expanded(child: _otherListsPanel()),
            const SizedBox(height: 7),
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: 33,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _manageRoles,
                        icon: const Icon(Icons.admin_panel_settings, size: 16),
                        label: const Text('مجموعات الصلاحيات'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          textStyle: const TextStyle(fontSize: 10.5),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: _usersPanel()),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 18),
      Expanded(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle('المشروع'),
              _label('اسم المشروع'),
              _input('project_name'),
              const SizedBox(height: 5),
              _label(
                'بيانات الاتصال (مثل العنوان والتليفون، تظهر في طباعة الفواتير)',
              ),
              const SizedBox(height: 3),
              _input('contact'),
              const SizedBox(height: 5),
              _input('phone'),
              const SizedBox(height: 5),
              _input('address'),
              const SizedBox(height: 7),
              Align(
                alignment: Alignment.centerLeft,
                child: _grayButton(
                  'حفظ بيانات المشروع',
                  Icons.save_outlined,
                  () => _saveValues({
                    'settings.project_name': _fields['project_name']!.text
                        .trim(),
                    'settings.contact': _fields['contact']!.text.trim(),
                    'settings.phone': _fields['phone']!.text.trim(),
                    'settings.address': _fields['address']!.text.trim(),
                  }),
                ),
              ),
              const SizedBox(height: 9),
              _sectionTitle('قوائم أسعار البيع'),
              const Text(
                'بدلاً من سعر البيع، يمكنك إضافة سعر التجزئة وسعر الجملة، أو ما يناسب عملكم.',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  for (var i = 1; i <= 4; i++) ...[
                    if (i > 1) const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'سعر البيع ${_arabicOrdinal(i)}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: _settingsInk,
                            ),
                          ),
                          const SizedBox(height: 3),
                          _input('price_$i'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Checkbox(
                    value:
                        _repo.read('settings.customer_last_price', '0') == '1',
                    onChanged: (value) => _saveValues({
                      'settings.customer_last_price': value == true ? '1' : '0',
                    }, message: 'تم حفظ تفضيل سعر العميل.'),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const Expanded(
                    child: Text(
                      'استخدم سعر بيع العميل الأخير، حتى لو اختلف عن السعر الحالي للصنف حتى',
                      style: TextStyle(fontSize: 10.5),
                    ),
                  ),
                  SizedBox(
                    width: 55,
                    child: _input('last_price_months', numeric: true),
                  ),
                  const Text('شهر', style: TextStyle(fontSize: 10.5)),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: _grayButton(
                  'حفظ إعدادات الأسعار',
                  Icons.save_outlined,
                  () => _saveValues({
                    for (var i = 1; i <= 4; i++)
                      'settings.price_$i': _fields['price_$i']!.text.trim(),
                    'settings.customer_last_price_months':
                        _fields['last_price_months']!.text.trim(),
                  }),
                ),
              ),
              const SizedBox(height: 8),
              _sectionTitle('الدولة / العملة'),
              const SizedBox(height: 3),
              Row(
                children: [
                  _grayButton(
                    '... المزيد',
                    Icons.more_horiz,
                    _openCurrencyManager,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _currencyDisplay('EGP', 'العملة')),
                  const SizedBox(width: 7),
                  Expanded(child: _currencyDisplay('EG', 'الدولة')),
                  const SizedBox(width: 8),
                  _grayButton('...', Icons.more_horiz, _openCurrencyManager),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  );

  String _arabicOrdinal(int value) => switch (value) {
    1 => 'الأول',
    2 => 'الثاني',
    3 => 'الثالث',
    _ => 'الرابع',
  };

  Widget _otherListsPanel() {
    final rows = <Map<String, dynamic>>[
      for (final row in _paymentMethods) {...row, '_kind': 'payment'},
      for (final row in _treasuries) {...row, '_kind': 'treasury'},
    ];
    return _managePanel(
      title: 'المخازن / طرق السداد',
      rows: rows,
      selectedKey: _selectedOther,
      keyOf: (row) => '${row['_kind']}:${row['id']}',
      labelOf: (row) => '${row['name'] ?? ''}',
      activeOf: (row) => ((row['is_active'] as num?)?.toInt() ?? 1) == 1,
      select: (row) =>
          setState(() => _selectedOther = '${row['_kind']}:${row['id']}'),
      toggle: (row, active) => _toggleOther(row, active),
      add: _addOther,
      edit: _editOther,
      delete: _deleteOther,
      moveUp: () => _moveOther(-1),
      moveDown: () => _moveOther(1),
    );
  }

  Widget _usersPanel() => _managePanel(
    title: 'مستخدمو البرنامج',
    rows: [
      for (final user in _users)
        {
          'id': user.id,
          'username': user.username,
          'name': user.displayName,
          'is_admin': user.isAdmin ? 1 : 0,
          'is_active': user.isActive ? 1 : 0,
          'user': user,
        },
    ],
    selectedKey: _selectedUser?.toString(),
    keyOf: (row) => '${row['id']}',
    labelOf: (row) => '${row['name'] ?? ''}',
    activeOf: (row) => ((row['is_active'] as num?)?.toInt() ?? 1) == 1,
    select: (row) => setState(() => _selectedUser = (row['id'] as num).toInt()),
    toggle: (row, active) => _run(() async {
      final user = row['user'] as SettingsUser;
      await _repo.saveUser(
        id: user.id,
        username: user.username,
        displayName: user.displayName,
        isAdmin: user.isAdmin,
        isActive: active,
        permissions: user.permissions,
      );
      await AuthSession.instance.refreshCurrentUser();
    }),
    add: _addUser,
    edit: _editUser,
    delete: _deleteUser,
    moveUp: () => _moveUser(-1),
    moveDown: () => _moveUser(1),
  );

  Future<void> _manageRoles() async {
    var roles = _repo.roles();
    int? selectedId;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            final selected = roles
                .where((role) => role.id == selectedId)
                .firstOrNull;
            return AlertDialog(
              title: const Text('مجموعات الصلاحيات'),
              content: SizedBox(
                width: 690,
                height: 470,
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 250,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _grayButton(
                                        'مجموعة جديدة',
                                        Icons.add,
                                        () async {
                                          final draft =
                                              await showSettingsRoleDialog(
                                                dialogContext,
                                              );
                                          if (draft == null) return;
                                          try {
                                            await _repo.saveRole(
                                              name: draft.name,
                                              description: draft.description,
                                              permissions: draft.permissions,
                                            );
                                            if (!dialogContext.mounted) return;
                                            setDialogState(() {
                                              roles = _repo.roles();
                                              selectedId = roles.lastOrNull?.id;
                                              error = null;
                                            });
                                            _reloadLists();
                                          } catch (exception) {
                                            if (dialogContext.mounted) {
                                              setDialogState(
                                                () => error = exception
                                                    .toString(),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: roles.length,
                                    itemBuilder: (context, index) {
                                      final role = roles[index];
                                      final selected = role.id == selectedId;
                                      return ListTile(
                                        dense: true,
                                        selected: selected,
                                        selectedTileColor: const Color(
                                          0xFFE5F2FF,
                                        ),
                                        title: Text(role.name),
                                        subtitle: Text(
                                          '${role.userCount} مستخدم · ${role.permissions.length} شاشة',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        onTap: () => setDialogState(
                                          () => selectedId = role.id,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const VerticalDivider(width: 22),
                          Expanded(
                            child: selected == null
                                ? const Center(
                                    child: Text(
                                      'اختار مجموعة أو اعمل مجموعة جديدة.',
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        selected.name,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (selected.description.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(selected.description),
                                        ),
                                      const SizedBox(height: 12),
                                      const Text('الشاشات المسموح بها:'),
                                      const SizedBox(height: 5),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          child: Wrap(
                                            spacing: 5,
                                            runSpacing: 5,
                                            children: [
                                              for (final group
                                                  in appPermissionGroups)
                                                for (final permission
                                                    in group.permissions)
                                                  if (selected.permissions
                                                      .contains(
                                                        permission.code,
                                                      ))
                                                    Chip(
                                                      label: Text(
                                                        permission.label,
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                    ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 5),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (selected != null)
                  TextButton.icon(
                    onPressed: () async {
                      final draft = await showSettingsRoleDialog(
                        dialogContext,
                        role: selected,
                      );
                      if (draft == null) return;
                      try {
                        await _repo.saveRole(
                          id: selected.id,
                          name: draft.name,
                          description: draft.description,
                          permissions: draft.permissions,
                        );
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          roles = _repo.roles();
                          error = null;
                        });
                        _reloadLists();
                      } catch (exception) {
                        if (dialogContext.mounted) {
                          setDialogState(() => error = exception.toString());
                        }
                      }
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('تعديل'),
                  ),
                if (selected != null)
                  TextButton.icon(
                    onPressed: () async {
                      final ok = await showSettingsConfirmDialog(
                        dialogContext,
                        title: 'حذف مجموعة الصلاحيات',
                        message: 'المستخدمين اللي عليهم المجموعة هيفقدوا صلاحياتها. تقدر تعيّنهم لمجموعة تانية بعد الحذف.',
                      );
                      if (ok != true) return;
                      await _repo.deleteRole(selected.id);
                      if (!dialogContext.mounted) return;
                      setDialogState(() {
                        roles = _repo.roles();
                        selectedId = null;
                        error = null;
                      });
                      _reloadLists();
                    },
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('حذف'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('إغلاق'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _managePanel({
    required String title,
    required List<Map<String, dynamic>> rows,
    required String? selectedKey,
    required String Function(Map<String, dynamic>) keyOf,
    required String Function(Map<String, dynamic>) labelOf,
    required bool Function(Map<String, dynamic>) activeOf,
    required ValueChanged<Map<String, dynamic>> select,
    required Future<void> Function(Map<String, dynamic>, bool) toggle,
    required VoidCallback add,
    required VoidCallback edit,
    required VoidCallback delete,
    required VoidCallback moveUp,
    required VoidCallback moveDown,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle(title),
      const SizedBox(height: 3),
      Expanded(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF999999)),
                  color: Colors.white,
                ),
                child: rows.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد بيانات',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      )
                    : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          final selected = keyOf(row) == selectedKey;
                          final active = activeOf(row);
                          return InkWell(
                            onTap: () => select(row),
                            child: Container(
                              height: 28,
                              color: selected
                                  ? _settingsGreen
                                  : (active
                                        ? Colors.white
                                        : const Color(0xFFF1F1F1)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      labelOf(row),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: _settingsInk,
                                        decoration: active
                                            ? null
                                            : TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 22,
                                    child: Checkbox(
                                      value: active,
                                      onChanged: (value) =>
                                          toggle(row, value == true),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
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
            const SizedBox(width: 7),
            SizedBox(
              width: 74,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _listAction(
                            'جديد',
                            Icons.add,
                            add,
                            color: _settingsBlue,
                          ),
                          _listAction('تعديل', Icons.edit_outlined, edit),
                          _listAction(
                            'حذف',
                            Icons.remove,
                            delete,
                            color: const Color(0xFFFF614F),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _listAction(
                          '',
                          Icons.keyboard_arrow_down,
                          moveDown,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _listAction('', Icons.keyboard_arrow_up, moveUp),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _listAction(
    String label,
    IconData icon,
    VoidCallback action, {
    Color? color,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: InkWell(
      onTap: _saving ? null : action,
      child: Container(
        height: label.isEmpty ? 28 : 31,
        color: _settingsGray,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (label.isNotEmpty)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _settingsInk, fontSize: 10),
                  ),
                ),
              ),
            Icon(
              icon,
              size: label.isEmpty ? 21 : 18,
              color: color ?? Colors.black,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      title,
      textAlign: TextAlign.right,
      style: const TextStyle(color: _settingsBlue, fontSize: 17, height: 1.25),
    ),
  );

  Widget _label(String value) => Text(
    value,
    textAlign: TextAlign.right,
    style: const TextStyle(color: _settingsInk, fontSize: 11),
  );

  Widget _input(String key, {bool numeric = false}) => SizedBox(
    height: 24,
    child: TextField(
      controller: _fields[key],
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      textAlign: TextAlign.right,
      style: const TextStyle(fontSize: 11.5, color: Colors.black),
      decoration: const InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Color(0xFF999999)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Color(0xFF999999)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Color(0xFF174FAA)),
        ),
      ),
    ),
  );

  Widget _grayButton(String label, IconData icon, VoidCallback onPressed) =>
      SizedBox(
        height: 32,
        child: TextButton.icon(
          onPressed: _saving ? null : onPressed,
          icon: Icon(
            icon,
            size: 17,
            color: icon == Icons.add ? _settingsBlue : Colors.black,
          ),
          label: Text(
            label,
            style: const TextStyle(color: _settingsInk, fontSize: 11),
          ),
          style: TextButton.styleFrom(
            backgroundColor: _settingsGray,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      );

  Widget _currencyDisplay(String fallback, String label) {
    final primary = _currencies
        .where((row) => ((row['is_primary'] as num?)?.toInt() ?? 0) == 1)
        .firstOrNull;
    final value = primary == null
        ? fallback
        : '${primary[label == 'العملة' ? 'code' : 'country_code'] ?? fallback}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5)),
        const SizedBox(height: 3),
        Container(
          height: 24,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFF999999)),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 11, color: _settingsInk),
          ),
        ),
      ],
    );
  }

  Future<void> _addWarehouse() async {
    final values = await showSettingsEntryDialog(
      context,
      title: 'مخزن جديد',
      fields: const [
        SettingsFieldSpec('name', 'اسم المخزن'),
        SettingsFieldSpec('location', 'الموقع'),
        SettingsFieldSpec('description', 'ملاحظات'),
      ],
    );
    if (values == null) return;
    await _run(
      () => _repo.saveWarehouse(
        name: values['name'] ?? '',
        location: values['location'] ?? '',
        description: values['description'] ?? '',
        active: true,
      ),
      message: 'تمت إضافة المخزن.',
    );
  }

  Future<void> _editWarehouse() async {
    final row = _warehouses
        .where((r) => r['id'] == _selectedWarehouse)
        .firstOrNull;
    if (row == null) return _toast('حدد مخزناً أولاً.');
    final values = await showSettingsEntryDialog(
      context,
      title: 'تعديل المخزن',
      fields: const [
        SettingsFieldSpec('name', 'اسم المخزن'),
        SettingsFieldSpec('location', 'الموقع'),
        SettingsFieldSpec('description', 'ملاحظات'),
      ],
      initial: {
        'name': '${row['name'] ?? ''}',
        'location': '${row['location'] ?? ''}',
        'description': '${row['description'] ?? ''}',
      },
    );
    if (values == null) return;
    await _run(
      () => _repo.saveWarehouse(
        id: _selectedWarehouse,
        name: values['name'] ?? '',
        location: values['location'] ?? '',
        description: values['description'] ?? '',
        active: ((row['is_active'] as num?)?.toInt() ?? 1) == 1,
      ),
      message: 'تم تعديل بيانات المخزن.',
    );
  }

  Future<void> _deleteWarehouse() async {
    final id = _selectedWarehouse;
    if (id == null) return _toast('حدد مخزناً أولاً.');
    final ok = await showSettingsConfirmDialog(
      context,
      title: 'حذف المخزن',
      message: 'سيتم تعطيل المخزن إذا كان مرتبطاً بحركات سابقة للحفاظ على البيانات. متابعة؟',
    );
    if (ok != true) return;
    await _run(
      () => _repo.deleteWarehouse(id),
      message: 'تم حذف أو تعطيل المخزن بأمان.',
    );
  }

  Future<void> _moveWarehouse(int direction) async {
    final id = _selectedWarehouse;
    if (id == null) return;
    await _run(() => _repo.moveWarehouse(id, direction));
  }

  Future<void> _addOther() async {
    final kind = await showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SimpleDialog(
          title: const Text('إضافة إعداد'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'treasury'),
              child: const Text('خزينة'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'payment'),
              child: const Text('طريقة سداد'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (kind == 'treasury') {
      final values = await showSettingsEntryDialog(
        context,
        title: 'خزينة جديدة',
        fields: const [
          SettingsFieldSpec('name', 'اسم الخزينة'),
          SettingsFieldSpec('balance', 'الرصيد الافتتاحي', numeric: true),
          SettingsFieldSpec('description', 'ملاحظات'),
        ],
      );
      if (!mounted) return;
      if (values == null) return;
      await _run(
        () => _repo.saveTreasury(
          name: values['name'] ?? '',
          openingBalance: int.tryParse(values['balance'] ?? '') ?? 0,
          description: values['description'] ?? '',
          active: true,
        ),
        message: 'تمت إضافة الخزينة.',
      );
    } else if (kind == 'payment') {
      final values = await showSettingsEntryDialog(
        context,
        title: 'طريقة سداد جديدة',
        fields: const [
          SettingsFieldSpec('code', 'الكود (مثال: cash)'),
          SettingsFieldSpec('name', 'اسم طريقة السداد'),
          SettingsFieldSpec('kind', 'النوع (cash / card / bank / credit)'),
        ],
      );
      if (!mounted) return;
      if (values == null) return;
      await _run(
        () => _repo.savePaymentMethod(
          code: values['code'] ?? '',
          name: values['name'] ?? '',
          kind: values['kind'] ?? 'other',
          active: true,
        ),
        message: 'تمت إضافة طريقة السداد.',
      );
    }
  }

  Map<String, dynamic>? _selectedOtherRow() {
    if (_selectedOther == null) return null;
    for (final row in _paymentMethods) {
      if (_selectedOther == 'payment:${row['id']}') {
        return {...row, '_kind': 'payment'};
      }
    }
    for (final row in _treasuries) {
      if (_selectedOther == 'treasury:${row['id']}') {
        return {...row, '_kind': 'treasury'};
      }
    }
    return null;
  }

  Future<void> _editOther() async {
    final row = _selectedOtherRow();
    if (row == null) return _toast('حدد خزينة أو طريقة سداد أولاً.');
    if (row['_kind'] == 'treasury') {
      final values = await showSettingsEntryDialog(
        context,
        title: 'تعديل الخزينة',
        fields: const [
          SettingsFieldSpec('name', 'اسم الخزينة'),
          SettingsFieldSpec('balance', 'الرصيد الافتتاحي', numeric: true),
          SettingsFieldSpec('description', 'ملاحظات'),
        ],
        initial: {
          'name': '${row['name'] ?? ''}',
          'balance': '${row['opening_balance'] ?? 0}',
          'description': '${row['description'] ?? ''}',
        },
      );
      if (values == null) return;
      await _run(
        () => _repo.saveTreasury(
          id: (row['id'] as num).toInt(),
          name: values['name'] ?? '',
          openingBalance: int.tryParse(values['balance'] ?? '') ?? 0,
          description: values['description'] ?? '',
          active: ((row['is_active'] as num?)?.toInt() ?? 1) == 1,
        ),
        message: 'تم تعديل الخزينة.',
      );
    } else {
      final values = await showSettingsEntryDialog(
        context,
        title: 'تعديل طريقة السداد',
        fields: const [
          SettingsFieldSpec('code', 'الكود'),
          SettingsFieldSpec('name', 'الاسم'),
          SettingsFieldSpec('kind', 'النوع'),
        ],
        initial: {
          'code': '${row['code'] ?? ''}',
          'name': '${row['name'] ?? ''}',
          'kind': '${row['kind'] ?? 'other'}',
        },
      );
      if (values == null) return;
      await _run(
        () => _repo.savePaymentMethod(
          id: (row['id'] as num).toInt(),
          code: values['code'] ?? '',
          name: values['name'] ?? '',
          kind: values['kind'] ?? 'other',
          active: ((row['is_active'] as num?)?.toInt() ?? 1) == 1,
        ),
        message: 'تم تعديل طريقة السداد.',
      );
    }
  }

  Future<void> _toggleOther(Map<String, dynamic> row, bool active) async {
    if (row['_kind'] == 'treasury') {
      await _run(
        () => _repo.saveTreasury(
          id: (row['id'] as num).toInt(),
          name: '${row['name']}',
          openingBalance: (row['opening_balance'] as num?)?.toInt() ?? 0,
          description: '${row['description'] ?? ''}',
          active: active,
        ),
      );
    } else {
      await _run(
        () => _repo.savePaymentMethod(
          id: (row['id'] as num).toInt(),
          code: '${row['code']}',
          name: '${row['name']}',
          kind: '${row['kind'] ?? 'other'}',
          active: active,
        ),
      );
    }
  }

  Future<void> _deleteOther() async {
    final row = _selectedOtherRow();
    if (row == null) return _toast('حدد خزينة أو طريقة سداد أولاً.');
    final ok = await showSettingsConfirmDialog(
      context,
      title: 'حذف الإعداد',
      message: 'إذا كان الإعداد مستخدماً في مستندات سابقة فسيتم تعطيله مع الاحتفاظ بالسجلات. متابعة؟',
    );
    if (ok != true) return;
    if (row['_kind'] == 'treasury') {
      await _run(
        () => _repo.deleteTreasury((row['id'] as num).toInt()),
        message: 'تم حذف أو تعطيل الخزينة بأمان.',
      );
    } else {
      await _run(
        () => _repo.deletePaymentMethod((row['id'] as num).toInt()),
        message: 'تم حذف أو تعطيل طريقة السداد بأمان.',
      );
    }
  }

  Future<void> _moveOther(int direction) async {
    final row = _selectedOtherRow();
    if (row == null) return;
    final id = (row['id'] as num).toInt();
    if (row['_kind'] == 'payment') {
      await _run(() => _repo.movePaymentMethod(id, direction));
    } else {
      await _run(() => _repo.moveTreasury(id, direction));
    }
  }

  Future<void> _addUser() async {
    final draft = await showSettingsUserDialog(context);
    if (draft == null) return;
    await _run(() async {
      await _repo.saveUser(
        username: draft.username,
        displayName: draft.displayName,
        password: draft.password,
        isAdmin: draft.isAdmin,
        isActive: draft.isActive,
        permissions: draft.permissions,
        roleIds: draft.roleIds,
      );
    }, message: 'تم إنشاء المستخدم وصلاحياته.');
  }

  Future<void> _editUser() async {
    final user = _users.where((row) => row.id == _selectedUser).firstOrNull;
    if (user == null) return _toast('حدد مستخدماً أولاً.');
    final draft = await showSettingsUserDialog(context, user: user);
    if (draft == null) return;
    await _run(() async {
      await _repo.saveUser(
        id: user.id,
        username: draft.username,
        displayName: draft.displayName,
        password: draft.password.isEmpty ? null : draft.password,
        isAdmin: draft.isAdmin,
        isActive: draft.isActive,
        permissions: draft.permissions,
        roleIds: draft.roleIds,
      );
      await AuthSession.instance.refreshCurrentUser();
    }, message: 'تم تحديث بيانات المستخدم وصلاحياته.');
  }

  Future<void> _deleteUser() async {
    final id = _selectedUser;
    if (id == null) return _toast('حدد مستخدماً أولاً.');
    final ok = await showSettingsConfirmDialog(
      context,
      title: 'تعطيل المستخدم',
      message: 'سيتم منع المستخدم من الدخول مع الاحتفاظ بسجلاته. متابعة؟',
    );
    if (ok != true) return;
    await _run(() async {
      await _repo.deleteUser(id);
      await AuthSession.instance.refreshCurrentUser();
    }, message: 'تم تعطيل المستخدم.');
  }

  Future<void> _moveUser(int direction) async {
    if (_selectedUser == null) return;
    await _run(() => _repo.moveUser(_selectedUser!, direction));
  }

  Widget _additionalFieldsTab() => ListView(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    children: [
      _fieldScopeSection(
        'product',
        'حقول إضافية للصنف',
        'بيانات إضافية تظهر في نموذج الصنف.',
      ),
      _fieldScopeSection(
        'account',
        'حقول إضافية للحساب',
        'بيانات إضافية تظهر في نموذج الحساب.',
      ),
      _fieldScopeSection(
        'document',
        'حقول إضافية للمستند',
        'حقول تظهر في مستندات البيع والشراء والقبض والصرف والجرد والتحويلات.',
      ),
      _fieldScopeSection(
        'line',
        'حقول إضافية لكل صنف بالفاتورة',
        'بيانات مستقلة لكل سطر صنف داخل المستند.',
      ),
      _fieldScopeSection(
        'sale_extra',
        'إضافات ثابتة على فاتورة البيع',
        'إضافات اختيارية تضاف إلى إجمالي مستند البيع.',
      ),
      _fieldScopeSection(
        'purchase_extra',
        'إضافات ثابتة على فاتورة الشراء',
        'إضافات اختيارية تضاف إلى إجمالي مستند الشراء.',
      ),
    ],
  );

  Widget _fieldScopeSection(String scope, String title, String description) {
    final fields = _repo
        .fieldDefinitions(scope)
        .where((row) => ((row['is_active'] as num?)?.toInt() ?? 1) == 1)
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(title),
          Text(
            description,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 10.5, color: Colors.grey),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              for (final field in fields) ...[
                Expanded(
                  child: Container(
                    height: 29,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF999999)),
                    ),
                    child: InkWell(
                      onTap: () => _editField(scope, field),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${field['name']}',
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _deleteField(field),
                            icon: const Icon(Icons.close, size: 14),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 24,
                              height: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              SizedBox(
                width: 120,
                child: _grayButton(
                  'إضافة حقل',
                  Icons.add,
                  () => _addField(scope),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addField(String scope) async {
    final values = await showSettingsEntryDialog(
      context,
      title: 'إضافة حقل',
      fields: const [SettingsFieldSpec('name', 'اسم الحقل')],
    );
    if (values == null) return;
    await _run(
      () => _repo.saveField(name: values['name'] ?? '', scope: scope),
      message: 'تمت إضافة الحقل.',
    );
  }

  Future<void> _editField(String scope, Map<String, dynamic> field) async {
    final values = await showSettingsEntryDialog(
      context,
      title: 'تعديل الحقل',
      fields: const [SettingsFieldSpec('name', 'اسم الحقل')],
      initial: {'name': '${field['name'] ?? ''}'},
    );
    if (values == null) return;
    await _run(
      () => _repo.saveField(
        id: (field['id'] as num).toInt(),
        name: values['name'] ?? '',
        scope: scope,
      ),
      message: 'تم تعديل الحقل.',
    );
  }

  Future<void> _deleteField(Map<String, dynamic> field) async {
    final ok = await showSettingsConfirmDialog(
      context,
      title: 'تعطيل الحقل',
      message: 'ستظل القيم القديمة محفوظة، ولن يظهر الحقل في المستندات الجديدة. متابعة؟',
    );
    if (ok != true) return;
    await _run(
      () => _repo.deleteField((field['id'] as num).toInt()),
      message: 'تم تعطيل الحقل.',
    );
  }

  Widget _taxTab() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('الضرائب'),
        Row(
          children: [
            Expanded(child: _fieldWithLabel('الرقم الضريبي', 'tax_number')),
            const SizedBox(width: 8),
            Expanded(
              child: _fieldWithLabel(
                'رقم التسجيل التجاري',
                'commercial_register',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 1; i <= 2; i++) ...[
          _taxRateRow(i),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        Material(
          color: Colors.white,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _repo.read('settings.e_invoice_enabled', '0') == '1',
            onChanged: (value) => _saveValues({
              'settings.e_invoice_enabled': value == true ? '1' : '0',
            }, message: 'تم حفظ حالة الفاتورة الإلكترونية.'),
            title: const Text(
              'تفعيل خصائص الفاتورة الإلكترونية',
              style: TextStyle(fontSize: 12, color: Color(0xFFEA4335)),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _grayButton(
            'إعداد الفاتورة الإلكترونية',
            Icons.settings_outlined,
            _editEInvoice,
          ),
        ),
        const SizedBox(height: 80),
        Container(
          padding: const EdgeInsets.all(10),
          color: const Color(0xFFFF7E70),
          child: const Text(
            'أدخل بيانات الرقم الضريبي والتسجيل التجاري بدقة. إعدادات الفاتورة الإلكترونية تحفظ بيانات المنشأة محلياً ولا ترسلها إلى جهة ضريبية من هذا البرنامج.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.black),
          ),
        ),
      ],
    ),
  );

  Widget _taxRateRow(int index) {
    final keyName = 'tax${index}_name';
    final keyPercent = 'tax${index}_percent';
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD5D5D5)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            color: _settingsGreen,
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _fieldWithLabel('اسم الضريبة', keyName)),
          const SizedBox(width: 8),
          SizedBox(
            width: 130,
            child: _fieldWithLabel('نسبة الضريبة %', keyPercent, numeric: true),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(
                height: 27,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'تُضاف يدويًا في فاتورة البيع',
                    style: TextStyle(fontSize: 11.5, color: _settingsInk),
                  ),
                ),
              ),
              _autoTaxCheck(
                index,
                'purchase',
                'أضف الضريبة تلقائياً لفاتورة الشراء',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _autoTaxCheck(int index, String operation, String label) => SizedBox(
    height: 27,
    child: Row(
      children: [
        Checkbox(
          value: _repo.read('settings.tax_${index}_$operation', '0') == '1',
          onChanged: (value) => _saveValues({
            'settings.tax_${index}_$operation': value == true ? '1' : '0',
          }, message: 'تم حفظ إعداد الضريبة.'),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        Text(label, style: const TextStyle(fontSize: 10.5)),
      ],
    ),
  );

  Widget _fieldWithLabel(String label, String key, {bool numeric = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 3),
          _input(key, numeric: numeric),
        ],
      );

  Future<void> _editEInvoice() async {
    final fields = const [
      SettingsFieldSpec('issuer', 'اسم جهة الإصدار'),
      SettingsFieldSpec('activity', 'النشاط'),
      SettingsFieldSpec('branch', 'رقم الفرع'),
      SettingsFieldSpec('device', 'معرف الجهاز'),
    ];
    final values = await showSettingsEntryDialog(
      context,
      title: 'إعداد الفاتورة الإلكترونية',
      fields: fields,
      initial: {
        for (final field in fields)
          field.key: _repo.read('settings.e_invoice_${field.key}'),
      },
      hint: 'تُحفظ هذه البيانات محلياً لتجهيز بيانات الفاتورة. لا يوجد اتصال خارجي مهيأ في التطبيق الحالي.',
    );
    if (values == null) return;
    await _saveValues({
      for (final entry in values.entries)
        'settings.e_invoice_${entry.key}': entry.value,
    }, message: 'تم حفظ بيانات الفاتورة الإلكترونية.');
  }

  Widget _passwordTab() => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('كلمات السر'),
        const Text(
          'كلمة سر حماية البيانات',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 11),
        ),
        const SizedBox(height: 3),
        const Text(
          'تُستخدم لتشفير ملفات النسخ الاحتياطية. لا يمكن استرجاع نسخة مشفّرة بدونها.',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        _PasswordSettingField(
          label: 'كلمة مرور النسخة الاحتياطية الجديدة',
          onSave: (password) => _setSecret('backup', password),
          configured: _repo.read('settings.backup_hash').isNotEmpty,
        ),
        const SizedBox(height: 16),
        const Text(
          'كلمة سر المستخدم المسؤول عند حذف صنف من فاتورة',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 11),
        ),
        const SizedBox(height: 3),
        const Text(
          'عند ضبطها سيُطلب إدخالها قبل حذف سطر صنف من فاتورة بيع أو شراء.',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        _PasswordSettingField(
          label: 'كلمة مرور حذف السطر الجديدة',
          onSave: (password) => _setSecret('line_delete', password),
          configured: _repo.read('settings.line_delete_hash').isNotEmpty,
          allowClear: true,
        ),
      ],
    ),
  );

  Future<void> _setSecret(String key, String password) async {
    if (password.isEmpty) {
      if (key != 'line_delete') return _toast('اكتب كلمة المرور أولاً.');
      await _saveValues({
        'settings.line_delete_salt': '',
        'settings.line_delete_hash': '',
      }, message: 'تمت إزالة كلمة مرور حذف السطر.');
      return;
    }
    if (password.length < 8) {
      return _toast('كلمة المرور يجب أن تكون 8 أحرف على الأقل.');
    }
    final hash = await PasswordHasher.hash(password);
    await _saveValues({
      'settings.${key}_salt': hash.salt,
      'settings.${key}_hash': hash.hash,
    }, message: 'تم حفظ كلمة المرور المشفرة.');
  }

  Widget _otherTab() => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('خيارات أخرى'),
        Material(
          color: Colors.white,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _repo.read('settings.scale_barcode_enabled', '0') == '1',
            onChanged: (value) => _saveValues({
              'settings.scale_barcode_enabled': value == true ? '1' : '0',
            }, message: 'تم حفظ إعداد الميزان.'),
            title: const Text(
              'تفعيل ميزان باركود',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _fieldWithLabel('بادئة الباركود', 'barcode_prefix'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _fieldWithLabel(
                'عدد أرقام كود الصنف',
                'barcode_code_digits',
                numeric: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _fieldWithLabel(
                'عدد أرقام الوزن',
                'barcode_weight_digits',
                numeric: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _fieldWithLabel(
                'عدد أرقام الإجمالي',
                'barcode_total_digits',
                numeric: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.white,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _repo.read('settings.auto_deliver_sales', '0') == '1',
            onChanged: (value) => _saveValues({
              'settings.auto_deliver_sales': value == true ? '1' : '0',
            }, message: 'تم حفظ خيار تسليم الفواتير.'),
            title: const Text(
              'تسليم فواتير البيع تلقائياً',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ),
        const SizedBox(height: 4),
        _label('مجلد حفظ الصور'),
        const SizedBox(height: 3),
        Row(
          children: [
            _grayButton('تصفح', Icons.folder_open, _browseImageFolder),
            const SizedBox(width: 7),
            Expanded(child: _input('image_folder')),
            const SizedBox(width: 6),
            _grayButton(
              'حفظ',
              Icons.save_outlined,
              () => _saveValues({
                'settings.product_image_folder': _fields['image_folder']!.text
                    .trim(),
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _fieldWithLabel('عدد نسخ طباعة فاتورة البيع', 'copies', numeric: true),
        const SizedBox(height: 12),
        _sectionTitle('تاريخ صلاحية الأصناف'),
        Row(
          children: [
            Expanded(
              child: _fieldWithLabel(
                'الافتراضي بعد يوم من تاريخ الشراء',
                'expiry_after_buy',
                numeric: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _fieldWithLabel(
                'تنبيه قبل انتهاء الصلاحية بعد يوم',
                'expiry_before',
                numeric: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: _grayButton(
            'حفظ الخيارات',
            Icons.save_outlined,
            () => _saveValues({
              'settings.scale_barcode_prefix': _fields['barcode_prefix']!.text
                  .trim(),
              'settings.scale_code_digits': _fields['barcode_code_digits']!.text
                  .trim(),
              'settings.scale_weight_digits': _fields['barcode_weight_digits']!
                  .text
                  .trim(),
              'settings.scale_total_digits': _fields['barcode_total_digits']!
                  .text
                  .trim(),
              'settings.product_image_folder': _fields['image_folder']!.text
                  .trim(),
              'settings.invoice_print_copies': _fields['copies']!.text.trim(),
              'settings.expiry_after_buy_days': _fields['expiry_after_buy']!
                  .text
                  .trim(),
              'settings.expiry_warning_days': _fields['expiry_before']!.text
                  .trim(),
            }),
          ),
        ),
      ],
    ),
  );

  Future<void> _browseImageFolder() async {
    if (!Platform.isWindows) {
      return _toast(
        'تصفح المجلد متاح في نسخة Windows. يمكنك كتابة المسار يدوياً.',
      );
    }
    const script =
        r'''Add-Type -AssemblyName System.Windows.Forms; $d=New-Object System.Windows.Forms.FolderBrowserDialog; if($d.ShowDialog() -eq 'OK'){[Console]::WriteLine($d.SelectedPath)}''';
    try {
      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-STA',
        '-Command',
        script,
      ], runInShell: false);
      final path = '${result.stdout}'.trim();
      if (result.exitCode == 0 && path.isNotEmpty && mounted) {
        setState(() => _fields['image_folder']!.text = path);
      }
    } catch (_) {
      _toast('تعذر فتح نافذة اختيار المجلد. اكتب المسار يدوياً.');
    }
  }

  Future<void> _openCurrencyManager() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _CurrencyManagerDialog(onReload: _reloadLists),
    );
    if (mounted) _reloadLists();
  }
}

class _SettingsTitleBar extends StatelessWidget {
  const _SettingsTitleBar({required this.onClose, this.title = 'إعداد Safwa'});
  final VoidCallback onClose;
  final String title;

  @override
  Widget build(BuildContext context) => Container(
    height: 27,
    color: const Color(0xFFF5F5F5),
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Row(
      children: [
        Text(title, style: TextStyle(color: Color(0xFF333333), fontSize: 10.5)),
        const Spacer(),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 28, height: 26),
          color: const Color(0xFF5A5A5A),
        ),
      ],
    ),
  );
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: ClipPath(
      clipper: _SettingsTabClipper(),
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : const Color(0xFFD7E1EB),
            border: Border.all(
              color: disabled
                  ? const Color(0xFFB7C2CE)
                  : const Color(0xFF7694C3),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: disabled ? Colors.grey : Colors.black,
            ),
          ),
        ),
      ),
    ),
  );
}

class _SettingsTabClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(10, size.height)
    ..lineTo(18, 5)
    ..quadraticBezierTo(19, 0, 27, 0)
    ..lineTo(size.width - 27, 0)
    ..quadraticBezierTo(size.width - 19, 0, size.width - 18, 5)
    ..lineTo(size.width - 10, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _PasswordSettingField extends StatefulWidget {
  const _PasswordSettingField({
    required this.label,
    required this.onSave,
    required this.configured,
    this.allowClear = false,
  });
  final String label;
  final Future<void> Function(String) onSave;
  final bool configured;
  final bool allowClear;

  @override
  State<_PasswordSettingField> createState() => _PasswordSettingFieldState();
}

class _PasswordSettingFieldState extends State<_PasswordSettingField> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.onSave(_controller.text);
    if (mounted) {
      setState(() => _busy = false);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 160,
        child: Text(
          widget.configured ? 'كلمة مرور مضبوطة' : widget.label,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 10.5),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: SizedBox(
          height: 27,
          child: TextField(
            controller: _controller,
            obscureText: true,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.zero),
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            ),
          ),
        ),
      ),
      const SizedBox(width: 7),
      SizedBox(
        height: 27,
        child: ElevatedButton(
          onPressed: _busy ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: ShopColors.yellow,
            foregroundColor: Colors.black,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('حفظ', style: TextStyle(fontSize: 10.5)),
        ),
      ),
      if (widget.allowClear && widget.configured) ...[
        const SizedBox(width: 5),
        TextButton(
          onPressed: () async {
            await widget.onSave('');
          },
          child: const Text('إزالة', style: TextStyle(fontSize: 10)),
        ),
      ],
    ],
  );
}

class _CurrencyManagerDialog extends StatefulWidget {
  const _CurrencyManagerDialog({required this.onReload});
  final VoidCallback onReload;

  @override
  State<_CurrencyManagerDialog> createState() => _CurrencyManagerDialogState();
}

class _CurrencyManagerDialogState extends State<_CurrencyManagerDialog> {
  final _repo = SettingsRepository.instance;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _rows = _repo.currencies());

  Future<void> _edit({Map<String, dynamic>? row}) async {
    final keys = const [
      'code',
      'name',
      'symbol',
      'country',
      'decimals',
      'rate',
    ];
    final labels = const [
      'كود العملة',
      'اسم العملة',
      'الرمز',
      'الدولة',
      'الخانات العشرية',
      'سعر الصرف بالنسبة للعملة الأساسية',
    ];
    final fields = [
      for (var i = 0; i < keys.length; i++)
        SettingsFieldSpec(keys[i], labels[i], numeric: i >= 4),
    ];
    final values = await showSettingsEntryDialog(
      context,
      title: row == null ? 'عملة جديدة' : 'تعديل العملة',
      fields: fields,
      initial: {
        'code': '${row?['code'] ?? ''}',
        'name': '${row?['name'] ?? ''}',
        'symbol': '${row?['symbol'] ?? ''}',
        'country': '${row?['country_code'] ?? ''}',
        'decimals': '${row?['decimal_places'] ?? 2}',
        'rate': '${row?['exchange_rate'] ?? 1}',
      },
    );
    if (values == null) return;
    final isPrimary = ((row?['is_primary'] as num?)?.toInt() ?? 0) == 1;
    try {
      await _repo.saveCurrency(
        id: (row?['id'] as num?)?.toInt(),
        code: values['code'] ?? '',
        name: values['name'] ?? '',
        symbol: values['symbol'] ?? '',
        country: values['country'] ?? '',
        decimalPlaces: int.tryParse(values['decimals'] ?? '') ?? 2,
        exchangeRate: double.tryParse(values['rate'] ?? '') ?? 1,
        primary: isPrimary,
        active: ((row?['is_active'] as num?)?.toInt() ?? 1) == 1,
      );
      _reload();
      widget.onReload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _primary(Map<String, dynamic> row) async {
    try {
      await _repo.setPrimaryCurrency((row['id'] as num).toInt());
      _reload();
      widget.onReload();
      CurrencyUtils.updateSymbol('${row['symbol'] ?? ''}');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: AlertDialog(
      title: const Text('الدولة / العملة'),
      content: SizedBox(
        width: 580,
        height: 360,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _rows.length,
                itemBuilder: (context, index) {
                  final row = _rows[index];
                  final primary =
                      ((row['is_primary'] as num?)?.toInt() ?? 0) == 1;
                  return ListTile(
                    dense: true,
                    selected: primary,
                    leading: Icon(
                      primary
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: primary ? _settingsGreen : Colors.grey,
                    ),
                    title: Text('${row['name']} (${row['code']})'),
                    subtitle: Text(
                      '${row['symbol']}  •  ${row['country_code']}  •  سعر الصرف ${row['exchange_rate']}',
                    ),
                    trailing: Wrap(
                      spacing: 0,
                      children: [
                        IconButton(
                          tooltip: 'تعديل',
                          onPressed: () => _edit(row: row),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                        IconButton(
                          tooltip: primary ? 'عملة أساسية' : 'تعيين أساسية',
                          onPressed: primary ? null : () => _primary(row),
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _primary(row),
                  );
                },
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text('إضافة عملة'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    ),
  );
}
