import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/budgeting_repository.dart';
import '../models/budgeting_models.dart';
import 'budget_settings_page.dart';

class BudgetingPage extends StatefulWidget {
  const BudgetingPage({super.key});

  @override
  State<BudgetingPage> createState() => _BudgetingPageState();
}

class _BudgetingPageState extends State<BudgetingPage> {
  final BudgetingRepository _repository = BudgetingRepository.instance;
  late Future<_BudgetViewData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadViewData();
  }

  Future<_BudgetViewData> _loadViewData() async {
    final baseProfile = await _repository.fetchProfile();
    final expenseCategories = await _repository.fetchExpenseCategories();
    final incomeCategories = await _repository.fetchIncomeCategories();
    final transactions = await _repository.fetchTransactions();
    final month = DateTime.now();
    final plans = await _repository.fetchCategoryPlans(budgetMonthKey(month));
    final profile = baseProfile.copyWith(
      expenseCategories: expenseCategories.isEmpty
          ? baseProfile.expenseCategories
          : expenseCategories,
      incomeCategories: incomeCategories.isEmpty
          ? baseProfile.incomeCategories
          : incomeCategories,
    );
    return _BudgetViewData(
      profile: profile,
      transactions: transactions,
      month: DateTime(month.year, month.month),
      plans: plans,
    );
  }

  Future<void> _refresh() async {
    final future = _loadViewData();
    if (!mounted) return;
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _openSettings(_BudgetViewData data) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BudgetSettingsPage(
          initialProfile: data.profile,
          initialMonth: data.month,
        ),
      ),
    );
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _saveTransaction(
    BudgetTransaction tx, {
    required bool isEdit,
  }) async {
    if (isEdit) {
      await _repository.updateTransaction(tx);
    } else {
      await _repository.addTransaction(tx);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEdit ? 'Transaction updated.' : 'Transaction saved.'),
      ),
    );
    await _refresh();
  }

  Future<void> _openEditor(
    BudgetProfile profile, {
    BudgetTransaction? tx,
  }) async {
    final result = await showModalBottomSheet<BudgetTransaction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransactionEditorSheet(profile: profile, initial: tx),
    );
    if (result == null) return;
    await _saveTransaction(result, isEdit: tx != null);
  }

  Future<void> _deleteTransaction(BudgetTransaction tx) async {
    final id = tx.id;
    if (id == null) return;
    await _repository.deleteTransaction(id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Transaction deleted.')));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0E1424)
        : const Color(0xFFF4F7FF);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          surfaceTintColor: Colors.transparent,
          title: const Text('Budgeting'),
          actions: [
            FutureBuilder<_BudgetViewData>(
              future: _future,
              builder: (context, snapshot) {
                final data = snapshot.data;
                return IconButton(
                  onPressed: data == null ? null : () => _openSettings(data),
                  icon: const Icon(Icons.settings_outlined),
                );
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Activity'),
              Tab(text: 'Overview'),
              Tab(text: 'Insights'),
            ],
          ),
        ),
        body: FutureBuilder<_BudgetViewData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            final data = snapshot.requireData;
            return TabBarView(
              children: [
                _ActivityTab(
                  data: data,
                  onEdit: (tx) => _openEditor(data.profile, tx: tx),
                  onDelete: _deleteTransaction,
                ),
                _OverviewTab(data: data),
                _InsightsTab(data: data),
              ],
            );
          },
        ),
        floatingActionButton: FutureBuilder<_BudgetViewData>(
          future: _future,
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data == null) return const SizedBox.shrink();
            return FloatingActionButton.extended(
              onPressed: () => _openEditor(data.profile),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add transaction'),
            );
          },
        ),
      ),
    );
  }
}

class _BudgetViewData {
  const _BudgetViewData({
    required this.profile,
    required this.transactions,
    required this.month,
    required this.plans,
  });

  final BudgetProfile profile;
  final List<BudgetTransaction> transactions;
  final DateTime month;
  final List<BudgetCategoryPlan> plans;
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({
    required this.data,
    required this.onEdit,
    required this.onDelete,
  });

  final _BudgetViewData data;
  final ValueChanged<BudgetTransaction> onEdit;
  final ValueChanged<BudgetTransaction> onDelete;

