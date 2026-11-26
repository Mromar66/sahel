import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safwa/features/accounts/data/account_repository.dart';
import 'package:safwa/features/accounts/domain/account_entity.dart';
import 'package:safwa/core/utils/currency_utils.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository();
});

class AccountNotifier extends StateNotifier<List<AccountEntity>> {
  final AccountRepository _repository;
  AccountNotifier(this._repository) : super([]);

  Future<void> loadAccounts() async {
    state = await _repository.getAllAccounts();
  }

  Future<void> addAccount(AccountEntity account) async {
    await _repository.insertAccount(account);
    await loadAccounts();
  }

  Future<void> updateAccount(AccountEntity account) async {
    await _repository.updateAccount(account);
    await loadAccounts();
  }

  Future<void> deleteAccount(int id) async {
    await _repository.deleteAccount(id);
    await loadAccounts();
  }

  String formatBalance(int amount) => CurrencyUtils.format(amount);
}

final accountNotifierProvider =
    StateNotifierProvider<AccountNotifier, List<AccountEntity>>((ref) {
      final repo = ref.watch(accountRepositoryProvider);
      return AccountNotifier(repo);
    });
