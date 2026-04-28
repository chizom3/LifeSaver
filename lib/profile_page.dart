import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
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
  final List<TextEditingController> _contactNameCtrls = [];
  final List<TextEditingController> _contactPhoneCtrls = [];
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
    for (final controller in _contactNameCtrls) {
      controller.dispose();
    }
    for (final controller in _contactPhoneCtrls) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final contactNames = prefs.getStringList('contact_names') ?? [];
    var contactPhones = prefs.getStringList('contact_phones') ?? [];

    final legacyContact = prefs.getString('contact') ?? '';
    if (contactPhones.isEmpty && legacyContact.trim().isNotEmpty) {
      contactPhones = [legacyContact];
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

      _clearContactControllers();
      final count = contactPhones.isEmpty ? 1 : contactPhones.length;
      for (var index = 0; index < count; index++) {
        _addContactControllers(
          name: index < contactNames.length ? contactNames[index] : '',
          phone: index < contactPhones.length ? contactPhones[index] : '',
        );
      }
    });
  }

  void _clearContactControllers() {
    for (final controller in _contactNameCtrls) {
      controller.dispose();
    }
    for (final controller in _contactPhoneCtrls) {
      controller.dispose();
    }
    _contactNameCtrls.clear();
    _contactPhoneCtrls.clear();
  }

  void _addContactControllers({String name = '', String phone = ''}) {
    _contactNameCtrls.add(TextEditingController(text: name));
    _contactPhoneCtrls.add(TextEditingController(text: phone));
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

    for (var index = 0; index < _contactPhoneCtrls.length; index++) {
      final phone = _cleanPhoneNumber(_contactPhoneCtrls[index].text);
      final name = _contactNameCtrls[index].text.trim();
      if (phone.isEmpty && name.isEmpty) continue;
      if (phone.length < 7) {
        _showSnackBar(
          'Enter a valid phone number for emergency contact ${index + 1}.',
        );
        return;
      }
      contactNames.add(name);
      contactPhones.add(phone);
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
    await prefs.setString('medications', _medicationsCtrl.text.trim());
    await prefs.setString(
      'preferred_hospital',
      _preferredHospitalCtrl.text.trim(),
    );
    await prefs.setString('note', _noteCtrl.text.trim());
    await prefs.setStringList('contact_names', contactNames);
    await prefs.setStringList('contact_phones', contactPhones);
    await prefs.setString('contact', contactPhones.first);

    if (!mounted) return;
    setState(() {
      _isEditing = false;
    });
    _showSnackBar('Medical ID saved locally.', color: Colors.green);
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
                  'Known Conditions',
                  _conditionsCtrl,
                  Icons.monitor_heart,
                  maxLines: 2,
                ),
                _buildField(
                  'Current Medications',
                  _medicationsCtrl,
                  Icons.medication,
                  maxLines: 2,
                ),
                _buildField(
                  'Preferred Hospital',
                  _preferredHospitalCtrl,
                  Icons.local_hospital,
                ),
                _buildField(
                  'Allergies / Notes',
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

  String _medicalIdText() {
    final contacts = <String>[];
    for (var index = 0; index < _contactPhoneCtrls.length; index++) {
      final name = _contactNameCtrls[index].text.trim();
      final phone = _contactPhoneCtrls[index].text.trim();
      if (name.isEmpty && phone.isEmpty) continue;
      contacts.add(name.isEmpty ? phone : '$name: $phone');
    }

    return [
      'MEDICAL ID',
      if (_nameCtrl.text.trim().isNotEmpty) 'Name: ${_nameCtrl.text.trim()}',
      if (_ageCtrl.text.trim().isNotEmpty) 'Age: ${_ageCtrl.text.trim()}',
      if (_bloodCtrl.text.trim().isNotEmpty)
        'Blood type: ${_bloodCtrl.text.trim()}',
      if (_addressCtrl.text.trim().isNotEmpty)
        'Address: ${_addressCtrl.text.trim()}',
      if (_conditionsCtrl.text.trim().isNotEmpty)
        'Known conditions: ${_conditionsCtrl.text.trim()}',
      if (_medicationsCtrl.text.trim().isNotEmpty)
        'Current medications: ${_medicationsCtrl.text.trim()}',
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
