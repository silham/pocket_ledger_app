/// Pure share-math for splitting an expense the user paid for across a group
/// (shared-apartment lunches, etc.). Keeps the money logic out of the UI and
/// testable, mirroring the rest of `lib/domain/ledger/`.
///
/// A split decomposes into existing transaction types and is written by
/// [LedgerService.createBatch]: the payer's own share (a participant with a
/// null personId) becomes an `expense`; every other participant becomes a
/// `lend`. The shares always sum to exactly the total, so account balances
/// stay consistent (see deltas.dart).
library;

/// One participant in a split.
class SplitParticipant {
  const SplitParticipant({this.personId, this.customMinor});

  /// `null` means *me* (the payer) — this share becomes an expense row.
  /// Otherwise it's another person who will owe me their share (a lend row).
  final String? personId;

  /// A locked exact share in minor units. When null, the participant shares
  /// the remainder equally with the other un-locked participants.
  final int? customMinor;

  bool get isMe => personId == null;
}

/// Raised when a split cannot be computed (e.g. custom shares exceed the
/// total). The message is shown to the user.
class SplitException implements Exception {
  SplitException(this.message);
  final String message;

  @override
  String toString() => 'SplitException: $message';
}

/// Computes each participant's share (minor units), aligned to [participants].
///
/// - Participants with a [SplitParticipant.customMinor] keep that exact amount.
/// - `remaining = total - sum(customs)` is divided equally among the rest; the
///   leftover 1-minor-unit remainder is handed out one-by-one to the first few
///   un-locked participants so the shares sum to exactly [totalMinor].
///
/// Throws [SplitException] when impossible: a negative total/custom, customs
/// that exceed the total, or an all-custom split whose customs don't add up.
List<int> computeSplitShares(
  int totalMinor,
  List<SplitParticipant> participants,
) {
  if (totalMinor <= 0) {
    throw SplitException('Enter a total greater than zero');
  }
  if (participants.isEmpty) {
    throw SplitException('Add at least one participant');
  }

  var customSum = 0;
  var openCount = 0;
  for (final p in participants) {
    final custom = p.customMinor;
    if (custom != null) {
      if (custom < 0) throw SplitException('A share cannot be negative');
      customSum += custom;
    } else {
      openCount++;
    }
  }

  final remaining = totalMinor - customSum;
  if (remaining < 0) {
    throw SplitException('Custom shares add up to more than the total');
  }

  if (openCount == 0) {
    if (remaining != 0) {
      throw SplitException('Custom shares must add up to the total');
    }
    return [for (final p in participants) p.customMinor!];
  }

  final base = remaining ~/ openCount;
  var extra = remaining - base * openCount; // 0 .. openCount-1

  return [
    for (final p in participants)
      if (p.customMinor != null)
        p.customMinor!
      else
        base + (extra-- > 0 ? 1 : 0),
  ];
}
