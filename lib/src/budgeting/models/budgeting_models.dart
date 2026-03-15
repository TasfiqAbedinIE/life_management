import 'dart:convert';

enum BudgetTransactionType { income, expense }

extension BudgetTransactionTypeX on BudgetTransactionType {
  String get value =>
      this == BudgetTransactionType.income ? 'income' : 'expense';

  bool get isIncome => this == BudgetTransactionType.income;

  bool get isExpense => this == BudgetTransactionType.expense;

  static BudgetTransactionType fromValue(String value) {
    return value == 'income'
        ? BudgetTransactionType.income
        : BudgetTransactionType.expense;
  }
}

class BudgetingDefaults {
  static const List<String> moneySources = ['Cash', 'Card', 'Bank'];
}

class BudgetTransaction {
  const BudgetTransaction({
    this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.description,
    required this.source,
    required this.occurredAt,
    required this.createdAt,
  });

  final int? id;
  final BudgetTransactionType type;
  final double amount;
  final String category;
  final String description;
  final String source;
  final DateTime occurredAt;
  final DateTime createdAt;

  BudgetTransaction copyWith({
    int? id,
    BudgetTransactionType? type,
    double? amount,
    String? category,
    String? description,
    String? source,
    DateTime? occurredAt,
    DateTime? createdAt,
  }) {
    return BudgetTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      source: source ?? this.source,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'type': type.value,
      'amount': amount,
      'category': category,
      'description': description,
      'source': source,
      'occurred_at': occurredAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory BudgetTransaction.fromMap(Map<String, Object?> map) {
    return BudgetTransaction(
      id: map['id'] as int?,
      type: BudgetTransactionTypeX.fromValue(map['type'] as String),
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      description: (map['description'] as String?) ?? '',
      source:
          (map['source'] as String?) ?? BudgetingDefaults.moneySources.first,
      occurredAt: DateTime.parse(map['occurred_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class BudgetProfile {
  const BudgetProfile({
    required this.id,
    required this.monthlyBudget,
    required this.monthlyIncomeGoal,
    required this.savingsGoal,
    required this.currencyCode,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.updatedAt,
  });

  final int id;
  final double monthlyBudget;
  final double monthlyIncomeGoal;
  final double savingsGoal;
  final String currencyCode;
  final List<String> expenseCategories;
  final List<String> incomeCategories;
  final DateTime updatedAt;

  BudgetProfile copyWith({
    int? id,
    double? monthlyBudget,
    double? monthlyIncomeGoal,
    double? savingsGoal,
    String? currencyCode,
    List<String>? expenseCategories,
    List<String>? incomeCategories,
    DateTime? updatedAt,
  }) {
    return BudgetProfile(
      id: id ?? this.id,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      monthlyIncomeGoal: monthlyIncomeGoal ?? this.monthlyIncomeGoal,
      savingsGoal: savingsGoal ?? this.savingsGoal,
      currencyCode: currencyCode ?? this.currencyCode,
      expenseCategories: expenseCategories ?? this.expenseCategories,
      incomeCategories: incomeCategories ?? this.incomeCategories,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'monthly_budget': monthlyBudget,
      'monthly_income_goal': monthlyIncomeGoal,
      'savings_goal': savingsGoal,
      'currency_code': currencyCode,
      'expense_categories': jsonEncode(expenseCategories),
      'income_categories': jsonEncode(incomeCategories),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory BudgetProfile.defaultProfile() {
    return BudgetProfile(
      id: 1,
      monthlyBudget: 0,
      monthlyIncomeGoal: 55000,
      savingsGoal: 10000,
      currencyCode: 'BDT',
      expenseCategories: const [
        'Housing',
        'Food & Dining',
        'Transportation',
        'Bills & Utilities',
        'Shopping',
        'Entertainment',
        'Healthcare',
        'Education',
        'Travel',
        'Other',
      ],
      incomeCategories: const [
        'Salary',
        'Freelance',
        'Bonus',
        'Investment',
        'Gift',
        'Other',
      ],
      updatedAt: DateTime.now(),
    );
  }

  factory BudgetProfile.fromMap(Map<String, Object?> map) {
    final fallback = BudgetProfile.defaultProfile();
    return BudgetProfile(
      id: map['id'] as int,
      monthlyBudget: (map['monthly_budget'] as num?)?.toDouble() ?? 0,
      monthlyIncomeGoal: (map['monthly_income_goal'] as num).toDouble(),
      savingsGoal: (map['savings_goal'] as num).toDouble(),
      currencyCode: (map['currency_code'] as String?) ?? fallback.currencyCode,
      expenseCategories: _decodeList(
        map['expense_categories'] as String?,
        fallback.expenseCategories,
      ),
      incomeCategories: _decodeList(
        map['income_categories'] as String?,
        fallback.incomeCategories,
      ),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static List<String> _decodeList(String? raw, List<String> fallback) {
    if (raw == null || raw.isEmpty) return List<String>.from(fallback);
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    } catch (_) {
      return List<String>.from(fallback);
    }
  }
}

class BudgetCategoryPlan {
  const BudgetCategoryPlan({
    this.id,
    required this.monthKey,
    required this.category,
    required this.amount,
    required this.updatedAt,
  });

  final int? id;
  final String monthKey;
  final String category;
  final double amount;
  final DateTime updatedAt;

  BudgetCategoryPlan copyWith({
    int? id,
    String? monthKey,
    String? category,
    double? amount,
    DateTime? updatedAt,
  }) {
    return BudgetCategoryPlan(
      id: id ?? this.id,
      monthKey: monthKey ?? this.monthKey,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'month_key': monthKey,
      'category': category,
      'amount': amount,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory BudgetCategoryPlan.fromMap(Map<String, Object?> map) {
    return BudgetCategoryPlan(
      id: map['id'] as int?,
      monthKey: map['month_key'] as String,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

String budgetMonthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
