class SosService {
  String buildMessage({
    required String mapLink,
    required String name,
    String age = '',
    required String blood,
    String address = '',
    String conditions = '',
    String medications = '',
    String preferredHospital = '',
    required String note,
    String locationLabel = 'My location',
  }) {
    final lines = <String>[
      'EMERGENCY! I need help.',
      if (name.isNotEmpty) 'Name: $name',
      if (age.isNotEmpty) 'Age: $age',
      if (blood.isNotEmpty) 'Blood type: $blood',
      if (address.isNotEmpty) 'Address: $address',
      if (conditions.isNotEmpty) 'Known conditions: $conditions',
      if (medications.isNotEmpty) 'Current medications: $medications',
      if (preferredHospital.isNotEmpty)
        'Preferred hospital: $preferredHospital',
      if (note.isNotEmpty) 'Medical notes: $note',
      '$locationLabel: $mapLink',
    ];

    return lines.join('\n');
  }

  Uri smsUri({required String contact, required String message}) {
    return Uri(
      scheme: 'sms',
      path: contact,
      queryParameters: {'body': message},
    );
  }
}
