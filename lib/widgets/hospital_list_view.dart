import 'package:flutter/material.dart';

import '../hospital.dart';

class HospitalListView extends StatelessWidget {
  final List<Hospital> hospitals;
  final int visibleHospitalCount;
  final bool Function(Hospital hospital) isFavorite;
  final bool Function(Hospital hospital) canCall;
  final ValueChanged<Hospital> onHospitalSelected;
  final ValueChanged<Hospital> onToggleFavorite;
  final ValueChanged<Hospital> onCall;
  final ValueChanged<Hospital> onDirections;
  final VoidCallback onRefreshLocation;
  final VoidCallback onShowMore;

  const HospitalListView({
    super.key,
    required this.hospitals,
    required this.visibleHospitalCount,
    required this.isFavorite,
    required this.canCall,
    required this.onHospitalSelected,
    required this.onToggleFavorite,
    required this.onCall,
    required this.onDirections,
    required this.onRefreshLocation,
    required this.onShowMore,
  });

  @override
  Widget build(BuildContext context) {
    if (hospitals.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          Icon(Icons.search_off, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Center(
            child: Text(
              "No hospitals match your current filters.",
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    final hasDistances = hospitals.any((hospital) {
      return hospital.distanceInMeters != null;
    });

    final visibleHospitals = hospitals.take(visibleHospitalCount).toList();
    final canShowMore = visibleHospitals.length < hospitals.length;

    return RefreshIndicator(
      onRefresh: () async => onRefreshLocation(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 144),
        itemCount:
            visibleHospitals.length +
            (canShowMore ? 1 : 0) +
            (hasDistances ? 0 : 1),
        itemBuilder: (context, index) {
          if (!hasDistances && index == 0) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_off, color: Colors.orange.shade900),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Location is off. You can still search hospitals and open directions.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: onRefreshLocation,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final hospitalIndex = hasDistances ? index : index - 1;

          if (hospitalIndex == visibleHospitals.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.expand_more),
                label: Text(
                  'Show more (${hospitals.length - visibleHospitals.length} remaining)',
                ),
                onPressed: onShowMore,
              ),
            );
          }

          final hospital = visibleHospitals[hospitalIndex];
          final favorite = isFavorite(hospital);

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 5),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onHospitalSelected(hospital),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.redAccent,
                          child: Icon(
                            Icons.local_hospital,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hospital.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${hospital.ward} - ${hospital.lga}, ${hospital.state}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: favorite
                              ? "Remove from saved hospitals"
                              : "Save hospital",
                          icon: Icon(
                            favorite ? Icons.star : Icons.star_border,
                            color: favorite
                                ? Colors.amber.shade700
                                : Colors.grey,
                          ),
                          onPressed: () => onToggleFavorite(hospital),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _InfoChip(
                          icon: Icons.near_me,
                          label: hospital.distanceText,
                        ),
                        _InfoChip(
                          icon: Icons.category_outlined,
                          label: hospital.facilityTypeText,
                        ),
                        _InfoChip(
                          icon: Icons.emergency_outlined,
                          label: hospital.operationStatusText,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.call),
                            label: const Text('Call'),
                            onPressed: canCall(hospital)
                                ? () => onCall(hospital)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.directions),
                            label: const Text('Directions'),
                            onPressed: () => onDirections(hospital),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.grey.shade700),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
