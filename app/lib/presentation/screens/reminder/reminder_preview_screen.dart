import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/repositories.dart';
import '../../../core/utils/money_utils.dart';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../domain/entities/entities.dart';

import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

const _whatsAppShare = MethodChannel(
  'com.lendentracker.lenden_tracker/whatsapp_share',
);

final reminderLoanProvider = FutureProvider.family<ReminderPreviewData, int>((
  ref,
  id,
) async {
  final loans = ref.watch(loanRepoProvider);
  final items = await loans.listWithPeople();
  final item = items.firstWhere((item) => item.loan.id == id);
  final loan = item.loan;
  final payments = ref.watch(paymentRepoProvider);
  final principal = await payments.outstandingPrincipal(id);
  final person = await ref.watch(personRepoProvider).getById(loan.personId);
  final dues = await loans.duesForLoan(id);
  final paymentHistory = await payments.forLoan(id);
  final today = DateTime.now().toIso8601String().substring(0, 10);
  ScheduledDue? nextDue;
  for (final due in dues) {
    if (due.status == DueStatus.upcoming && due.dueDate.compareTo(today) >= 0) {
      nextDue = due;
      break;
    }
  }
  var unpaidPrincipal = 0;
  var unpaidInterest = 0;
  var remainingPayments = paymentHistory
      .where(
        (payment) =>
            !payment.reversed && payment.effectiveDate.compareTo(today) <= 0,
      )
      .fold<int>(0, (sum, payment) => sum + payment.totalMinor);
  for (final due in dues.where(
    (due) =>
        due.dueDate.compareTo(today) <= 0 &&
        due.status != DueStatus.paid &&
        due.status != DueStatus.waived,
  )) {
    final paidInterest = remainingPayments < due.interestMinor
        ? remainingPayments
        : due.interestMinor;
    remainingPayments -= paidInterest;
    final paidPrincipal = remainingPayments < due.principalMinor
        ? remainingPayments
        : due.principalMinor;
    remainingPayments -= paidPrincipal;
    unpaidInterest += due.interestMinor - paidInterest;
    unpaidPrincipal += due.principalMinor - paidPrincipal;
  }
  return ReminderPreviewData(
    item: item,
    phone: person?.phoneE164 ?? '',
    outstandingPrincipalMinor: principal,
    nextDueDate: nextDue?.dueDate ?? item.nextDueDate ?? loan.maturityDate,
    duePrincipalMinor: unpaidPrincipal,
    scheduledPrincipalMinor: nextDue?.principalMinor ?? 0,
    scheduledInterestMinor: nextDue?.interestMinor ?? 0,
    dueInterestMinor: unpaidInterest,
    currentDueMinor: unpaidPrincipal + unpaidInterest,
  );
});

class ReminderPreviewData {
  const ReminderPreviewData({
    required this.item,
    required this.phone,
    required this.outstandingPrincipalMinor,
    required this.nextDueDate,
    required this.duePrincipalMinor,
    required this.scheduledPrincipalMinor,
    required this.scheduledInterestMinor,
    required this.dueInterestMinor,
    required this.currentDueMinor,
  });
  final LoanListItem item;
  final String phone;
  final int outstandingPrincipalMinor;
  final String? nextDueDate;
  final int duePrincipalMinor;
  final int scheduledPrincipalMinor;
  final int scheduledInterestMinor;
  final int dueInterestMinor;
  final int currentDueMinor;
}

class ReminderPreviewScreen extends ConsumerStatefulWidget {
  const ReminderPreviewScreen({super.key, required this.loanId});
  final int loanId;

  @override
  ConsumerState<ReminderPreviewScreen> createState() =>
      _ReminderPreviewScreenState();
}

class _ReminderPreviewScreenState extends ConsumerState<ReminderPreviewScreen> {
  final _controller = ScreenshotController();
  final _captionController = TextEditingController();
  bool _sharing = false;
  String _whatsAppAvailability = 'unknown';

  @override
  void initState() {
    super.initState();
    _checkWhatsAppInstalled();
  }

