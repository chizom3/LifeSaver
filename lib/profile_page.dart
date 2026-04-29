import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameCtrl = TextEditingController();
  final _photoUrlCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _bloodCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  final _medicationsCtrl = TextEditingController();
  final _preferredHospitalCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _criticalWarningCtrl = TextEditingController();
  final List<TextEditingController> _allergyCtrls = [];
  final List<TextEditingController> _medicationCtrls = [];
  final List<TextEditingController> _contactNameCtrls = [];
  final List<TextEditingController> _contactPhoneCtrls = [];
  final List<TextEditingController> _contactRelationshipCtrls = [];
  static const _bloodTypes = [
    '',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];
  static const _relationships = [
    '',
    'Mother',
    'Father',
    'Spouse',
    'Partner',
    'Sibling',
    'Child',
    'Friend',
    'Doctor',
    'Caregiver',
    'Other',
  ];
  final ImagePicker _imagePicker = ImagePicker();

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _photoUrlCtrl.dispose();
    _ageCtrl.dispose();
    _bloodCtrl.dispose();
    _addressCtrl.dispose();
    _conditionsCtrl.dispose();
    _medicationsCtrl.dispose();
    _preferredHospitalCtrl.dispose();
    _noteCtrl.dispose();
    _criticalWarningCtrl.dispose();
    _disposeControllers(_allergyCtrls);
    _disposeControllers(_medicationCtrls);
    for (final controller in _contactNameCtrls) {
      controller.dispose();
    }
    for (final controller in _contactPhoneCtrls) {
      controller.dispose();
    }
    for (final controller in _contactRelationshipCtrls) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final contactNames = prefs.getStringList('contact_names') ?? [];
    final contactRelationships =
        prefs.getStringList('contact_relationships') ?? [];
    var contactPhones = prefs.getStringList('contact_phones') ?? [];
    var allergies = prefs.getStringList('allergy_items') ?? [];
    var medications = prefs.getStringList('medication_items') ?? [];

    final legacyContact = prefs.getString('contact') ?? '';
    if (contactPhones.isEmpty && legacyContact.trim().isNotEmpty) {
      contactPhones = [legacyContact];
    }
    if (allergies.isEmpty) {
      final note = prefs.getString('note') ?? '';
      if (note.trim().isNotEmpty) allergies = [note.trim()];
    }
    if (medications.isEmpty) {
      final legacyMedications = prefs.getString('medications') ?? '';
      medications = _splitItems(legacyMedications);
    }

    if (!mounted) return;
    setState(() {
      _nameCtrl.text = prefs.getString('name') ?? '';
      _photoUrlCtrl.text = prefs.getString('photo_url') ?? '';
      _ageCtrl.text = prefs.getString('age') ?? '';
      _bloodCtrl.text = prefs.getString('blood') ?? '';
      _addressCtrl.text = prefs.getString('address') ?? '';
      _conditionsCtrl.text = prefs.getString('conditions') ?? '';
      _medicationsCtrl.text = prefs.getString('medications') ?? '';
      _preferredHospitalCtrl.text = prefs.getString('preferred_hospital') ?? '';
      _noteCtrl.text = prefs.getString('note') ?? '';
      _criticalWarningCtrl.text = prefs.getString('critical_warning') ?? '';

      _resetControllers(_allergyCtrls, allergies.isEmpty ? [''] : allergies);
      _resetControllers(
        _medicationCtrls,
        medications.isEmpty ? [''] : medications,
      );

      _clearContactControllers();
      final count = contactPhones.isEmpty ? 1 : contactPhones.length;
      for (var index = 0; index < count; index++) {
        _addContactControllers(
          name: index < contactNames.length ? contactNames[index] : '',
          phone: index < contactPhones.length ? contactPhones[index] : '',
          relationship: index < contactRelationships.length
              ? contactRelationships[index]
              : '',
        );
      }
    });
  }

  List<String> _splitItems(String value) {
    return value
        .split(RegExp(r'[,;\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  void _disposeControllers(List<TextEditingController> controllers) {
    for (final controller in controllers) {
      controller.dispose();
    }
    controllers.clear();
  }

  void _resetControllers(
    List<TextEditingController> controllers,
    List<String> values,
  ) {
    _disposeControllers(controllers);
    for (final value in values) {
      controllers.add(TextEditingController(text: value));
    }
  }

  void _clearContactControllers() {
    for (final controller in _contactNameCtrls) {
      controller.dispose();
    }
    for (final controller in _contactPhoneCtrls) {
      controller.dispose();
    }
    for (final controller in _contactRelationshipCtrls) {
      controller.dispose();
    }
    _contactNameCtrls.clear();
    _contactPhoneCtrls.clear();
    _contactRelationshipCtrls.clear();
  }

  void _addContactControllers({
    String name = '',
    String phone = '',
    String relationship = '',
  }) {
    _contactNameCtrls.add(TextEditingController(text: name));
    _contactPhoneCtrls.add(TextEditingController(text: phone));
    _contactRelationshipCtrls.add(TextEditingController(text: relationship));
  }

  String _cleanPhoneNumber(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return '';
    final hasLeadingPlus = trimmed.startsWith('+');
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return '';
    return hasLeadingPlus ? '+$digitsOnly' : digitsOnly;
  }

  Future<void> _saveData() async {
    final contactNames = <String>[];
    final contactPhones = <String>[];
    final contactRelationships = <String>[];
    final allergies = _cleanControllerItems(_allergyCtrls);
    final medications = _cleanControllerItems(_medicationCtrls);

    for (var index = 0; index < _contactPhoneCtrls.length; index++) {
      final phone = _cleanPhoneNumber(_contactPhoneCtrls[index].text);
      final name = _contactNameCtrls[index].text.trim();
      final relationship = _contactRelationshipCtrls[index].text.trim();
      if (phone.isEmpty && name.isEmpty) continue;
      if (phone.length < 7) {
        _showSnackBar(
          'Enter a valid phone number for emergency contact ${index + 1}.',
        );
        return;
      }
      contactNames.add(name);
      contactPhones.add(phone);
      contactRelationships.add(relationship);
    }

    if (contactPhones.isEmpty) {
      _showSnackBar('Add at least one emergency contact.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', _nameCtrl.text.trim());
    await prefs.setString('photo_url', _photoUrlCtrl.text.trim());
    await prefs.setString('age', _ageCtrl.text.trim());
    await prefs.setString('blood', _bloodCtrl.text.trim());
    await prefs.setString('address', _addressCtrl.text.trim());
    await prefs.setString('conditions', _conditionsCtrl.text.trim());
    await prefs.setString('medications', medications.join('; '));
    await prefs.setString(
      'preferred_hospital',
      _preferredHospitalCtrl.text.trim(),
    );
    await prefs.setString('note', _noteCtrl.text.trim());
    await prefs.setString('critical_warning', _criticalWarningCtrl.text.trim());
    await prefs.setStringList('allergy_items', allergies);
    await prefs.setStringList('medication_items', medications);
    await prefs.setStringList('contact_names', contactNames);
    await prefs.setStringList('contact_phones', contactPhones);
    await prefs.setStringList('contact_relationships', contactRelationships);
    await prefs.setString('contact', contactPhones.first);

    if (!mounted) return;
    setState(() {
      _isEditing = false;
    });
    _showSnackBar('Medical ID saved locally.', color: Colors.green);
  }

  List<String> _cleanControllerItems(List<TextEditingController> controllers) {
    return controllers
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  void _showSnackBar(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  void _addContact() {
    setState(() {
      _addContactControllers();
    });
  }

  void _removeContact(int index) {
    if (_contactPhoneCtrls.length == 1) {
      _showSnackBar('Keep at least one emergency contact.');
      return;
    }

    setState(() {
      _contactNameCtrls.removeAt(index).dispose();
      _contactPhoneCtrls.removeAt(index).dispose();
      _contactRelationshipCtrls.removeAt(index).dispose();
    });
  }

  void _addAllergy() {
    setState(() {
      _allergyCtrls.add(TextEditingController());
    });
  }

  void _addMedication() {
    setState(() {
      _medicationCtrls.add(TextEditingController());
    });
  }

  void _removeListItem(List<TextEditingController> controllers, int index) {
    if (controllers.length == 1) {
      controllers[index].clear();
      return;
    }
    setState(() {
      controllers.removeAt(index).dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical ID'),
        actions: [
          IconButton(
            tooltip: 'Emergency view',
            icon: const Icon(Icons.visibility),
            onPressed: _showEmergencyView,
          ),
          IconButton(
            tooltip: 'Copy Medical ID',
            icon: const Icon(Icons.copy),
            onPressed: _copyMedicalId,
          ),
          IconButton(
            tooltip: 'Medical ID QR',
            icon: const Icon(Icons.qr_code_2),
            onPressed: _showMedicalIdQr,
          ),
          IconButton(
            tooltip: _isEditing ? 'Save' : 'Edit',
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _saveData();
              } else {
                setState(() => _isEditing = true);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: Colors.red,
              backgroundImage: _profileImageProvider(),
              child: _profileImageProvider() == null
                  ? const Icon(Icons.person, size: 50, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: 'Personal',
              children: [
                _buildField('Full Name', _nameCtrl, Icons.person),
                _buildPhotoField(),
                _buildField(
                  'Age',
                  _ageCtrl,
                  Icons.cake,
                  keyboardType: TextInputType.number,
                ),
                _buildBloodTypeField(),
                _buildField('Address', _addressCtrl, Icons.home, maxLines: 2),
              ],
            ),
            const SizedBox(height: 12),
            _buildSection(
              title: 'Medical',
              children: [
                _buildField(
                  'Critical Warning',
                  _criticalWarningCtrl,
                  Icons.priority_high,
                  maxLines: 2,
                ),
                _buildField(
                  'Known Conditions',
                  _conditionsCtrl,
                  Icons.monitor_heart,
                  maxLines: 2,
                ),
                _buildStructuredList(
                  title: 'Allergies',
                  controllers: _allergyCtrls,
                  icon: Icons.warning_amber,
                  onAdd: _addAllergy,
                ),
                _buildStructuredList(
                  title: 'Current Medications',
                  controllers: _medicationCtrls,
                  icon: Icons.medication,
                  onAdd: _addMedication,
                ),
                _buildField(
                  'Preferred Hospital',
                  _preferredHospitalCtrl,
                  Icons.local_hospital,
                ),
                _buildField(
                  'Additional Notes',
                  _noteCtrl,
                  Icons.note,
                  maxLines: 2,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildContactsSection(),
            const SizedBox(height: 20),
            const Text(
              'This information is saved only on your device and can be used without internet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const Divider(),
              children[index],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactsSection() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Emergency Contacts',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    tooltip: 'Pick from phone contacts',
                    icon: const Icon(Icons.contacts),
                    onPressed: _pickPhoneContact,
                  ),
                if (_isEditing)
                  IconButton(
                    tooltip: 'Add contact',
                    icon: const Icon(Icons.add),
                    onPressed: _addContact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < _contactPhoneCtrls.length; index++) ...[
              if (index > 0) const Divider(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildRelationshipField(index),
                        _buildField(
                          'Contact Name',
                          _contactNameCtrls[index],
                          Icons.badge,
                        ),
                        _buildField(
                          'Phone Number',
                          _contactPhoneCtrls[index],
                          Icons.contact_phone,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                  ),
                  if (_isEditing)
                    IconButton(
                      tooltip: 'Remove contact',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeContact(index),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      enabled: _isEditing,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.red),
        border: _isEditing ? const OutlineInputBorder() : InputBorder.none,
      ),
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildRelationshipField(int index) {
    if (!_isEditing) {
      return _buildField(
        'Relationship',
        _contactRelationshipCtrls[index],
        Icons.family_restroom,
      );
    }

    final value =
        _relationships.contains(_contactRelationshipCtrls[index].text.trim())
        ? _contactRelationshipCtrls[index].text.trim()
        : 'Other';

    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Relationship',
        prefixIcon: Icon(Icons.family_restroom, color: Colors.red),
        border: OutlineInputBorder(),
      ),
      items: _relationships.map((relationship) {
        return DropdownMenuItem(
          value: relationship,
          child: Text(
            relationship.isEmpty ? 'Select relationship' : relationship,
          ),
        );
      }).toList(),
      onChanged: (value) {
        _contactRelationshipCtrls[index].text = value ?? '';
      },
    );
  }

  Widget _buildStructuredList({
    required String title,
    required List<TextEditingController> controllers,
    required IconData icon,
    required VoidCallback onAdd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (_isEditing)
              IconButton(
                tooltip: 'Add $title',
                icon: const Icon(Icons.add),
                onPressed: onAdd,
              ),
          ],
        ),
        for (var index = 0; index < controllers.length; index++)
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controllers[index],
                    enabled: _isEditing,
                    decoration: InputDecoration(
                      labelText: '$title ${index + 1}',
                      border: _isEditing
                          ? const OutlineInputBorder()
                          : InputBorder.none,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _removeListItem(controllers, index),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBloodTypeField() {
    if (!_isEditing) {
      return _buildField('Blood Type', _bloodCtrl, Icons.bloodtype);
    }

    final value = _bloodTypes.contains(_bloodCtrl.text.trim())
        ? _bloodCtrl.text.trim()
        : '';

    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Blood Type',
        prefixIcon: Icon(Icons.bloodtype, color: Colors.red),
        border: OutlineInputBorder(),
      ),
      items: _bloodTypes.map((bloodType) {
        return DropdownMenuItem(
          value: bloodType,
          child: Text(bloodType.isEmpty ? 'Select blood type' : bloodType),
        );
      }).toList(),
      onChanged: (value) {
        _bloodCtrl.text = value ?? '';
      },
    );
  }

  Widget _buildPhotoField() {
    return Column(
      children: [
        TextField(
          controller: _photoUrlCtrl,
          enabled: _isEditing,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: 'Photo URL or local path',
            prefixIcon: const Icon(Icons.photo_camera, color: Colors.red),
            border: _isEditing ? const OutlineInputBorder() : InputBorder.none,
          ),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        if (_isEditing)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text('Choose photo'),
              onPressed: _pickProfilePhoto,
            ),
          ),
      ],
    );
  }

  ImageProvider? _profileImageProvider() {
    final photoValue = _photoUrlCtrl.text.trim();
    if (photoValue.startsWith('http')) {
      return NetworkImage(photoValue);
    }
    if (photoValue.isNotEmpty && File(photoValue).existsSync()) {
      return FileImage(File(photoValue));
    }
    return null;
  }

  Future<void> _pickProfilePhoto() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() {
      _photoUrlCtrl.text = image.path;
    });
  }

  Future<void> _pickPhoneContact() async {
    try {
      final permission = await FlutterContacts.permissions.request(
        PermissionType.read,
      );
      if (permission != PermissionStatus.granted &&
          permission != PermissionStatus.limited) {
        _showSnackBar('Contacts permission was not granted.');
        return;
      }

      final contactId = await FlutterContacts.native.showPicker();
      if (contactId == null) return;

      final fullContact = await FlutterContacts.get(
        contactId,
        properties: {ContactProperty.name, ContactProperty.phone},
      );
      final phone = fullContact?.phones.isNotEmpty == true
          ? fullContact!.phones.first.number
          : '';
      if (phone.trim().isEmpty) {
        _showSnackBar('Selected contact has no phone number.');
        return;
      }

      setState(() {
        final emptyIndex = _contactPhoneCtrls.indexWhere((controller) {
          return controller.text.trim().isEmpty;
        });
        final index = emptyIndex == -1 ? _contactPhoneCtrls.length : emptyIndex;
        if (emptyIndex == -1) {
          _addContactControllers();
        }
        _contactNameCtrls[index].text = fullContact?.displayName ?? '';
        _contactPhoneCtrls[index].text = phone;
      });
    } on PlatformException {
      _showSnackBar(
        'Phone contact picker is available on Android/iOS devices.',
      );
    }
  }

  String _medicalIdText() {
    final contacts = <String>[];
    for (var index = 0; index < _contactPhoneCtrls.length; index++) {
      final name = _contactNameCtrls[index].text.trim();
      final phone = _contactPhoneCtrls[index].text.trim();
      final relationship = _contactRelationshipCtrls[index].text.trim();
      if (name.isEmpty && phone.isEmpty) continue;
      final label = name.isEmpty ? phone : '$name: $phone';
      contacts.add(relationship.isEmpty ? label : '$relationship - $label');
    }
    final allergies = _cleanControllerItems(_allergyCtrls);
    final medications = _cleanControllerItems(_medicationCtrls);

    return [
      'MEDICAL ID',
      if (_criticalWarningCtrl.text.trim().isNotEmpty)
        'CRITICAL WARNING: ${_criticalWarningCtrl.text.trim()}',
      if (_nameCtrl.text.trim().isNotEmpty) 'Name: ${_nameCtrl.text.trim()}',
      if (_ageCtrl.text.trim().isNotEmpty) 'Age: ${_ageCtrl.text.trim()}',
      if (_bloodCtrl.text.trim().isNotEmpty)
        'Blood type: ${_bloodCtrl.text.trim()}',
      if (_addressCtrl.text.trim().isNotEmpty)
        'Address: ${_addressCtrl.text.trim()}',
      if (_conditionsCtrl.text.trim().isNotEmpty)
        'Known conditions: ${_conditionsCtrl.text.trim()}',
      if (allergies.isNotEmpty) 'Allergies: ${allergies.join('; ')}',
      if (medications.isNotEmpty)
        'Current medications: ${medications.join('; ')}',
      if (_preferredHospitalCtrl.text.trim().isNotEmpty)
        'Preferred hospital: ${_preferredHospitalCtrl.text.trim()}',
      if (_noteCtrl.text.trim().isNotEmpty) 'Notes: ${_noteCtrl.text.trim()}',
      if (contacts.isNotEmpty) 'Emergency contacts: ${contacts.join('; ')}',
    ].join('\n');
  }

  Future<void> _copyMedicalId() async {
    await Clipboard.setData(ClipboardData(text: _medicalIdText()));
    _showSnackBar('Medical ID copied.');
  }

  void _showMedicalIdQr() {
    final data = _medicalIdText();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Medical ID QR'),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(
                  data: data,
                  size: 240,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Responder can scan this to view your Medical ID details.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showEmergencyView() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency Medical ID',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_criticalWarningCtrl.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'CRITICAL WARNING: ${_criticalWarningCtrl.text.trim()}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SelectableText(
                  _medicalIdText(),
                  style: const TextStyle(fontSize: 20, height: 1.45),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Medical ID'),
                    onPressed: _copyMedicalId,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
