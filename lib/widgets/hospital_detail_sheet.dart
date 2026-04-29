import 'package:flutter/material.dart';

import '../hospital.dart';
import '../services/hospital_verification_service.dart';

Future<void> showHospitalDetailSheet({
  required BuildContext context,
  required Hospital hospital,
  required bool isFavorite,
  required bool canCall,
  required String phoneText,
  required VoidCallback onToggleFavorite,
  required VoidCallback onCall,
  required VoidCallback onDirections,
  required VoidCallback onReportInfo,
  required HospitalVerificationStatus verificationStatus,
  required VoidCallback onMarkCorrect,
  required VoidCallback onMarkIncorrect,
}) {
  return showModalBottomSheet<void>(
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      hospital.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: isFavorite
                        ? 'Remove from saved hospitals'
                        : 'Save hospital',
                    icon: Icon(
                      isFavorite ? Icons.star : Icons.star_border,
                      color: isFavorite ? Colors.amber.shade700 : null,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onToggleFavorite();
                    },
                  ),
                ],
              ),
              if (isFavorite)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.amber.shade100),
                  ),
                  child: const Text(
                    'Saved hospital',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 8),
              _VerificationBadge(status: verificationStatus),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.near_me,
                label: 'Distance',
                value: hospital.distanceText,
              ),
              _DetailRow(
                icon: Icons.location_on,
                label: 'Ward',
                value: hospital.ward,
              ),
              _DetailRow(
                icon: Icons.business,
                label: 'Type',
                value: hospital.facilityTypeText,
              ),
              _DetailRow(
                icon: Icons.schedule,
                label: 'Status',
                value: hospital.operationStatusText,
              ),
              _DetailRow(
                icon: Icons.verified_user_outlined,
                label: 'License',
                value: hospital.licenseStatus,
              ),
              _DetailRow(
                icon: Icons.assignment_turned_in_outlined,
                label: 'Registration',
                value: hospital.registrationStatus,
              ),
              _DetailRow(
                icon: Icons.place_outlined,
                label: 'Address',
                value: hospital.physicalLocation,
              ),
              _DetailRow(icon: Icons.map, label: 'LGA', value: hospital.lga),
              _DetailRow(
                icon: Icons.public,
                label: 'State',
                value: hospital.state,
              ),
              _DetailRow(icon: Icons.phone, label: 'Phone', value: phoneText),
              _DetailRow(
                icon: Icons.pin_drop,
                label: 'Coordinates',
                value:
                    '${hospital.latitude.toStringAsFixed(5)}, ${hospital.longitude.toStringAsFixed(5)}',
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.call),
                      label: const Text('Call'),
                      onPressed: canCall ? onCall : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.directions),
                      label: const Text('Directions'),
                      onPressed: onDirections,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Info correct'),
                      onPressed: () {
                        Navigator.pop(context);
                        onMarkCorrect();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Info wrong'),
                      onPressed: () {
                        Navigator.pop(context);
                        onMarkIncorrect();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.report_outlined),
                  label: const Text('Report wrong info'),
                  onPressed: onReportInfo,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _VerificationBadge extends StatelessWidget {
  final HospitalVerificationStatus status;

  const _VerificationBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isReported = status.incorrectCount > status.correctCount;
    final color = isReported ? Colors.orange : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade100),
      ),
      child: Row(
        children: [
          Icon(
            isReported ? Icons.report_problem_outlined : Icons.verified,
            color: color.shade800,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${status.label}  •  Correct ${status.correctCount}  •  Reports ${status.incorrectCount}',
              style: TextStyle(
                color: color.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value.trim().isEmpty ? 'Not available' : value.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.redAccent),
          const SizedBox(width: 12),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