  Future<void> _checkWhatsAppInstalled() async {
    try {
      final availability = await _whatsAppShare.invokeMethod<String>(
        'availability',
      );
      if (mounted) {
        setState(() => _whatsAppAvailability = availability ?? 'unknown');
      }
    } on PlatformException {
      if (mounted) setState(() => _whatsAppAvailability = 'unknown');
    } on MissingPluginException {
      if (mounted) setState(() => _whatsAppAvailability = 'unknown');
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  String get _shareText {
    final caption = _captionController.text.trim();
    return caption.isEmpty
        ? 'A friendly loan reminder. Please choose the recipient yourself; nothing is sent automatically.'
        : '$caption Please choose the recipient yourself; nothing is sent automatically.';
  }

  Future<void> _shareWhatsApp(LoanListItem item) async {
    setState(() => _sharing = true);
    var message = 'Could not open WhatsApp. Use Share via another app instead.';
    try {
      final image = await _controller.capture(pixelRatio: 2);
      if (image == null) throw StateError('Image unavailable');
      final opened = await _whatsAppShare.invokeMethod<bool>('shareImage', {
        'image': image,
        'text': _shareText,
      });
      if (opened == true) {
        message = 'WhatsApp opened. Select a recipient there; delivery is not confirmed.';
      } else {
        await _checkWhatsAppInstalled();
      }
    } on PlatformException {
      await _checkWhatsAppInstalled();
    } on MissingPluginException {
      // Generic chooser remains available if this platform has no native handler.
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _share(LoanListItem item) async {
    setState(() => _sharing = true);
    var message = 'Sharing is unavailable right now. You can try again later.';
    try {
      final Uint8List? image = await _controller.capture(pixelRatio: 2);
      if (image == null) throw StateError('Image unavailable');
      final result = await Share.shareXFiles([
        XFile.fromData(
          image,
          mimeType: 'image/png',
          name: 'reminder_${item.loan.id}.png',
        ),
      ], text: _shareText);
      message = result.status == ShareResultStatus.dismissed
          ? 'Sharing cancelled. The reminder was not sent.'
          : 'Share sheet closed. Delivery is not confirmed.';
    } catch (_) {
      message = 'Sharing is unavailable right now. You can try again later.';
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _saveImage(LoanListItem item) async {
    try {
      final Uint8List? image = await _controller.capture(pixelRatio: 2);
      if (image == null) throw StateError('Image unavailable');
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save reminder image',
        fileName: 'reminder_${item.loan.id}.png',
        type: FileType.custom,
        allowedExtensions: const ['png'],
        bytes: image,
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Reminder image saved.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the reminder image.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loanAsync = ref.watch(reminderLoanProvider(widget.loanId));
    return Scaffold(
      appBar: AppBar(title: const Text('Review reminder')),
      body: loanAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () =>
                ref.invalidate(reminderLoanProvider(widget.loanId)),
            child: const Text('Could not load loan. Retry'),
          ),
        ),
        data: (preview) {
          final item = preview.item;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'To: ${item.personName}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Screenshot(
                controller: _controller,
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'A friendly reminder',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Hi ${item.personName},'),
                      const SizedBox(height: 12),
                      Text(
                        'Loan reference #${item.loan.id} · as of ${DateTime.now().toIso8601String().substring(0, 10)}',
                      ),
                      const SizedBox(height: 8),
                      const Text('Outstanding principal'),
                      const SizedBox(height: 8),
                      Text(
                        MoneyUtils.format(
                          preview.outstandingPrincipalMinor,
                          item.loan.currency,
                        ),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Due date: ${preview.nextDueDate ?? 'Not scheduled'}',
                      ),
                      Text(
                        'Due principal: ${MoneyUtils.format(preview.scheduledPrincipalMinor, item.loan.currency)}',
                      ),
                      Text(
                        'Due interest: ${MoneyUtils.format(preview.dueInterestMinor, item.loan.currency)}',
                      ),
                      Text(
                        'Scheduled interest: ${MoneyUtils.format(preview.scheduledInterestMinor, item.loan.currency)}',
                      ),
                      Text(
                        'Current due: ${MoneyUtils.format(preview.currentDueMinor, item.loan.currency)}',
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Please let me know if you have any questions.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Phone: ${preview.phone.isEmpty ? 'Not available' : preview.phone}',
              ),
              const Text('Notes are kept private and excluded from the image.'),
              Text(
                'Current due: ${MoneyUtils.format(preview.currentDueMinor, item.loan.currency)} · ${preview.nextDueDate ?? 'No date set'}',
              ),
              const SizedBox(height: 8),
              const Text(
                'Sharing does not confirm delivery. The recipient may not receive or read it.',
              ),
              const Text(
                'WhatsApp opens its own recipient picker. The number above is for your reference only; no recipient is selected or sent a message automatically.',
              ),
              if (_whatsAppAvailability == 'missing' ||
                  _whatsAppAvailability == 'noHandler') ...[
                const SizedBox(height: 8),
                Text(
                  _whatsAppAvailability == 'missing'
                      ? 'WhatsApp is not installed. Save the image or share via another app.'
                      : 'WhatsApp cannot handle reminder images on this device. Share via another app instead.',
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _captionController,
                maxLength: 240,
                decoration: const InputDecoration(
                  labelText: 'Optional caption',
                ),
              ),
              const SizedBox(height: 12),
              if (_whatsAppAvailability == 'available')
                FilledButton(
                  onPressed: _sharing ? null : () => _shareWhatsApp(item),
                  child: const Text('Share via WhatsApp'),
                ),
              FilledButton(
                onPressed: _sharing ? null : () => _share(item),
                child: Text(_sharing ? 'Preparing…' : 'Share via another app'),
              ),
              TextButton.icon(
                onPressed: _sharing ? null : () => _saveImage(item),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Save image'),
              ),
            ],
          );
        },
      ),
    );
  }
}
