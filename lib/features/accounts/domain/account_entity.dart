/// Domain entity for an account.
class AccountEntity {
  final int? id;
  final String name;
  final String accountType;
  final int balance;
  final String? description;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AccountEntity({
    this.id,
    required this.name,
    required this.accountType,
    this.balance = 0,
    this.description,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  AccountEntity copyWith({
    int? id,
    String? name,
    String? accountType,
    int? balance,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      accountType: accountType ?? this.accountType,
      balance: balance ?? this.balance,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
