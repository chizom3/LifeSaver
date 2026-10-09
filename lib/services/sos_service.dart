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
    // Use `query` with percent-encoding: `queryParameters` encodes spaces
    // as '+', which many SMS apps show literally.
    return Uri(
      scheme: 'sms',
      path: contact,
      query: encodeQueryParameters({'body': message}),
    );
  }
}

String encodeQueryParameters(Map<String, String> params) {
  return params.entries
      .map((entry) {
        return '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}';
      })
      .join('&');
}
