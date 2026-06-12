import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../core/db/app_database.dart';
import '../../core/money/money.dart';
import '../../core/widgets/selector_sheet.dart';
import '../../domain/ledger/ledger_service.dart';
import '../../domain/models/enums.dart';
import '../../providers/data_providers.dart';
import '../../providers/database_provider.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({
    super.key,
    this.editId,
    this.initialType,
    this.initialPersonId,
    this.initialAccountId,
    this.initialAmountMinor,
  });

  /// When set, the form loads this transaction and saves via update.
  final String? editId;

  /// Optional preselections (ignored when editing). Used by the
  /// person-ledger settle flow and the accounts screen's balance adjust.
  final TransactionType? initialType;
  final String? initialPersonId;
  final String? initialAccountId;
  final int? initialAmountMinor;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  var _type = TransactionType.expense;
  Account? _account;
  Account? _toAccount;
  Category? _category;
  Person? _person;
  var _date = DateTime.now();
  var _reduceBalance = false; // adjustment direction
  var _saving = false;
  String? _amountError;

  bool get _isEditing => widget.editId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadForEdit(widget.editId!);
    } else {
      _applyInitialValues();
    }
  }

  Future<void> _applyInitialValues() async {
    if (widget.initialType != null) _type = widget.initialType!;
    if (widget.initialAmountMinor != null) {
      _amountController.text = minorToInputString(widget.initialAmountMinor!);
    }
    final db = ref.read(databaseProvider);
    final personId = widget.initialPersonId;
    if (personId != null) {
      final person = await (db.select(db.people)
            ..where((p) => p.id.equals(personId)))
          .getSingleOrNull();
      if (person != null && mounted) setState(() => _person = person);
    }
    final accountId = widget.initialAccountId;
    if (accountId != null) {
      final account = await (db.select(db.accounts)
            ..where((a) => a.id.equals(accountId)))
          .getSingleOrNull();
      if (account != null && mounted) setState(() => _account = account);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadForEdit(String id) async {
    final db = ref.read(databaseProvider);
    final t = await ref.read(transactionsRepositoryProvider).findById(id);
    if (t == null) {
      showAppSnackBar('Transaction not found');
      if (mounted) context.pop();
      return;
    }

    Future<Account?> account(String? accountId) async => accountId == null
        ? null
        : (db.select(db.accounts)..where((a) => a.id.equals(accountId)))
            .getSingleOrNull();
    final category = t.categoryId == null
        ? null
        : await (db.select(db.categories)
              ..where((c) => c.id.equals(t.categoryId!)))
            .getSingleOrNull();
    final person = t.personId == null
        ? null
        : await (db.select(db.people)..where((p) => p.id.equals(t.personId!)))
            .getSingleOrNull();
    final mainAccount = await account(t.accountId);
    final toAccount = await account(t.toAccountId);

    if (!mounted) return;
    setState(() {
      _type = t.type;
      _amountController.text = minorToInputString(t.amountMinor);
      _noteController.text = t.note ?? '';
      _date = t.date.toLocal();
      _reduceBalance = t.isNegativeAdjustment;
      _account = mainAccount;
      _toAccount = toAccount;
      _category = category;
      _person = person;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(activeAccountsProvider).value ?? const [];
    // Default to the first account once loaded.
    if (_account == null && accounts.isNotEmpty) _account = accounts.first;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTypeChips(),
          const SizedBox(height: 16),
          _buildAmountField(),
          const SizedBox(height: 16),
          _PickerTile(
            icon: Icons.account_balance_wallet_outlined,
            label: _type == TransactionType.transfer ? 'From account' : 'Account',
            value: _account?.name,
            onTap: () => _pickAccount(accounts, forDestination: false),
          ),
          if (_type == TransactionType.transfer)
            _PickerTile(
              icon: Icons.account_balance_outlined,
              label: 'To account',
              value: _toAccount?.name,
              onTap: () => _pickAccount(accounts, forDestination: true),
            ),
          if (_type.usesCategory)
            _PickerTile(
              icon: Icons.category_outlined,
              label: 'Category',
              value: _category?.name ?? 'Optional',
              onTap: _pickCategory,
            ),
          if (_type.involvesPerson)
            _PickerTile(
              icon: Icons.person_outline,
              label: 'Person',
              value: _person?.name,
              onTap: _pickPerson,
            ),
          if (_type == TransactionType.adjustment) _buildAdjustmentDirection(),
          _PickerTile(
            icon: Icons.event_outlined,
            label: 'Date',
            value: DateFormat.yMMMd().format(_date),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(_saving ? 'Saving…' : (_isEditing ? 'Update' : 'Save')),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChips() {
    // Settlement appears as its two directions so the flow stays one tap.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in TransactionType.values)
          ChoiceChip(
            label: Text(type.label),
            selected: _type == type,
            onSelected: (_) => setState(() {
              _type = type;
              // Reset fields that don't apply to the new type.
              if (!_type.usesCategory) _category = null;
              if (_category != null &&
                  _category!.type.name != _type.name) {
                _category = null;
              }
              if (!_type.involvesPerson) _person = null;
              if (_type != TransactionType.transfer) _toAccount = null;
            }),
          ),
      ],
    );
  }

  Widget _buildAmountField() {
    return TextField(
      controller: _amountController,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: Theme.of(context).textTheme.headlineMedium,
      decoration: InputDecoration(
        labelText: 'Amount',
        prefixText: 'Rs. ',
        errorText: _amountError,
      ),
      onChanged: (_) {
        if (_amountError != null) setState(() => _amountError = null);
      },
    );
  }

  Widget _buildAdjustmentDirection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
            value: false,
            label: Text('Increase balance'),
            icon: Icon(Icons.add),
          ),
          ButtonSegment(
            value: true,
            label: Text('Reduce balance'),
            icon: Icon(Icons.remove),
          ),
        ],
        selected: {_reduceBalance},
        onSelectionChanged: (selection) =>
            setState(() => _reduceBalance = selection.single),
      ),
    );
  }

  Future<void> _pickAccount(List<Account> accounts,
      {required bool forDestination}) async {
    final picked = await showSelectorSheet<Account>(
      context: context,
      title: forDestination ? 'To account' : 'Account',
      items: accounts,
      tileBuilder: (sheetContext, account) => ListTile(
        leading: const Icon(Icons.account_balance_wallet_outlined),
        title: Text(account.name),
        subtitle: Text(formatMinor(account.balanceMinor)),
        onTap: () => Navigator.pop(sheetContext, account),
      ),
    );
    if (picked != null) {
      setState(() => forDestination ? _toAccount = picked : _account = picked);
    }
  }

  Future<void> _pickCategory() async {
    final type = _type == TransactionType.income
        ? CategoryType.income
        : CategoryType.expense;
    final categories =
        await ref.read(activeCategoriesProvider(type).future);
    if (!mounted) return;
    final picked = await showSelectorSheet<Category>(
      context: context,
      title: 'Category',
      items: categories,
      tileBuilder: (sheetContext, category) => ListTile(
        leading: const Icon(Icons.label_outline),
        title: Text(category.name),
        onTap: () => Navigator.pop(sheetContext, category),
      ),
    );
    if (picked != null) setState(() => _category = picked);
  }

  Future<void> _pickPerson() async {
    final people = await ref.read(activePeopleProvider.future);
    if (!mounted) return;
    final picked = await showSelectorSheet<Person>(
      context: context,
      title: 'Person',
      items: people,
      tileBuilder: (sheetContext, person) => ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(person.name),
        onTap: () => Navigator.pop(sheetContext, person),
      ),
      footer: ListTile(
        leading: const Icon(Icons.person_add_outlined),
        title: const Text('Add new person'),
        onTap: () async {
          final created = await _createPersonDialog();
          if (created != null && mounted) {
            // ignore: use_build_context_synchronously
            Navigator.pop(context, created);
          }
        },
      ),
    );
    if (picked != null) setState(() => _person = picked);
  }

  Future<Person?> _createPersonDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New person'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return null;
    return ref.read(peopleRepositoryProvider).create(name);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _date = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _date.hour,
            _date.minute,
          ));
    }
  }

  Future<void> _save() async {
    final amountMinor = parseAmountToMinor(_amountController.text);
    if (amountMinor == null) {
      setState(() => _amountError = 'Enter a valid amount');
      return;
    }
    final account = _account;
    if (account == null) {
      showAppSnackBar('Pick an account first');
      return;
    }
    if (_type == TransactionType.transfer && _toAccount == null) {
      showAppSnackBar('Pick a destination account');
      return;
    }
    if (_type.involvesPerson && _person == null) {
      showAppSnackBar('Pick a person');
      return;
    }

    setState(() => _saving = true);
    try {
      final draft = TransactionDraft(
        type: _type,
        amountMinor: amountMinor,
        date: _date,
        accountId: account.id,
        toAccountId: _toAccount?.id,
        categoryId: _category?.id,
        personId: _person?.id,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        isNegativeAdjustment:
            _type == TransactionType.adjustment && _reduceBalance,
      );
      final ledger = ref.read(ledgerServiceProvider);
      if (_isEditing) {
        await ledger.updateTransaction(widget.editId!, draft);
      } else {
        await ledger.createTransaction(draft);
      }
      HapticFeedback.mediumImpact();
      showAppSnackBar(
          '${_type.label} ${_isEditing ? 'updated' : 'saved'}');
      if (mounted) context.pop();
    } on LedgerValidationException catch (e) {
      showAppSnackBar(e.message);
      setState(() => _saving = false);
    } catch (_) {
      showAppSnackBar('Could not save — please try again');
      setState(() => _saving = false);
    }
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value ?? 'Tap to select'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
