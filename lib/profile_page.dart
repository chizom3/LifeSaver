import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Controllers for text fields
  final _nameCtrl = TextEditingController();
  final _bloodCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Load saved data when page opens
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameCtrl.text = prefs.getString('name') ?? '';
      _bloodCtrl.text = prefs.getString('blood') ?? '';
      _contactCtrl.text = prefs.getString('contact') ?? '';
      _noteCtrl.text = prefs.getString('note') ?? '';
    });
  }

  // Save data to phone storage
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', _nameCtrl.text);
    await prefs.setString('blood', _bloodCtrl.text);
    await prefs.setString('contact', _contactCtrl.text);
    await prefs.setString('note', _noteCtrl.text);

    setState(() {
      _isEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Medical ID Saved Locally'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Medical ID"),
        actions: [
          IconButton(
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
            // Profile Icon
            const CircleAvatar(
              radius: 40,
              backgroundColor: Colors.red,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 20),

            // Info Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildField("Full Name", _nameCtrl, Icons.person),
                    const Divider(),
                    _buildField("Blood Type", _bloodCtrl, Icons.bloodtype),
                    const Divider(),
                    _buildField(
                      "Emergency Contact",
                      _contactCtrl,
                      Icons.contact_phone,
                    ),
                    const Divider(),
                    _buildField(
                      "Medical Notes (Allergies)",
                      _noteCtrl,
                      Icons.note,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              "This information is saved only on your device.\nIt is accessible without internet.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      enabled: _isEditing, // Only type when in 'Edit' mode
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.red),
        border: _isEditing ? const OutlineInputBorder() : InputBorder.none,
      ),
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }
}