  @override
  Widget build(BuildContext context) {
    final stats = _BudgetStats.fromData(data);
    final groups = _groupedTransactions(data.transactions);
    if (groups.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _MonthlySummaryStrip(data: data, stats: stats),
          const SizedBox(height: 24),
          const Center(child: Text('No transactions yet.')),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _MonthlySummaryStrip(data: data, stats: stats),
        const SizedBox(height: 16),
        ...groups.map((group) {
          final subtotal = group.items.fold<double>(
            0,
            (sum, tx) => sum + (tx.type.isExpense ? tx.amount : -tx.amount),
          );
          return _Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('dd.MM.yy').format(group.date),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    Text(
                      _money(data.profile.currencyCode, subtotal.abs()),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: subtotal > 0
                            ? Theme.of(context).colorScheme.error
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...group.items.map(
                  (tx) => _TransactionTile(
                    tx: tx,
                    currencyCode: data.profile.currencyCode,
                    onTap: () => onEdit(tx),
                    onDelete: () => onDelete(tx),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.data});

  final _BudgetViewData data;

  @override
  Widget build(BuildContext context) {
    final stats = _BudgetStats.fromData(data);
    final score = _BudgetScore.fromStats(data, stats);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _BudgetScoreCard(data: data, score: score, stats: stats),
        const SizedBox(height: 16),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Current balance',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _money(data.profile.currencyCode, stats.balance),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Budget',
                      value: _money(
                        data.profile.currencyCode,
                        stats.totalBudget,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniStat(
                      label: 'Remaining',
                      value: _money(
                        data.profile.currencyCode,
                        stats.remainingBudget,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Monthly category budgets',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 14),
              if (data.plans.isEmpty)
                const Text('No category budgets set for this month yet.')
              else
                ...data.plans.map((plan) {
                  final spent = stats.expenseByCategory[plan.category] ?? 0;
                  final ratio = plan.amount <= 0
                      ? 0.0
                      : (spent / plan.amount).clamp(0.0, 1.0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                plan.category,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${_money(data.profile.currencyCode, spent)} / ${_money(data.profile.currencyCode, plan.amount)}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 10,
                            value: ratio,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

class _InsightsTab extends StatefulWidget {
  const _InsightsTab({required this.data});

  final _BudgetViewData data;

  @override
  State<_InsightsTab> createState() => _InsightsTabState();
}

class _InsightsTabState extends State<_InsightsTab> {
  int? _selectedDay;
  String? _selectedCategory;
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.data.month;
  }

  @override
  Widget build(BuildContext context) {
    final stats = _BudgetStats.forMonth(
      widget.data.transactions,
      widget.data.plans,
      _selectedMonth,
    );
    final days = _sevenDaySpendForMonth(
      widget.data.transactions,
      _selectedMonth,
    );
    final maxSpend = days.fold<double>(
      0,
      (max, item) => math.max(max, item.amount),
    );
    final pie = _pieEntries(stats.expenseByCategory);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InsightMonthHeader(
                month: _selectedMonth,
                onPrevious: () {
                  setState(() {
                    _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month - 1,
                    );
                    _selectedDay = null;
                    _selectedCategory = null;
                  });
                },
                onNext: () {
                  setState(() {
                    _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month + 1,
                    );
                    _selectedDay = null;
                    _selectedCategory = null;
                  });
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Income',
                      value: _money(
                        widget.data.profile.currencyCode,
                        stats.monthIncome,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniStat(
                      label: 'Expense',
                      value: _money(
                        widget.data.profile.currencyCode,
                        stats.monthExpense,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniStat(
                      label: 'Net',
                      value: _money(
                        widget.data.profile.currencyCode,
                        stats.monthIncome - stats.monthExpense,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '7 day spend pulse',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 6),
              const Text('Tap a bar to inspect a day.'),
              const SizedBox(height: 16),
              SizedBox(
                height: 210,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(days.length, (index) {
                    final item = days[index];
                    final selected = _selectedDay == index;
                    final height = maxSpend == 0
                        ? 12.0
                        : 28 + (item.amount / maxSpend) * 110;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(
                          () => _selectedDay = selected ? null : index,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SizedBox(
                                height: 34,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    selected
                                        ? _money(
                                            widget.data.profile.currencyCode,
                                            item.amount,
                                          )
                                        : '',
                                  ),
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                height: height,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 18,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    DateFormat('dd').format(item.day),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Expense split in ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              if (pie.isEmpty)
                const Text(
                  'Add expense transactions in this month to see the chart.',
                )
              else
                SizedBox(
                  height: 240,
                  child: Row(
                    children: [
                      Expanded(
                        child: CustomPaint(
                          painter: _PieChartPainter(
                            entries: pie,
                            selectedCategory: _selectedCategory,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: pie.map((entry) {
                            final percent = stats.monthExpense == 0
                                ? 0
                                : (entry.amount / stats.monthExpense) * 100;
                            final selected =
                                _selectedCategory == entry.category;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                onTap: () => setState(
                                  () => _selectedCategory = selected
                                      ? null
                                      : entry.category,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? entry.color.withValues(alpha: 0.18)
                                        : entry.color.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: entry.color.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: entry.color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          entry.category,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${percent.toStringAsFixed(0)}%',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
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

class _Card extends StatelessWidget {
  const _Card({required this.child, this.margin});

  final Widget child;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171F35) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.tx,
    required this.currencyCode,
    required this.onTap,
    required this.onDelete,
  });

  final BudgetTransaction tx;
  final String currencyCode;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final amountColor = tx.type.isIncome
        ? Colors.green
        : Theme.of(context).colorScheme.error;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.description.isEmpty ? tx.category : tx.description,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(tx.category),
                ],
              ),
            ),
            Expanded(
              child: Text(
                tx.source,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${tx.type.isIncome ? '+' : '-'}${_money(currencyCode, tx.amount)}',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: amountColor,
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionEditorSheet extends StatefulWidget {
  const _TransactionEditorSheet({required this.profile, this.initial});

  final BudgetProfile profile;
  final BudgetTransaction? initial;

  @override
  State<_TransactionEditorSheet> createState() =>
      _TransactionEditorSheetState();
}

class _TransactionEditorSheetState extends State<_TransactionEditorSheet> {
  late BudgetTransactionType _type;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late String _category;
  late String _source;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final tx = widget.initial;
    _type = tx?.type ?? BudgetTransactionType.expense;
    _amountController = TextEditingController(
      text: tx == null ? '' : tx.amount.toStringAsFixed(0),
    );
    _descriptionController = TextEditingController(text: tx?.description ?? '');
    _source = tx?.source ?? BudgetingDefaults.moneySources.first;
    _date = tx?.occurredAt ?? DateTime.now();
    _category = _categories.first;
    if (tx != null && _categories.contains(tx.category)) {
      _category = tx.category;
    }
  }

  List<String> get _categories => _type.isIncome
      ? widget.profile.incomeCategories
      : widget.profile.expenseCategories;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
    });
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;
    Navigator.of(context).pop(
      BudgetTransaction(
        id: widget.initial?.id,
        type: _type,
        amount: amount,
        category: _category,
        description: _descriptionController.text.trim(),
        source: _source,
        occurredAt: DateTime(_date.year, _date.month, _date.day),
        createdAt: widget.initial?.createdAt ?? DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!_categories.contains(_category)) {
      _category = _categories.first;
    }
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF171F35) : Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initial == null ? 'Add transaction' : 'Edit transaction',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<BudgetTransactionType>(
                segments: const [
                  ButtonSegment(
                    value: BudgetTransactionType.expense,
                    label: Text('Expense'),
                  ),
                  ButtonSegment(
                    value: BudgetTransactionType.income,
                    label: Text('Income'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (value) {
                  setState(() {
                    _type = value.first;
                    _category = _categories.first;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _category = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _source,
                decoration: const InputDecoration(labelText: 'Source'),
                items: BudgetingDefaults.moneySources
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _source = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_rounded),
                label: Text(DateFormat('dd MMM yyyy').format(_date)),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(widget.initial == null ? 'Save' : 'Update'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TxGroup {
  const _TxGroup({required this.date, required this.items});

  final DateTime date;
  final List<BudgetTransaction> items;
}

List<_TxGroup> _groupedTransactions(List<BudgetTransaction> transactions) {
  final grouped = <String, List<BudgetTransaction>>{};
  for (final tx in transactions) {
    final key = DateFormat('yyyy-MM-dd').format(tx.occurredAt);
    grouped.putIfAbsent(key, () => []).add(tx);
  }
  final list = grouped.entries.map((entry) {
    final items = List<BudgetTransaction>.from(entry.value)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _TxGroup(date: DateTime.parse(entry.key), items: items);
  }).toList();
  list.sort((a, b) => b.date.compareTo(a.date));
  return list;
}

class _BudgetStats {
  const _BudgetStats({
    required this.balance,
    required this.monthIncome,
    required this.monthExpense,
    required this.totalBudget,
    required this.remainingBudget,
    required this.expenseByCategory,
  });

  final double balance;
  final double monthIncome;
  final double monthExpense;
  final double totalBudget;
  final double remainingBudget;
  final Map<String, double> expenseByCategory;

  factory _BudgetStats.fromData(_BudgetViewData data) {
    return _BudgetStats.forMonth(data.transactions, data.plans, data.month);
  }

  factory _BudgetStats.forMonth(
    List<BudgetTransaction> transactions,
    List<BudgetCategoryPlan> plans,
    DateTime month,
  ) {
    double balance = 0;
    double monthIncome = 0;
    double monthExpense = 0;
    final expenseByCategory = <String, double>{};
    for (final tx in transactions) {
      balance += tx.type.isIncome ? tx.amount : -tx.amount;
      final inMonth =
          tx.occurredAt.year == month.year &&
          tx.occurredAt.month == month.month;
      if (inMonth && tx.type.isIncome) {
        monthIncome += tx.amount;
      }
      if (inMonth && tx.type.isExpense) {
        monthExpense += tx.amount;
        expenseByCategory.update(
          tx.category,
          (value) => value + tx.amount,
          ifAbsent: () => tx.amount,
        );
      }
    }
    final totalBudget = plans.fold<double>(0, (sum, plan) => sum + plan.amount);
    return _BudgetStats(
      balance: balance,
      monthIncome: monthIncome,
      monthExpense: monthExpense,
      totalBudget: totalBudget,
      remainingBudget: totalBudget - monthExpense,
      expenseByCategory: expenseByCategory,
    );
  }
}

class _SpendDay {
  const _SpendDay({required this.day, required this.amount});

  final DateTime day;
  final double amount;
}

List<_SpendDay> _sevenDaySpendForMonth(
  List<BudgetTransaction> transactions,
  DateTime month,
) {
  final now = DateTime.now();
  final isCurrentMonth = now.year == month.year && now.month == month.month;
  final anchor = isCurrentMonth
      ? DateTime(now.year, now.month, now.day)
      : DateTime(month.year, month.month + 1, 0);
  return List.generate(7, (index) {
    final day = DateTime(
      anchor.year,
      anchor.month,
      anchor.day,
    ).subtract(Duration(days: 6 - index));
    final amount = transactions.fold<double>(0, (sum, tx) {
      final occurred = DateTime(
        tx.occurredAt.year,
        tx.occurredAt.month,
        tx.occurredAt.day,
      );
      if (tx.type.isExpense && occurred == day) return sum + tx.amount;
      return sum;
    });
    return _SpendDay(day: day, amount: amount);
  });
}

class _PieEntry {
  const _PieEntry({
    required this.category,
    required this.amount,
    required this.color,
  });

  final String category;
  final double amount;
  final Color color;
}

List<_PieEntry> _pieEntries(Map<String, double> expenseByCategory) {
  const colors = [
    Color(0xFF4B76E5),
    Color(0xFF3BB273),
    Color(0xFFFF8A5B),
    Color(0xFFF3C14B),
    Color(0xFF8E6CFF),
    Color(0xFF2AB7CA),
  ];
  final entries = expenseByCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return List.generate(
    entries.length,
    (index) => _PieEntry(
      category: entries[index].key,
      amount: entries[index].value,
      color: colors[index % colors.length],
    ),
  );
}

class _MonthlySummaryStrip extends StatelessWidget {
  const _MonthlySummaryStrip({required this.data, required this.stats});

  final _BudgetViewData data;
  final _BudgetStats stats;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('MMMM yyyy').format(data.month),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Expense',
                  value: _money(data.profile.currencyCode, stats.monthExpense),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  label: 'Income',
                  value: _money(data.profile.currencyCode, stats.monthIncome),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  label: 'Balance',
                  value: _money(
                    data.profile.currencyCode,
                    stats.monthIncome - stats.monthExpense,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetScore {
  const _BudgetScore({
    required this.value,
    required this.tone,
    required this.suggestions,
  });

  final int value;
  final String tone;
  final List<String> suggestions;

  factory _BudgetScore.fromStats(_BudgetViewData data, _BudgetStats stats) {
    final incomeGoalRatio = data.profile.monthlyIncomeGoal <= 0
        ? 1.0
        : (stats.monthIncome / data.profile.monthlyIncomeGoal).clamp(0.0, 1.2);
    final savings = stats.monthIncome - stats.monthExpense;
    final savingsRatio = data.profile.savingsGoal <= 0
        ? 1.0
        : (savings / data.profile.savingsGoal).clamp(0.0, 1.2);
    final budgetRatio = stats.totalBudget <= 0
        ? 0.6
        : (1 - ((stats.monthExpense - stats.totalBudget) / stats.totalBudget))
              .clamp(0.0, 1.2);
    final score =
        ((incomeGoalRatio * 30) + (savingsRatio * 35) + (budgetRatio * 35))
            .round()
            .clamp(0, 100);
    final suggestions = <String>[
      if (stats.totalBudget > 0 && stats.monthExpense > stats.totalBudget)
        'You are above this month\'s budget. Tighten the categories with the biggest spend first.',
      if (data.profile.monthlyIncomeGoal > 0 &&
          stats.monthIncome < data.profile.monthlyIncomeGoal)
        'Income is below your target, so this month benefits from a more defensive spending plan.',
      if (savings < data.profile.savingsGoal)
        'Your savings runway is behind goal. Consider trimming one flexible expense category this week.',
      if (stats.expenseByCategory.isNotEmpty)
        'Highest pressure category: ${_topExpenseCategory(stats.expenseByCategory)}. Review recent transactions there for quick wins.',
    ];
    return _BudgetScore(
      value: score,
      tone: score >= 80
          ? 'Strong control'
          : score >= 60
          ? 'Mostly healthy'
          : 'Needs attention',
      suggestions: suggestions.isEmpty
          ? const [
              'You are on track. Keep recording transactions to maintain a reliable score.',
            ]
          : suggestions,
    );
  }
}

class _BudgetScoreCard extends StatelessWidget {
  const _BudgetScoreCard({
    required this.data,
    required this.score,
    required this.stats,
  });

  final _BudgetViewData data;
  final _BudgetScore score;
  final _BudgetStats stats;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF24355D), Color(0xFF121B33)]
              : const [Color(0xFF2351B7), Color(0xFF6B9BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Budget score',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${score.value}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  score.tone,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 12,
              value: score.value / 100,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _GlassMetric(
                  label: 'Income goal',
                  value:
                      '${((stats.monthIncome / (data.profile.monthlyIncomeGoal == 0 ? 1 : data.profile.monthlyIncomeGoal)) * 100).clamp(0, 999).toStringAsFixed(0)}%',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GlassMetric(
                  label: 'Savings pace',
                  value: _money(
                    data.profile.currencyCode,
                    stats.monthIncome - stats.monthExpense,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'AI-style suggestions',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...score.suggestions
              .take(3)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _GlassMetric extends StatelessWidget {
  const _GlassMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightMonthHeader extends StatelessWidget {
  const _InsightMonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(month),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  const _PieChartPainter({
    required this.entries,
    required this.selectedCategory,
  });

  final List<_PieEntry> entries;
  final String? selectedCategory;

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.amount);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 18;
    var startAngle = -math.pi / 2;

    for (final entry in entries) {
      final sweep = (entry.amount / total) * math.pi * 2;
      final selected = entry.category == selectedCategory;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 34 : 28
        ..strokeCap = StrokeCap.round
        ..color = entry.color;
      final rect = Rect.fromCircle(
        center: center,
        radius: selected ? radius + 4 : radius,
      );
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.selectedCategory != selectedCategory;
  }
}

String _topExpenseCategory(Map<String, double> expenseByCategory) {
  var topLabel = 'Other';
  var topValue = -1.0;
  for (final entry in expenseByCategory.entries) {
    if (entry.value > topValue) {
      topLabel = entry.key;
      topValue = entry.value;
    }
  }
  return topLabel;
}

String _money(String currencyCode, double amount) {
  return NumberFormat.currency(
    symbol: '$currencyCode ',
    decimalDigits: 0,
  ).format(amount);
}
