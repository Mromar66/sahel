part of 'invoice_archive_page.dart';

/// One grid column. Exactly one of [docValue] / [itemValue] is used by the
/// current view; the sort fields stay null for columns SQL cannot sort.
class _ArchiveColumn {
  const _ArchiveColumn({
    required this.label,
    required this.width,
    this.align = TextAlign.right,
    this.docValue,
    this.itemValue,
    this.docSort,
    this.itemSort,
  });

  final String label;
  final double width;
  final TextAlign align;
  final String Function(ArchiveDocument document)? docValue;
  final String Function(ArchiveItem item)? itemValue;
  final ArchiveSortField? docSort;
  final ArchiveItemSortField? itemSort;
}

String _docDateTime(ArchiveDocument document) {
  if (document.dateText.isEmpty) return '';
  return '${document.dateText}  ${document.timeText}';
}

extension _InvoiceArchiveTable on _InvoiceArchivePageState {
  // ---------------------------------------------------------------------------
  // Results shell.
  // ---------------------------------------------------------------------------
  Widget _buildResults() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 0, 8, 6),
      child: Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 169, child: _buildLeftPanel()),
          const SizedBox(width: 8),
          Expanded(
            child: RepaintBoundary(
              key: _tableKey,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE3E3E3)),
                ),
                child: _buildGridArea(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Left action panel (تعديل / حذف / طباعة / مشاركة).
  // ---------------------------------------------------------------------------
  Widget _buildLeftPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 66,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: _panelAction(
                  'تعديل',
                  Icons.description,
                  const Color(0xFFD9B62E),
                  _editSelected,
                  tooltip: 'تعديل المستند المحدد (F2)',
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _panelAction(
                  'حذف',
                  Icons.close,
                  _kRed,
                  _deleteSelected,
                  tooltip: 'حذف المستند المحدد نهائياً (Delete)',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        _panelPrintRow(
          label: 'طباعة التقرير',
          printTooltip: 'طباعة كل نتائج البحث (F12)',
          shareTooltip: 'مشاركة التقرير (F11)',
          onPrint: _printReport,
          onShare: _shareReport,
        ),
        const SizedBox(height: 5),
        _panelPrintRow(
          label: 'طباعة المستند',
          printTooltip: 'طباعة المستند المحدد',
          shareTooltip: 'مشاركة المستند المحدد',
          onPrint: _printDocument,
          onShare: _shareDocument,
        ),
      ],
    );
  }

  Widget _panelAction(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    required String tooltip,
  }) {
    return HoverBuilder(
      builder: (context, hovered) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: hovered
                  ? const Color(0xFFDEDEDE)
                  : const Color(0xFFE9E9E9),
              border: Border.all(color: const Color(0xFFDDDDDD)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 25, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _kInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _panelPrintRow({
    required String label,
    required String printTooltip,
    required String shareTooltip,
    required VoidCallback onPrint,
    required VoidCallback onShare,
  }) {
    return SizedBox(
      height: 44,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: HoverBuilder(
              builder: (context, hovered) => Tooltip(
                message: printTooltip,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPrint,
                  child: Container(
                    decoration: BoxDecoration(
                      color: hovered ? kHoverYellow : const Color(0xFFE9E9E9),
                      border: Border.all(color: const Color(0xFFDDDDDD)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      textDirection: TextDirection.rtl,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(fontSize: 11, color: _kInk),
                        ),
                        const Icon(
                          Icons.print,
                          size: 18,
                          color: Color(0xFF4A4A4A),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          SizedBox(
            width: 44,
            child: HoverBuilder(
              builder: (context, hovered) => Tooltip(
                message: shareTooltip,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onShare,
                  child: Container(
                    decoration: BoxDecoration(
                      color: hovered ? kHoverYellow : const Color(0xFFE9E9E9),
                      border: Border.all(color: const Color(0xFFDDDDDD)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.share,
                      size: 20,
                      color: Color(0xFF2D70DB),
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

  // ---------------------------------------------------------------------------
  // Grid states.
  // ---------------------------------------------------------------------------
  Widget _buildGridArea() {
    if (_loading) {
      return const _ArchiveStateView(
        message: 'جارٍ تحميل البيانات...',
        loading: true,
      );
    }
    if (_error != null) {
      return _ArchiveStateView(
        message: _error!,
        error: true,
        actionLabel: 'إعادة المحاولة',
        onAction: () => _search(),
      );
    }
    if (!_loaded) {
      return const _ArchiveStateView(
        message: 'حدد ما تبحث عنه أولاً .. ثم اضغط عرض الفواتير',
        large: true,
      );
    }
    final rowCount = _showItems ? _items.length : _documents.length;
    if (rowCount == 0) {
      return _ArchiveStateView(
        message: _showItems
            ? 'لا توجد أصناف مطابقة للفلاتر المحددة.'
            : 'لا توجد مستندات مطابقة للفلاتر المحددة.',
      );
    }
    final columns = _showItems
        ? _itemColumnsFor(_type)
        : _documentColumnsFor(_type);
    final tableWidth = columns.fold<double>(
      0,
      (sum, column) => sum + column.width,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _hScroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _hScroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(tableWidth, constraints.maxWidth),
              height: constraints.maxHeight,
              child: Column(
                children: [
                  _gridHeader(columns),
                  Expanded(
                    child: Scrollbar(
                      controller: _vScroll,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: _vScroll,
                        itemCount: rowCount + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= rowCount) return _loadMoreTile();
                          if (_showItems) {
                            final item = _items[index];
                            final key = _itemKey(item, index);
                            return _gridRow(
                              columns: columns,
                              values: [
                                for (final column in columns)
                                  column.itemValue?.call(item) ?? '',
                              ],
                              selected: _isSelected(key),
                              onTap: () => _tapRow(key),
                              onDoubleTap: () => _openDocument(item.documentId),
                            );
                          }
                          final document = _documents[index];
                          final key = _docKey(document);
                          return _gridRow(
                            columns: columns,
                            values: [
                              for (final column in columns)
                                column.docValue?.call(document) ?? '',
                            ],
                            selected: _isSelected(key),
                            onTap: () => _tapRow(key),
                            onDoubleTap: () => _openDocument(document.id),
                          );
                        },
                      ),
                    ),
                  ),
                  _gridFooter(rowCount),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _tapRow(String key) {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final ctrl =
        pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight);
    final shift =
        pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
    _selectRow(key, ctrl: ctrl, shift: shift);
  }

  Widget _gridHeader(List<_ArchiveColumn> columns) {
    return Container(
      height: 27,
      color: _kHeader,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [for (final column in columns) _headerCell(column)],
      ),
    );
  }

  Widget _headerCell(_ArchiveColumn column) {
    final sortable = _showItems
        ? column.itemSort != null
        : column.docSort != null;
    final active = _showItems
        ? column.itemSort == _itemSort.field
        : column.docSort == _sort.field;
    final ascending = _showItems ? _itemSort.ascending : _sort.ascending;
    final content = Container(
      width: column.width,
      height: 27,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: _alignment(column.align),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        textDirection: TextDirection.rtl,
        children: [
          Flexible(
            child: Text(
              column.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: column.align,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: _kInk,
                height: 1.05,
              ),
            ),
          ),
          if (sortable) ...[
            const SizedBox(width: 2),
            Icon(
              active
                  ? (ascending ? Icons.arrow_drop_up : Icons.arrow_drop_down)
                  : Icons.unfold_more,
              size: active ? 14 : 10,
              color: active ? _kGreen : const Color(0xFF9A9A9A),
            ),
          ],
        ],
      ),
    );
    if (!sortable) return content;
    return Tooltip(
      message:
          'ترتيب حسب ${_InvoiceArchivePageState._headerText(column.label)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_showItems) {
            _setItemSort(column.itemSort!);
          } else {
            _setDocSort(column.docSort!);
          }
        },
        child: content,
      ),
    );
  }

  Widget _gridRow({
    required List<_ArchiveColumn> columns,
    required List<String> values,
    required bool selected,
    required VoidCallback onTap,
    required VoidCallback onDoubleTap,
  }) {
    return HoverBuilder(
      cursor: SystemMouseCursors.basic,
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Container(
          height: 24,
          decoration: BoxDecoration(
            color: selected
                ? ShopColors.rowSelected
                : hovered
                ? ShopColors.rowHover
                : Colors.white,
            border: const Border(bottom: BorderSide(color: _kGridLine)),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              for (var index = 0; index < columns.length; index++)
                Container(
                  width: columns[index].width,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: _alignment(columns[index].align),
                  child: Text(
                    values[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: columns[index].align,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: _kInk,
                      height: 1.1,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadMoreTile() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _loadingMore ? null : () => _search(append: true),
      child: Container(
        height: 30,
        color: const Color(0xFFF7F7F7),
        alignment: Alignment.center,
        child: _loadingMore
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kGreen,
                ),
              )
            : const Text(
                'تحميل المزيد من النتائج...',
                style: TextStyle(fontSize: 10.5, color: Color(0xFF6B6B6B)),
              ),
      ),
    );
  }

  Widget _gridFooter(int shown) {
    final selected = _selection.isEmpty
        ? ''
        : '  •  محدد: ${_selection.length}';
    return Container(
      height: 22,
      color: const Color(0xFFF7F7F7),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.centerRight,
      child: Text(
        'معروض: $shown من $_totalCount  •  '
        'الإجمالي: ${_money(_totals.total)}$selected',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFF5A5A5A),
          height: 1.1,
        ),
      ),
    );
  }

  Alignment _alignment(TextAlign align) => switch (align) {
    TextAlign.center => Alignment.center,
    TextAlign.left => Alignment.centerLeft,
    _ => Alignment.centerRight,
  };

  // ---------------------------------------------------------------------------
  // Columns.
  // ---------------------------------------------------------------------------
  List<_ArchiveColumn> _documentColumnsFor(ArchiveDocType type) {
    final number = _ArchiveColumn(
      label: 'رقم المستند',
      width: 88,
      docValue: (document) => document.number,
      docSort: ArchiveSortField.number,
      itemValue: (item) => item.documentNumber,
      itemSort: ArchiveItemSortField.number,
    );
    final date = _ArchiveColumn(
      label: 'التاريخ',
      width: 116,
      align: TextAlign.center,
      docValue: _docDateTime,
      docSort: ArchiveSortField.date,
      itemValue: (item) => item.dateText,
      itemSort: ArchiveItemSortField.date,
    );
    final account = _ArchiveColumn(
      label: 'الحساب / الجهة',
      width: 138,
      docValue: (document) => document.accountName,
      docSort: ArchiveSortField.account,
      itemValue: (item) => item.accountName,
    );
    final warehouse = _ArchiveColumn(
      label: 'المخزن',
      width: 104,
      docValue: (document) => document.warehouseName,
      itemValue: (item) => item.warehouseName,
    );
    final total = _ArchiveColumn(
      label: type.isVoucher ? 'المبلغ' : 'الإجمالي',
      width: 82,
      align: TextAlign.center,
      docValue: (document) => _money(document.total),
      docSort: ArchiveSortField.total,
      itemValue: (item) => _money(item.lineTotal),
      itemSort: ArchiveItemSortField.total,
    );
    final discount = _ArchiveColumn(
      label: 'الخصم',
      width: 66,
      align: TextAlign.center,
      docValue: (document) => _money(document.discount),
      itemValue: (item) => _money(item.discount),
    );
    final tax = _ArchiveColumn(
      label: 'الضريبة',
      width: 66,
      align: TextAlign.center,
      docValue: (document) => _money(document.tax),
    );
    final paid = _ArchiveColumn(
      label: 'المدفوع',
      width: 78,
      align: TextAlign.center,
      docValue: (document) => _money(document.paid),
      docSort: ArchiveSortField.paid,
    );
    final remaining = _ArchiveColumn(
      label: 'المتبقي',
      width: 78,
      align: TextAlign.center,
      docValue: (document) => _money(document.remaining),
      docSort: ArchiveSortField.remaining,
    );
    final status = _ArchiveColumn(
      label: 'الحالة',
      width: 82,
      align: TextAlign.center,
      docValue: (document) => document.paymentStatusLabel,
      docSort: ArchiveSortField.status,
    );
    final method = _ArchiveColumn(
      label: 'طريقة السداد',
      width: 74,
      align: TextAlign.center,
      docValue: (document) => document.paymentMethodLabel,
    );
    final itemsCount = _ArchiveColumn(
      label: 'الأصناف',
      width: 54,
      align: TextAlign.center,
      docValue: (document) => '${document.itemCount}',
    );
    final applied = _ArchiveColumn(
      label: 'الترحيل',
      width: 58,
      align: TextAlign.center,
      docValue: (document) => document.applied ? 'مُرحّل' : 'غير مُرحّل',
    );
    final original = _ArchiveColumn(
      label: 'المستند الأصلي',
      width: 96,
      docValue: (document) => document.originalNumber,
    );
    final notes = _ArchiveColumn(
      label: 'ملاحظات',
      width: 160,
      docValue: (document) => document.notes,
      itemValue: (item) => item.notes,
    );

    if (type.isVoucher) {
      return [number, date, account, total, method, notes];
    }
    if (type.isStockDocument) {
      return [number, date, warehouse, total, itemsCount, applied, notes];
    }
    if (type.isQuotation) {
      return [
        number,
        date,
        account,
        total,
        discount,
        tax,
        status,
        itemsCount,
        notes,
      ];
    }
    return [
      number,
      date,
      account,
      if (type.isSalesReturn || type.isPurchaseReturn) original,
      total,
      discount,
      tax,
      paid,
      remaining,
      status,
      method,
      itemsCount,
      notes,
    ];
  }

  List<_ArchiveColumn> _itemColumnsFor(ArchiveDocType type) {
    final number = _ArchiveColumn(
      label: 'رقم المستند',
      width: 88,
      itemValue: (item) => item.documentNumber,
      itemSort: ArchiveItemSortField.number,
    );
    final date = _ArchiveColumn(
      label: 'التاريخ',
      width: 102,
      align: TextAlign.center,
      itemValue: (item) => item.dateText,
      itemSort: ArchiveItemSortField.date,
    );
    final account = _ArchiveColumn(
      label: 'الحساب / الجهة',
      width: 130,
      itemValue: (item) => item.accountName,
    );
    final warehouse = _ArchiveColumn(
      label: 'المخزن',
      width: 104,
      itemValue: (item) => item.warehouseName,
    );
    final itemName = _ArchiveColumn(
      label: 'اسم الصنف',
      width: 150,
      itemValue: (item) => item.itemName,
      itemSort: ArchiveItemSortField.item,
    );
    final code = _ArchiveColumn(
      label: 'الكود',
      width: 82,
      itemValue: (item) => item.itemCode,
    );
    final barcode = _ArchiveColumn(
      label: 'الباركود',
      width: 96,
      itemValue: (item) => item.barcode,
    );
    final unit = _ArchiveColumn(
      label: 'الوحدة',
      width: 54,
      align: TextAlign.center,
      itemValue: (item) => item.unitName,
    );
    final qty = _ArchiveColumn(
      label: 'الكمية',
      width: 58,
      align: TextAlign.center,
      itemValue: (item) => '${item.quantity}',
      itemSort: ArchiveItemSortField.quantity,
    );
    final price = _ArchiveColumn(
      label: 'السعر',
      width: 68,
      align: TextAlign.center,
      itemValue: (item) => _money(item.unitPrice),
    );
    final discount = _ArchiveColumn(
      label: 'الخصم',
      width: 64,
      align: TextAlign.center,
      itemValue: (item) => _money(item.discount),
    );
    final total = _ArchiveColumn(
      label: 'الإجمالي',
      width: 80,
      align: TextAlign.center,
      itemValue: (item) => _money(item.lineTotal),
      itemSort: ArchiveItemSortField.total,
    );
    final extra = _ArchiveColumn(
      label: type.isAdjustment
          ? 'الفرق'
          : type.isStockDocument
          ? 'المتاح'
          : 'إضافي',
      width: 64,
      align: TextAlign.center,
      itemValue: (item) => item.extraValue,
    );
    final notes = _ArchiveColumn(
      label: 'ملاحظات',
      width: 150,
      itemValue: (item) => item.notes,
    );
    if (type.isStockDocument) {
      return [
        number,
        date,
        warehouse,
        itemName,
        code,
        barcode,
        unit,
        qty,
        price,
        total,
        extra,
        notes,
      ];
    }
    return [
      number,
      date,
      account,
      itemName,
      code,
      barcode,
      unit,
      qty,
      price,
      discount,
      total,
      notes,
    ];
  }

  // ---------------------------------------------------------------------------
  // One document print table (real header + real lines).
  // ---------------------------------------------------------------------------
  _ArchivePrintData _documentPrintData(ArchiveDocumentDetail detail) {
    final header = detail.header;
    String text(String key) => '${header[key] ?? ''}'.trim();
    int number(String key) => (header[key] as num?)?.toInt() ?? 0;
    final docNumber = text('number');
    final parsed = DateTime.tryParse(text('doc_date'));
    final dateText = parsed == null
        ? text('doc_date')
        : _InvoiceArchivePageState._fmtFilterDate(parsed);
    final timeText = parsed == null
        ? ''
        : _InvoiceArchivePageState._fmtFilterTime(
            _InvoiceArchivePageState._timeValue(parsed.hour, parsed.minute),
          );
    final summary = <String>[
      'رقم: $docNumber',
      if (dateText.isNotEmpty) 'التاريخ: $dateText $timeText',
      if (text('account_name').isNotEmpty) 'الحساب: ${text('account_name')}',
      if (text('warehouse_name').isNotEmpty)
        'المخزن: ${text('warehouse_name')}',
      if (number('total') != 0) 'الإجمالي: ${_money(number('total'))}',
      if (number('discount') != 0) 'الخصم: ${_money(number('discount'))}',
      if (number('tax') != 0) 'الضريبة: ${_money(number('tax'))}',
      if (number('paid') != 0) 'المدفوع: ${_money(number('paid'))}',
      if (number('remaining') != 0) 'المتبقي: ${_money(number('remaining'))}',
      if (text('payment_method').isNotEmpty)
        'طريقة السداد: ${text('payment_method') == 'cash'
            ? 'نقدي'
            : text('payment_method') == 'credit'
            ? 'آجل'
            : text('payment_method')}',
      if (text('status').isNotEmpty) 'الحالة: ${text('status')}',
      if (text('original_number').isNotEmpty)
        'المستند الأصلي: ${text('original_number')}',
      if (text('notes').isNotEmpty) 'ملاحظات: ${text('notes')}',
    ];

    if (detail.items.isEmpty) {
      return _ArchivePrintData(
        headers: const ['البيان', 'القيمة'],
        rows: [
          ['رقم المستند', docNumber],
          ['التاريخ', '$dateText $timeText'.trim()],
          ['الحساب', text('account_name')],
          ['المبلغ', _money(number('total'))],
          [
            'طريقة السداد',
            text('payment_method') == 'cash'
                ? 'نقدي'
                : text('payment_method') == 'check'
                ? 'شيك'
                : text('payment_method'),
          ],
          ['البيان', text('notes')],
        ],
        subtitle: summary.join('  |  '),
        count: 1,
        number: docNumber,
      );
    }

    final stock = detail.type.isStockDocument;
    final qtyKey = switch (detail.type) {
      ArchiveDocType.stocktaking => 'counted_qty',
      ArchiveDocType.adjustment => 'adjusted_qty',
      ArchiveDocType.transfer => 'transfer_qty',
      _ => 'quantity',
    };
    final priceKey = stock ? 'price' : 'unit_price';
    final headers = [
      'الصنف',
      'الكود',
      'الوحدة',
      'الكمية',
      'السعر',
      if (!stock) 'الخصم',
      'الإجمالي',
      if (detail.type.isStocktaking) 'المتاح قبل الجرد',
      if (detail.type.isAdjustment) 'الفرق',
      if (detail.type.isTransfer) 'المتاح',
    ];
    final rows = <List<String>>[];
    for (final item in detail.items) {
      final quantity = (item[qtyKey] as num?)?.toInt() ?? 0;
      final price = (item[priceKey] as num?)?.toInt() ?? 0;
      final lineTotal = (item['total'] as num?)?.toInt() ?? 0;
      rows.add([
        '${item['product_name'] ?? ''}',
        '${item['product_code'] ?? ''}',
        '${item['unit_name'] ?? ''}',
        '$quantity',
        _money(price),
        if (!stock) _money((item['discount'] as num?)?.toInt() ?? 0),
        _money(lineTotal),
        if (detail.type.isStocktaking)
          '${(item['available_qty'] as num?)?.toInt() ?? 0}',
        if (detail.type.isAdjustment)
          '${(item['difference'] as num?)?.toInt() ?? 0}',
        if (detail.type.isTransfer)
          '${(item['available_qty'] as num?)?.toInt() ?? 0}',
      ]);
    }
    return _ArchivePrintData(
      headers: headers,
      rows: rows,
      subtitle: summary.join('  |  '),
      count: rows.length,
      number: docNumber,
    );
  }
}

/// Large Arabic loading / empty / error message shown inside the grid area.
class _ArchiveStateView extends StatelessWidget {
  const _ArchiveStateView({
    required this.message,
    this.loading = false,
    this.error = false,
    this.large = false,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final bool loading;
  final bool error;
  final bool large;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: _kGreen,
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (error) ...[
              const Icon(Icons.error_outline, size: 26, color: _kRed),
              const SizedBox(height: 10),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: large ? 20 : 13,
                color: error
                    ? _kRed
                    : large
                    ? const Color(0xFF555555)
                    : const Color(0xFF777777),
                height: 1.3,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAction,
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  color: _kSoft,
                  alignment: Alignment.center,
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(fontSize: 11.5, color: _kInk),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
