import 'package:dlibphonenumber/dlibphonenumber.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../../domain/services/phone_number_service.dart';

/// The single selected contact snapshot; no address book is persisted.
class ContactSnapshot {
  const ContactSnapshot({
    required this.id,
    required this.name,
    required this.phone,
  });
  final String id;
  final String name;
  final String phone;
}

Future<ContactSnapshot?> selectContactSnapshot(BuildContext context) async {
  if (!await FlutterContacts.requestPermission(readonly: true)) {
    throw StateError(
      'Contact access is unavailable. Existing loans remain accessible.',
    );
  }
  if (!context.mounted) return null;
  final picked = await FlutterContacts.openExternalPick();
  if (picked == null) return null;
  final contact =
      await FlutterContacts.getContact(picked.id, withProperties: true) ??
      picked;
  if (!context.mounted) return null;
  if (contact.phones.isEmpty) {
    throw StateError('This contact has no phone number.');
  }
  String? selected;
  if (contact.phones.length == 1) {
    selected = contact.phones.single.number;
  } else {
    selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Choose a phone number')),
            for (final phone in contact.phones)
              ListTile(
                title: Text(phone.number),
                onTap: () => Navigator.pop(sheet, phone.number),
              ),
          ],
        ),
      ),
    );
  }
  if (selected == null || !context.mounted) return null;
  final phone = await showDialog<String>(
    context: context,
    builder: (dialog) => _PhoneSelectionDialog(initialNumber: selected!),
  );
  if (phone == null) return null;
  return ContactSnapshot(
    id: contact.id,
    name: contact.displayName,
    phone: phone,
  );
}

class _PhoneSelectionDialog extends StatefulWidget {
  const _PhoneSelectionDialog({required this.initialNumber});
  final String initialNumber;

  @override
  State<_PhoneSelectionDialog> createState() => _PhoneSelectionDialogState();
}

class _PhoneSelectionDialogState extends State<_PhoneSelectionDialog> {
  late final TextEditingController _number = TextEditingController(
    text: widget.initialNumber,
  );
  String _region = 'IN';
  bool _invalid = false;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Confirm contact phone'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _number,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Selected number',
            errorText: _invalid ? 'Invalid number for selected country' : null,
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: _region,
          decoration: const InputDecoration(
            labelText: 'Country for national numbers',
          ),
          items: (PhoneNumberUtil.instance.supportedRegions.toList()..sort())
              .map((code) => DropdownMenuItem(value: code, child: Text(code)))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _region = value);
          },
        ),
        const Text('Numbers beginning with + use their own country code.'),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final phone = PhoneNumberService.normalize(
            _number.text,
            region: _region,
          );
          if (phone == null) {
            setState(() => _invalid = true);
            return;
          }
          Navigator.pop(context, phone);
        },
        child: const Text('Use number'),
      ),
    ],
  );
}
