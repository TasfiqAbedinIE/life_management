import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/budgeting_repository.dart';
import '../models/budgeting_models.dart';

class BudgetSettingsPage extends StatefulWidget {
  const BudgetSettingsPage({
    super.key,
    required this.initialProfile,
    required this.initialMonth,
  });

  final BudgetProfile initialProfile;
  final DateTime initialMonth;

  @override
  State<BudgetSettingsPage> createState() => _BudgetSettingsPageState();
}

class _BudgetSettingsPageState extends State<BudgetSettingsPage> {
  final BudgetingRepository _repository = BudgetingRepository.instance;
  late BudgetProfile _profile;
  late DateTime _selectedMonth;
  late final TextEditingController _incomeGoalController;
  late final TextEditingController _savingsGoalController;
  late final TextEditingController _currencyController;
  final TextEditingController _expenseCategoryController =
      TextEditingController();
  final TextEditingController _incomeCategoryController =
      TextEditingController();
  late List<String> _expenseCategories;
  late List<String> _incomeCategories;
  Map<String, TextEditingController> _budgetControllers = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    _selectedMonth = DateTime(
      widget.initialMonth.year,
      widget.initialMonth.month,
    );
    _expenseCategories = List<String>.from(_profile.expenseCategories);
    _incomeCategories = List<String>.from(_profile.incomeCategories);
    _incomeGoalController = TextEditingController(
      text: _profile.monthlyIncomeGoal.toStringAsFixed(0),
    );
    _savingsGoalController = TextEditingController(
      text: _profile.savingsGoal.toStringAsFixed(0),
    );
    _currencyController = TextEditingController(text: _profile.currencyCode);
    _loadMonthPlans();
  }

  @override
  void dispose() {
    _incomeGoalController.dispose();
    _savingsGoalController.dispose();
    _currencyController.dispose();
    _expenseCategoryController.dispose();
    _incomeCategoryController.dispose();
    for (final controller in _budgetControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMonthPlans() async {
    final plans = await _repository.fetchCategoryPlans(
      budgetMonthKey(_selectedMonth),
    );
    final map = {for (final plan in plans) plan.category: plan.amount};

    for (final controller in _budgetControllers.values) {
      controller.dispose();
    }

    _budgetControllers = {
      for (final category in _expenseCategories)
        category: TextEditingController(
          text: (map[category] ?? 0).toStringAsFixed(0),
        ),
    };

    if (!mounted) return;
    setState(() {});
  }

  double get _totalBudget {
    return _budgetControllers.values.fold<double>(0, (sum, controller) {
      return sum + (double.tryParse(controller.text.trim()) ?? 0);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updatedProfile = _profile.copyWith(
        monthlyBudget: _totalBudget,
        monthlyIncomeGoal:
            double.tryParse(_incomeGoalController.text.trim()) ??
            _profile.monthlyIncomeGoal,
        savingsGoal:
            double.tryParse(_savingsGoalController.text.trim()) ??
            _profile.savingsGoal,
        currencyCode: _currencyController.text.trim().toUpperCase(),
        expenseCategories: _expenseCategories,
        incomeCategories: _incomeCategories,
        updatedAt: DateTime.now(),
      );

      final plans = <String, double>{
        for (final entry in _budgetControllers.entries)
          entry.key: double.tryParse(entry.value.text.trim()) ?? 0,
      };

      await _repository.replaceExpenseCategories(_expenseCategories);
      await _repository.replaceIncomeCategories(_incomeCategories);
      await _repository.saveProfile(updatedProfile);
      await _repository.saveCategoryPlans(
        monthKey: budgetMonthKey(_selectedMonth),
        plans: plans,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Budget settings saved.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
    _loadMonthPlans();
  }

  void _addExpenseCategory() {
    final value = _expenseCategoryController.text.trim();
    if (value.isEmpty || _expenseCategories.contains(value)) return;
    setState(() {
      _expenseCategories.add(value);
      _budgetControllers[value] = TextEditingController(text: '0');
      _expenseCategoryController.clear();
    });
  }

  void _addIncomeCategory() {
    final value = _incomeCategoryController.text.trim();
    if (value.isEmpty || _incomeCategories.contains(value)) return;
    setState(() {
      _incomeCategories.add(value);
      _incomeCategoryController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soft = isDark ? const Color(0xFF232B42) : const Color(0xFFF3F5FF);
    final border = isDark ? const Color(0xFF2A3552) : const Color(0xFFDDE3FF);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget settings'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _SettingsCard(
            title: 'Monthly budget by category',
            subtitle:
                'Set a different expense budget for each month. Total budget is calculated from the category amounts.',
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        DateFormat('MMMM yyyy').format(_selectedMonth),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: soft,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total budget',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _totalBudget.toStringAsFixed(0),
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 28,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ..._expenseCategories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            category,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _budgetControllers[category],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Budget',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'Goals and currency',
            subtitle:
                'Income goal and savings goal stay global while currency affects display formatting.',
            child: Column(
              children: [
                TextField(
                  controller: _incomeGoalController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Monthly income goal',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _savingsGoalController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Savings goal'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _currencyController,
                  decoration: const InputDecoration(labelText: 'Currency code'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'Expense categories',
            subtitle:
                'Manage which categories show up in budget setup and expense entry.',
            child: _CategoryEditor(
              controller: _expenseCategoryController,
              items: _expenseCategories,
              onAdd: _addExpenseCategory,
              onRemove: (item) {
                if (_expenseCategories.length <= 1) return;
                setState(() {
                  _expenseCategories.remove(item);
                  _budgetControllers.remove(item)?.dispose();
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'Income categories',
            subtitle: 'Manage the category list used when recording income.',
            child: _CategoryEditor(
              controller: _incomeCategoryController,
              items: _incomeCategories,
              onAdd: _addIncomeCategory,
              onRemove: (item) {
                if (_incomeCategories.length <= 1) return;
                setState(() {
                  _incomeCategories.remove(item);
                });
              },
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save changes'),
          ),
        ],
      ),
      backgroundColor: isDark
          ? const Color(0xFF0F1424)
          : const Color(0xFFF3F5FF),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171E31) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3552) : const Color(0xFFDDE3FF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(subtitle),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _CategoryEditor extends StatelessWidget {
  const _CategoryEditor({
    required this.controller,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  final TextEditingController controller;
  final List<String> items;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'Add new category'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: onAdd, child: const Text('Add')),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map(
                (item) => InputChip(
                  label: Text(item),
                  onDeleted: () => onRemove(item),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
