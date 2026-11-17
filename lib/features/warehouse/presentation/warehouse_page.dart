import 'package:flutter/material.dart';
import 'package:inventory_app/app/theme/app_theme.dart';

class WarehousePage extends StatelessWidget {
  const WarehousePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('إدارة المستودعات'),
          backgroundColor: AppTheme.primaryColor,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'صفحة إدارة المستودعات - قيد الإنشاء',
            style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 18),
          ),
        ),
      ),
    );
  }
}
