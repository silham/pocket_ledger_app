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
import '../../domain/ledger/split.dart';
import '../../domain/models/enums.dart';
import '../../providers/data_providers.dart';
import '../../providers/database_provider.dart';
import 'split_people_sheet.dart';

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

  // Split-expense state (new transactions only; expense type only).
  var _split = false;
  var _includeMe = true;
  final List<_SplitRow> _participants = [];

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
          if (_type == TransactionType.expense && !_isEditing)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.call_split_outlined),
              title: const Text('Split this expense'),
              subtitle: const Text('Share the cost with people in the apartment'),
              value: _split,
              onChanged: (on) => setState(() => _split = on),
            ),
          if (_split) ..._buildSplitEditor(),
          if (_type.usesCategory && !(_split && !_includeMe))
            _PickerTile(
              icon: Icons.category_outlined,
              label: _split ? 'Category (your share)' : 'Category',
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
              if (_type != TransactionType.expense) _split = false;
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
        labelText: _split ? 'Total paid' : 'Amount',
        prefixText: 'Rs. ',
        errorText: _amountError,
      ),
      onChanged: (_) {
        // Re-render the live split preview as the total changes.
        setState(() => _amountError = null);
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

  // ----------------------------------------------------------- split editor

  /// Aligned (owner, share) data for the current split inputs. Index 0 is
  /// "me" (owner == null) when [_includeMe]; the rest follow [_participants]
  /// order. Returns null when there isn't enough input yet; throws
  /// [SplitException] when the custom amounts are inconsistent.
  ({List<Person?> owners, List<int> shares})? _computeSplit(int? totalMinor) {
    if (totalMinor == null || _participants.isEmpty) return null;
    final owners = <Person?>[];
    final parts = <SplitParticipant>[];
    if (_includeMe) {
      owners.add(null);
      parts.add(const SplitParticipant());
    }
    for (final row in _participants) {
      owners.add(row.person);
      parts.add(SplitParticipant(
        personId: row.person.id,
        customMinor: row.customMinor,
      ));
    }
    return (owners: owners, shares: computeSplitShares(totalMinor, parts));
  }

  List<Widget> _buildSplitEditor() {
    final total = parseAmountToMinor(_amountController.text);
    return [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.person_pin_circle_outlined),
        title: const Text('Include my share'),
        subtitle: const Text('Counts your portion as an expense'),
        value: _includeMe,
        onChanged: (on) => setState(() => _includeMe = on),
      ),
      Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            if (_participants.isEmpty)
              const ListTile(
                leading: Icon(Icons.group_outlined),
                title: Text('No one added yet'),
                subtitle: Text('Add the people who shared this expense'),
              )
            else
              ..._buildParticipantTiles(total),
            ListTile(
              leading: const Icon(Icons.group_add_outlined),
              title: Text(
                _participants.isEmpty ? 'Add people' : 'Add / edit people',
              ),
              onTap: _addParticipants,
            ),
          ],
        ),
      ),
      _buildSplitPreview(total),
      const SizedBox(height: 8),
    ];
  }

  List<Widget> _buildParticipantTiles(int? total) {
    final shareById = <String, int>{};
    try {
      final split = _computeSplit(total);
      if (split != null) {
        for (var i = 0; i < split.owners.length; i++) {
          final owner = split.owners[i];
          if (owner != null) shareById[owner.id] = split.shares[i];
        }
      }
    } on SplitException {
      // Shares unknown for now; the preview line surfaces the error.
    }
    return [
      for (final row in _participants)
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(row.person.name),
          subtitle: Text(row.customMinor != null ? 'Custom share' : 'Equal share'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                shareById.containsKey(row.person.id)
                    ? formatMinor(shareById[row.person.id]!)
                    : '—',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Set exact share',
                onPressed: () => _editShare(row),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Remove',
                onPressed: () => setState(() => _participants.remove(row)),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _buildSplitPreview(int? total) {
    final colorScheme = Theme.of(context).colorScheme;
    String message;
    Color? color;
    if (total == null) {
      message = 'Enter the total to see each share';
    } else if (_participants.isEmpty) {
      message = 'Add people to split with';
    } else {
      try {
        final split = _computeSplit(total)!;
        var myShare = 0;
        var othersTotal = 0;
        var owe = 0;
        for (var i = 0; i < split.owners.length; i++) {
          if (split.owners[i] == null) {
            myShare += split.shares[i];
          } else {
            othersTotal += split.shares[i];
            owe++;
          }
        }
        message = [
          'You paid ${formatMinor(total)}',
          '$owe ${owe == 1 ? 'person owes' : 'people owe'} you '
              '${formatMinor(othersTotal)}',
          if (_includeMe) 'your share ${formatMinor(myShare)}',
        ].join(' · ');
      } on SplitException catch (e) {
        message = e.message;
        color = colorScheme.error;
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color ?? colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  Future<void> _addParticipants() async {
    final people = await ref.read(peopleRepositoryProvider).getActive();
    if (!mounted) return;
    final current = {for (final r in _participants) r.person};
    final chosen = await showSplitPeopleSheet(
      context: context,
      people: people,
      selected: current,
      onAddPerson: _createPersonDialog,
    );
    if (chosen == null || !mounted) return;
    setState(() {
      // Keep existing rows (with their custom amounts) for still-selected
      // people; add rows for newly selected ones; drop removed ones.
      final next = <_SplitRow>[];
      for (final person in chosen) {
        _SplitRow? existing;
        for (final r in _participants) {
          if (r.person.id == person.id) {
            existing = r;
            break;
          }
        }
        next.add(existing ?? _SplitRow(person));
      }
      _participants
        ..clear()
        ..addAll(next);
    });
  }

  Future<void> _editShare(_SplitRow row) async {
    final controller = TextEditingController(
      text: row.customMinor != null ? minorToInputString(row.customMinor!) : '',
    );
    final result = await showDialog<_ShareEdit>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("${row.person.name}'s share"),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Exact amount',
            prefixText: 'Rs. ',
            helperText: 'Leave blank to split equally',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, const _ShareEdit.clear()),
            child: const Text('Split equally'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                Navigator.pop(dialogContext, const _ShareEdit.clear());
                return;
              }
              final minor = parseAmountToMinor(text);
              if (minor == null) {
                showAppSnackBar('Enter a valid amount');
                return;
              }
              Navigator.pop(dialogContext, _ShareEdit.set(minor));
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() => row.customMinor = result.minor);
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
        await ref.read(categoriesRepositoryProvider).getActive(type);
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
    final people = await ref.read(peopleRepositoryProvider).getActive();
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
    if (_split) {
      await _saveSplit(amountMinor, account);
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

  /// Fans one paid total out into a `lend` per other participant plus an
  /// `expense` for the user's own share, written atomically via [createBatch].
  Future<void> _saveSplit(int totalMinor, Account account) async {
    if (_participants.isEmpty) {
      showAppSnackBar('Add at least one person to split with');
      return;
    }
    final List<Person?> owners;
    final List<int> shares;
    try {
      final split = _computeSplit(totalMinor)!;
      owners = split.owners;
      shares = split.shares;
    } on SplitException catch (e) {
      showAppSnackBar(e.message);
      return;
    }

    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();
    final drafts = <TransactionDraft>[];
    for (var i = 0; i < owners.length; i++) {
      final share = shares[i];
      if (share <= 0) continue; // amounts must be positive; skip zero shares
      final owner = owners[i];
      drafts.add(TransactionDraft(
        type: owner == null ? TransactionType.expense : TransactionType.lend,
        amountMinor: share,
        date: _date,
        accountId: account.id,
        categoryId: owner == null ? _category?.id : null,
        personId: owner?.id,
        note: note,
      ));
    }
    if (drafts.isEmpty) {
      showAppSnackBar('Nothing to record — every share is zero');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(ledgerServiceProvider).createBatch(drafts);
      HapticFeedback.mediumImpact();
      showAppSnackBar('Split saved — ${drafts.length} entries');
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

/// A person in the split, plus an optional locked exact share. Mutable so the
/// editor can toggle a custom amount in place.
class _SplitRow {
  _SplitRow(this.person);
  final Person person;
  int? customMinor;
}

/// Result of the per-person "set exact share" dialog: [minor] is null to clear
/// the override (back to an equal split), or the locked amount.
class _ShareEdit {
  const _ShareEdit.clear() : minor = null;
  const _ShareEdit.set(this.minor);
  final int? minor;
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
