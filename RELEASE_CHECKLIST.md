# Pocket Ledger — Release Checklist

## 1. Automated checks

```bash
flutter analyze
flutter test
```

## 2. Manual test pass (every balance-affecting flow)

Run on a device/emulator (`flutter run`). After **each** step, confirm the
dashboard total and the account balances match what you expect, then run
**Settings → Verify balances** at the end — it must say all balances check out.

- [ ] Fresh install: 20 default categories + Cash account exist
- [ ] Add expense (with category + note) → Cash decreases, dashboard "Spent today" updates
- [ ] Add income → Cash increases
- [ ] Add second account (Bank), transfer Cash → Bank → both balances move, total unchanged
- [ ] Adjustment increase and decrease
- [ ] Lend to a new person → Cash down, People tab shows "owes you"
- [ ] Partial settle (Record repayment with smaller amount) → remaining debt correct
- [ ] Full settle → "All settled", balances restored
- [ ] Borrow + Pay back flow (the reverse direction)
- [ ] Edit a transaction's amount → balance re-applied correctly
- [ ] Edit a transaction's account → both accounts corrected
- [ ] Swipe-delete a transaction → balance reversed
- [ ] Budgets: set overall + category budget, spend into warning (≥80%) and over (>100%) states
- [ ] Reports: previous month navigation shows correct scoped numbers
- [ ] Archive account (blocked when it's the last one), archive category, archive person
- [ ] Settings → Export backup produces a JSON file via the share sheet
- [ ] Dark mode (Settings → theme) — skim every screen
- [ ] Kill the app, reopen: all data still there

## 3. One-time: create the upload keystore (keep it safe + backed up!)

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties` (gitignored):

```
storeFile=/Users/shakil/upload-keystore.jks
storePassword=<password>
keyAlias=upload
keyPassword=<password>
```

If `key.properties` is missing, release builds fall back to debug signing
(fine for sideloading on your own phone, rejected by Play).

## 4. Build

```bash
# Sideload on your own phone:
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk

# Play Store (internal testing track):
flutter build appbundle --release
# -> build/app/outputs/bundle/release/app-release.aab
```

Upload the .aab in Play Console → Testing → Internal testing.
Bump `version:` in pubspec.yaml (e.g. 1.0.1+2) before each new upload.

## 5. Play listing essentials

- App name: Pocket Ledger
- Category: Finance
- Data safety: all data stored on-device, no data collected/shared
- Screenshots: dashboard, add transaction, people ledger, budgets (light + dark)
