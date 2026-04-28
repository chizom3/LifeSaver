import 'package:flutter/material.dart';

class EmergencyContact {
  final String name;
  final String phone;

  const EmergencyContact({required this.name, required this.phone});

  String get displayName {
    return name.isEmpty ? phone : '$name ($phone)';
  }
}

Future<String?> showSosConfirmationSheet({
  required BuildContext context,
  required String contact,
  required String message,
  required VoidCallback onEmergencyCall,
}) {
  final messageController = TextEditingController(text: message);

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Send SOS Alert",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "To: $contact",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const Text(
                "Message preview",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: messageController,
                  minLines: 5,
                  maxLines: 9,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.call),
                  label: const Text('Call emergency line 112'),
                  onPressed: onEmergencyCall,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.sms),
                      label: const Text("Send SMS"),
                      onPressed: () {
                        Navigator.pop(context, messageController.text);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  ).whenComplete(messageController.dispose);
}

Future<List<EmergencyContact>?> showContactPickerSheet({
  required BuildContext context,
  required List<EmergencyContact> contacts,
}) {
  return showModalBottomSheet<List<EmergencyContact>>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose SOS Contact',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Colors.red,
                child: Icon(Icons.groups, color: Colors.white),
              ),
              title: const Text('All emergency contacts'),
              subtitle: Text('${contacts.length} recipients'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, contacts),
            ),
            const Divider(),
            for (final contact in contacts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Colors.red,
                  child: Icon(Icons.contact_phone, color: Colors.white),
                ),
                title: Text(contact.displayName),
                subtitle: Text(contact.phone),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, [contact]),
              ),
          ],
        ),
      );
    },
  );
}
