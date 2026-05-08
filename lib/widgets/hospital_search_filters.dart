import 'package:flutter/material.dart';

class HospitalSearchFilters extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final List<String> states;
  final List<String> lgas;
  final String? selectedState;
  final String? selectedLga;
  final bool showFavoritesOnly;
  final int favoriteCount;
  final double? selectedRadiusKm;
  final String sortMode;
  final int resultCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStateChanged;
  final ValueChanged<String?> onLgaChanged;
  final ValueChanged<bool> onFavoritesChanged;
  final ValueChanged<double?> onRadiusChanged;
  final ValueChanged<String> onSortModeChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onClearFilters;

  const HospitalSearchFilters({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.states,
    required this.lgas,
    required this.selectedState,
    required this.selectedLga,
    required this.showFavoritesOnly,
    required this.favoriteCount,
    required this.selectedRadiusKm,
    required this.sortMode,
    required this.resultCount,
    required this.onSearchChanged,
    required this.onStateChanged,
    required this.onLgaChanged,
    required this.onFavoritesChanged,
    required this.onRadiusChanged,
    required this.onSortModeChanged,
    required this.onClearSearch,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search hospital, state, LGA, ward',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: onClearSearch,
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: onSearchChanged,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedState,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'State',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: states.map((state) {
                      return DropdownMenuItem(
                        value: state,
                        child: Text(state, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: onStateChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedLga,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'LGA',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: lgas.map((lga) {
                      return DropdownMenuItem(
                        value: lga,
                        child: Text(lga, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: onLgaChanged,
                  ),
                ),
                IconButton(
                  tooltip: 'Clear filters',
                  icon: const Icon(Icons.filter_alt_off),
                  visualDensity: VisualDensity.compact,
                  onPressed: onClearFilters,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                FilterChip(
                  avatar: Icon(
                    showFavoritesOnly ? Icons.star : Icons.star_border,
                    size: 16,
                  ),
                  label: Text('Saved ($favoriteCount)'),
                  selected: showFavoritesOnly,
                  visualDensity: VisualDensity.compact,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                  onSelected: onFavoritesChanged,
                ),
                const Spacer(),
                SegmentedButton<String>(
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: 'nearest',
                      icon: Icon(Icons.near_me, size: 16),
                      label: Text('Nearest'),
                    ),
                    ButtonSegment(
                      value: 'az',
                      icon: Icon(Icons.sort_by_alpha, size: 16),
                      label: Text('A-Z'),
                    ),
                  ],
                  selected: {sortMode},
                  onSelectionChanged: (selection) {
                    onSortModeChanged(selection.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Any'),
                      selected: selectedRadiusKm == null,
                      visualDensity: VisualDensity.compact,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                      onSelected: (_) => onRadiusChanged(null),
                    ),
                    for (final radius in const [5.0, 10.0, 25.0, 50.0]) ...[
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text('${radius.toStringAsFixed(0)} km'),
                        selected: selectedRadiusKm == radius,
                        visualDensity: VisualDensity.compact,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                        onSelected: (_) => onRadiusChanged(radius),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.local_hospital, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    resultCount == 1
                        ? '1 facility shown'
                        : '$resultCount facilities shown',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  sortMode == 'az' ? 'Sorted A-Z' : 'Nearest first',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
