import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger_app/domain/ledger/split.dart';

/// Convenience: an un-locked (equal-share) participant. `me` has a null id.
SplitParticipant _open({String? id}) => SplitParticipant(personId: id);
SplitParticipant _custom(int minor, {String? id}) =>
    SplitParticipant(personId: id, customMinor: minor);

void main() {
  group('computeSplitShares', () {
    test('equal split with no remainder', () {
      final shares = computeSplitShares(100000, [
        _open(id: 'a'),
        _open(id: 'b'),
        _open(id: 'c'),
        _open(id: 'd'),
      ]);
      expect(shares, [25000, 25000, 25000, 25000]);
      expect(shares.reduce((a, b) => a + b), 100000);
    });

    test('equal split distributes the remainder fairly and sums exactly', () {
      final shares = computeSplitShares(100000, [
        _open(id: 'a'),
        _open(id: 'b'),
        _open(id: 'c'),
      ]);
      // 100000 / 3 = 33333 r1 -> first participant gets the extra cent.
      expect(shares, [33334, 33333, 33333]);
      expect(shares.reduce((a, b) => a + b), 100000);
    });

    test('include-me adds the payer as an equal participant', () {
      final shares = computeSplitShares(100000, [
        _open(), // me
        _open(id: 'a'),
        _open(id: 'b'),
        _open(id: 'c'),
        _open(id: 'd'),
      ]);
      expect(shares, [20000, 20000, 20000, 20000, 20000]);
    });

    test('exclude-me splits the whole total across the others', () {
      final shares = computeSplitShares(100000, [
        _open(id: 'a'),
        _open(id: 'b'),
        _open(id: 'c'),
        _open(id: 'd'),
        _open(id: 'e'),
      ]);
      expect(shares, [20000, 20000, 20000, 20000, 20000]);
    });

    test('one custom amount; the rest re-split equally', () {
      final shares = computeSplitShares(100000, [
        _open(), // me
        _custom(40000, id: 'a'),
        _open(id: 'b'),
        _open(id: 'c'),
      ]);
      // remaining 60000 across me, b, c -> 20000 each.
      expect(shares, [20000, 40000, 20000, 20000]);
      expect(shares.reduce((a, b) => a + b), 100000);
    });

    test('all-custom shares that sum to the total are kept verbatim', () {
      final shares = computeSplitShares(100000, [
        _custom(50000, id: 'a'),
        _custom(30000, id: 'b'),
        _custom(20000, id: 'c'),
      ]);
      expect(shares, [50000, 30000, 20000]);
    });

    test('all-custom shares that do not sum to the total throw', () {
      expect(
        () => computeSplitShares(100000, [
          _custom(50000, id: 'a'),
          _custom(30000, id: 'b'),
        ]),
        throwsA(isA<SplitException>()),
      );
    });

    test('custom amounts exceeding the total throw', () {
      expect(
        () => computeSplitShares(100000, [
          _custom(60000, id: 'a'),
          _open(id: 'b'),
        ]),
        throwsA(isA<SplitException>()),
      );
    });

    test('a negative custom share throws', () {
      expect(
        () => computeSplitShares(100000, [_custom(-1, id: 'a'), _open(id: 'b')]),
        throwsA(isA<SplitException>()),
      );
    });

    test('zero or negative total throws', () {
      expect(() => computeSplitShares(0, [_open(id: 'a')]),
          throwsA(isA<SplitException>()));
    });

    test('empty participant list throws', () {
      expect(() => computeSplitShares(100000, const []),
          throwsA(isA<SplitException>()));
    });
  });
}
