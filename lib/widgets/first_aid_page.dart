import 'package:flutter/material.dart';

import '../first_aid_guide.dart';
import '../repositories/first_aid_repository.dart';
import 'first_aid_detail_page.dart';

class FirstAidPage extends StatefulWidget {
  final FirstAidRepository repository;
  final VoidCallback onCallEmergency;
  final VoidCallback onFindHospitals;

  const FirstAidPage({
    super.key,
    required this.repository,
    required this.onCallEmergency,
    required this.onFindHospitals,
  });

  @override
  State<FirstAidPage> createState() => _FirstAidPageState();
}

class _FirstAidPageState extends State<FirstAidPage> {
  late Future<List<FirstAidGuide>> _guidesFuture;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _guidesFuture = widget.repository.loadGuides();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FirstAidGuide>>(
      future: _guidesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _ErrorState(onRetry: _reload);
        }

        final allGuides = snapshot.data ?? const [];
        final guides = widget.repository.filterGuides(allGuides, _query);

        return Column(
          children: [
            _Header(
              searchController: _searchController,
              query: _query,
              onSearchChanged: (value) {
                setState(() => _query = value);
              },
              onClear: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
            Expanded(
              child: guides.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                      itemCount: guides.length,
                      itemBuilder: (context, index) {
                        final guide = guides[index];
                        return _GuideCard(
                          guide: guide,
                          onTap: () => _openGuide(guide),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _reload() {
    setState(() {
      _guidesFuture = widget.repository.loadGuides();
    });
  }

  void _openGuide(FirstAidGuide guide) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return FirstAidDetailPage(
            guide: guide,
            onCallEmergency: widget.onCallEmergency,
            onFindHospitals: () {
              Navigator.pop(context);
              widget.onFindHospitals();
            },
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClear;

  const _Header({
    required this.searchController,
    required this.query,
    required this.onSearchChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'First aid guides',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'General guidance only. Call 112 for serious or uncertain emergencies.',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search CPR, choking, burns, stroke...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: onClear,
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: onSearchChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final FirstAidGuide guide;
  final VoidCallback onTap;

  const _GuideCard({required this.guide, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: guide.callEmergencyNow
              ? Colors.red.shade50
              : Colors.teal.shade50,
          child: Icon(
            _iconForCategory(guide.category),
            color: guide.callEmergencyNow ? Colors.red : Colors.teal.shade800,
          ),
        ),
        title: Text(guide.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${guide.category} - ${guide.summary}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: guide.callEmergencyNow
            ? const Icon(Icons.priority_high, color: Colors.red)
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  IconData _iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'airway':
      case 'breathing':
        return Icons.air;
      case 'injury':
      case 'bites':
        return Icons.healing;
      case 'environment':
      case 'water':
        return Icons.thermostat;
      case 'life-threatening':
        return Icons.emergency;
      case 'medical':
      default:
        return Icons.medical_information;
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No first aid topics match your search.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              'First aid guides could not be loaded.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
