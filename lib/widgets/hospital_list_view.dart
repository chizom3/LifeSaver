import 'package:flutter/material.dart';

import '../hospital.dart';

class HospitalListView extends StatelessWidget {
  final List<Hospital> hospitals;
  final int visibleHospitalCount;
  final bool Function(Hospital hospital) isFavorite;
  final ValueChanged<Hospital> onHospitalSelected;
  final ValueChanged<Hospital> onToggleFavorite;
  final VoidCallback onRefreshLocation;
  final VoidCallback onShowMore;

  const HospitalListView({
    super.key,
    required this.hospitals,
    required this.visibleHospitalCount,
    required this.isFavorite,
    required this.onHospitalSelected,
    required this.onToggleFavorite,
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

    if (!hasDistances) {
      return RefreshIndicator(
        onRefresh: () async => onRefreshLocation(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Icon(Icons.location_off, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Center(
              child: Text(
                "Enable location to sort hospitals by distance.",
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    final visibleHospitals = hospitals.take(visibleHospitalCount).toList();
    final canShowMore = visibleHospitals.length < hospitals.length;

    return RefreshIndicator(
      onRefresh: () async => onRefreshLocation(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: visibleHospitals.length + (canShowMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == visibleHospitals.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.expand_more),
                label: Text(
                  'Show more (${hospitals.length - visibleHospitals.length} remaining)',
                ),
                onPressed: onShowMore,
              ),
            );
          }

          final hospital = visibleHospitals[index];
          final favorite = isFavorite(hospital);

          if (hospital.distanceInMeters == null) {
            return const SizedBox.shrink();
          }

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.redAccent,
                child: Icon(Icons.local_hospital, color: Colors.white),
              ),
              title: Text(
                hospital.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                "${hospital.ward} - ${hospital.lga}, ${hospital.state}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        hospital.distanceText,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: favorite
                        ? "Remove from saved hospitals"
                        : "Save hospital",
                    icon: Icon(
                      favorite ? Icons.star : Icons.star_border,
                      color: favorite ? Colors.amber.shade700 : Colors.grey,
                    ),
                    onPressed: () => onToggleFavorite(hospital),
                  ),
                ],
              ),
              onTap: () => onHospitalSelected(hospital),
            ),
          );
        },
      ),
    );
  }
}
