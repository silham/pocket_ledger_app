/// "Update available" dialog for the in-app self-updater. Shows the new version
/// and changelog with Later / Update actions; on Update it streams download
/// progress, then Android's installer takes over. See update_service.dart.
library;

import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';

import '../../app.dart' show showAppSnackBar;
import 'update_service.dart';

/// Shows the update prompt. Barrier-dismissible so "Later" is always available.
Future<void> showUpdateDialog(BuildContext context, AppUpdate update) {
  return showDialog<void>(
    context: context,
    builder: (_) => _UpdateDialog(update: update),
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.update});

  final AppUpdate update;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  /// 0.0–1.0 while downloading; null before the user taps Update.
  double? _progress;
  bool _downloading = false;

  void _startUpdate() {
    setState(() {
      _downloading = true;
      _progress = 0;
    });
    const UpdateService().download(widget.update.apkUrl).listen(
      (event) {
        if (event.status == OtaStatus.DOWNLOADING) {
          final pct = double.tryParse(event.value ?? '');
          if (pct != null && mounted) setState(() => _progress = pct / 100);
        }
      },
      onError: (_) {
        if (mounted) Navigator.of(context).pop();
        showAppSnackBar('Update failed. Please try again later.');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.update.notes;
    return AlertDialog(
      title: Text('Update available — v${widget.update.version}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notes.isNotEmpty) ...[
            Flexible(child: SingleChildScrollView(child: Text(notes))),
            const SizedBox(height: 16),
          ],
          if (_downloading)
            LinearProgressIndicator(value: _progress)
          else
            const Text('Download and install the new version now?'),
        ],
      ),
      actions: _downloading
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: _startUpdate,
                child: const Text('Update'),
              ),
            ],
    );
  }
}
