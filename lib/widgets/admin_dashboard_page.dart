import 'package:flutter/material.dart';

import '../hospital.dart';
import '../services/admin_auth_service.dart';
import '../services/hospital_verification_service.dart';
import '../services/hospital_update_service.dart';
import '../services/report_service.dart';

class AdminDashboardPage extends StatefulWidget {
  final AdminAuthService authService;
  final ReportService reportService;
  final HospitalVerificationService verificationService;
  final HospitalUpdateService updateService;

  const AdminDashboardPage({
    super.key,
    required this.authService,
    required this.reportService,
    required this.verificationService,
    required this.updateService,
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late Future<_AdminDashboardData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Add new hospital',
            icon: const Icon(Icons.add_business_outlined),
            onPressed: _showAddHospitalDialog,
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: FutureBuilder<_AdminDashboardData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data ?? _AdminDashboardData.empty();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryRow(data: data),
              const SizedBox(height: 16),
              Text(
                'Submitted facility reports',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (data.reports.isEmpty)
                const _EmptyAdminState()
              else
                for (var index = 0; index < data.reports.length; index++)
                  _ReportCard(
                    report: data.reports[index],
                    onCreateUpdate: () =>
                        _showUpdateDialog(data.reports[index]),
                    onCloseHospital: () => _closeHospital(data.reports[index]),
                    onDismiss: () => _dismissReport(index),
                  ),
              const SizedBox(height: 16),
              Text(
                'Hospital verification status',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (data.statuses.isEmpty)
                const Text('No user verification marks yet.')
              else
                for (final entry in data.statuses.entries)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        entry.value.incorrectCount > entry.value.correctCount
                            ? Icons.report_problem_outlined
                            : Icons.verified,
                        color:
                            entry.value.incorrectCount >
                                entry.value.correctCount
                            ? Colors.orange
                            : Colors.green,
                      ),
                      title: Text(entry.value.label),
                      subtitle: Text(
                        'Correct ${entry.value.correctCount} - Reports ${entry.value.incorrectCount}\n${entry.key}',
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Future<_AdminDashboardData> _loadData() async {
    final reports = await widget.reportService.pendingReports();
    final statuses = await widget.verificationService.allStatuses();
    return _AdminDashboardData(reports: reports, statuses: statuses);
  }

  Future<void> _createApprovedUpdate({
    required Hospital hospital,
    required HospitalUpdateAction action,
    int? reportIndex,
  }) async {
    await widget.updateService.saveApprovedUpdate(
      HospitalUpdate.fromHospital(hospital: hospital, action: action),
    );
    if (reportIndex != null) {
      await widget.reportService.removePendingReport(reportIndex);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Approved ${action.name} saved to Firebase.')),
    );
    setState(() => _dataFuture = _loadData());
  }

  Future<void> _closeHospital(FacilityReport report) async {
    final index = await _reportIndex(report);
    final hospital = report.toHospital();
    await _createApprovedUpdate(
      hospital: hospital,
      action: HospitalUpdateAction.close,
      reportIndex: index,
    );
  }

  Future<int?> _reportIndex(FacilityReport report) async {
    final reports = await widget.reportService.pendingReports();
    final index = reports.indexWhere((item) {
      return item.hospitalKey == report.hospitalKey &&
          item.createdAt.toIso8601String() ==
              report.createdAt.toIso8601String();
    });
    return index < 0 ? null : index;
  }

  Future<void> _showUpdateDialog(FacilityReport report) async {
    final hospital = await showDialog<Hospital>(
      context: context,
      builder: (context) => _HospitalUpdateDialog(
        title: 'Approve correction',
        initialHospital: report.toHospital(),
      ),
    );
    if (hospital == null) return;
    final index = await _reportIndex(report);
    await _createApprovedUpdate(
      hospital: hospital,
      action: HospitalUpdateAction.update,
      reportIndex: index,
    );
  }

  Future<void> _showAddHospitalDialog() async {
    final hospital = await showDialog<Hospital>(
      context: context,
      builder: (context) =>
          const _HospitalUpdateDialog(title: 'Add new hospital'),
    );
    if (hospital == null) return;
    await _createApprovedUpdate(
      hospital: hospital,
      action: HospitalUpdateAction.add,
    );
  }

  Future<void> _dismissReport(int index) async {
    await widget.reportService.removePendingReport(index);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Report dismissed.')));
    setState(() => _dataFuture = _loadData());
  }

  Future<void> _signOut() async {
    await widget.authService.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Admin signed out.')));
    Navigator.pop(context);
  }
}

class _AdminDashboardData {
  final List<FacilityReport> reports;
  final Map<String, HospitalVerificationStatus> statuses;

  const _AdminDashboardData({required this.reports, required this.statuses});

  factory _AdminDashboardData.empty() {
    return const _AdminDashboardData(reports: [], statuses: {});
  }
}

class _SummaryRow extends StatelessWidget {
  final _AdminDashboardData data;

  const _SummaryRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final reportedHospitals = data.statuses.values.where((status) {
      return status.incorrectCount > status.correctCount;
    }).length;

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Pending reports',
            value: '${data.reports.length}',
            icon: Icons.assignment_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            label: 'Reported hospitals',
            value: '$reportedHospitals',
            icon: Icons.report_problem_outlined,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: Colors.red, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final FacilityReport report;
  final VoidCallback onCreateUpdate;
  final VoidCallback onCloseHospital;
  final VoidCallback onDismiss;

  const _ReportCard({
    required this.report,
    required this.onCreateUpdate,
    required this.onCloseHospital,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.hospitalName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('${report.lga}, ${report.state}'),
            const SizedBox(height: 8),
            Text('Reason: ${report.reason}'),
            const SizedBox(height: 6),
            SelectableText('Key: ${report.hospitalKey}'),
            const SizedBox(height: 6),
            Text('Phone: ${report.phone}'),
            Text(
              'Coordinates: ${report.latitude.toStringAsFixed(5)}, ${report.longitude.toStringAsFixed(5)}',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('Dismiss'),
                    onPressed: onDismiss,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.block),
                    label: const Text('Close'),
                    onPressed: onCloseHospital,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Create Firebase update'),
                onPressed: onCreateUpdate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HospitalUpdateDialog extends StatefulWidget {
  final String title;
  final Hospital? initialHospital;

  const _HospitalUpdateDialog({required this.title, this.initialHospital});

  @override
  State<_HospitalUpdateDialog> createState() => _HospitalUpdateDialogState();
}

class _HospitalUpdateDialogState extends State<_HospitalUpdateDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _stateController;
  late final TextEditingController _lgaController;
  late final TextEditingController _wardController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _phoneController;
  late final TextEditingController _levelController;
  late final TextEditingController _ownershipController;
  late final TextEditingController _statusController;
  late final TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    final hospital = widget.initialHospital;
    _nameController = TextEditingController(text: hospital?.name ?? '');
    _stateController = TextEditingController(text: hospital?.state ?? '');
    _lgaController = TextEditingController(text: hospital?.lga ?? '');
    _wardController = TextEditingController(text: hospital?.ward ?? '');
    _latitudeController = TextEditingController(
      text: hospital == null ? '' : hospital.latitude.toString(),
    );
    _longitudeController = TextEditingController(
      text: hospital == null ? '' : hospital.longitude.toString(),
    );
    _phoneController = TextEditingController(
      text: hospital?.displayPhone ?? '',
    );
    _levelController = TextEditingController(
      text: hospital?.facilityLevel ?? '',
    );
    _ownershipController = TextEditingController(
      text: hospital?.ownership ?? '',
    );
    _statusController = TextEditingController(
      text: hospital?.operationStatus ?? '',
    );
    _addressController = TextEditingController(
      text: hospital?.physicalLocation ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stateController.dispose();
    _lgaController.dispose();
    _wardController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _phoneController.dispose();
    _levelController.dispose();
    _ownershipController.dispose();
    _statusController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_nameController, 'Hospital name'),
              _field(_stateController, 'State'),
              _field(_lgaController, 'LGA'),
              _field(_wardController, 'Ward'),
              Row(
                children: [
                  Expanded(child: _field(_latitudeController, 'Latitude')),
                  const SizedBox(width: 8),
                  Expanded(child: _field(_longitudeController, 'Longitude')),
                ],
              ),
              _field(_phoneController, 'Phone'),
              _field(_levelController, 'Facility level'),
              _field(_ownershipController, 'Ownership'),
              _field(_statusController, 'Operation status'),
              _field(_addressController, 'Address'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save update')),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  void _save() {
    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());
    if (_nameController.text.trim().isEmpty ||
        _stateController.text.trim().isEmpty ||
        _lgaController.text.trim().isEmpty ||
        latitude == null ||
        longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Name, state, LGA, latitude, and longitude are required.',
          ),
        ),
      );
      return;
    }

    final existing = widget.initialHospital;
    final generatedKey =
        existing?.hospitalKey ??
        [
          'firebase',
          _keyPart(_nameController.text),
          _keyPart(_stateController.text),
          _keyPart(_lgaController.text),
          latitude.toStringAsFixed(5),
          longitude.toStringAsFixed(5),
        ].join('|');

    Navigator.pop(
      context,
      Hospital(
        name: _nameController.text.trim(),
        state: _stateController.text.trim(),
        lga: _lgaController.text.trim(),
        ward: _wardController.text.trim(),
        latitude: latitude,
        longitude: longitude,
        phone: _phoneController.text.trim(),
        uniqueId: existing?.uniqueId ?? 'firebase',
        physicalLocation: _addressController.text.trim(),
        facilityLevel: _levelController.text.trim(),
        operationStatus: _statusController.text.trim(),
        ownership: _ownershipController.text.trim(),
        storedHospitalKey: generatedKey,
      ),
    );
  }

  String _keyPart(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}

class _EmptyAdminState extends StatelessWidget {
  const _EmptyAdminState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text('No pending facility reports.'),
      ),
    );
  }
}
