import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/helpers.dart';
import '../../core/constants.dart';
import '../../models/incident_model.dart';
import '../incident/presentation/incident_detail_screen.dart';

/// ResolvedIncidentsPanel — แท็บเหตุเสร็จแล้ว + Filter (วันที่/ประเภท/ระดับ/ค้นหา)
class ResolvedIncidentsPanel extends ConsumerStatefulWidget {
  const ResolvedIncidentsPanel({super.key});

  @override
  ConsumerState<ResolvedIncidentsPanel> createState() => _ResolvedIncidentsPanelState();
}

class _ResolvedIncidentsPanelState extends ConsumerState<ResolvedIncidentsPanel> {

  // Filter state
  DateTimeRange? _dateRange;
  String? _typeFilter;
  String? _priorityFilter;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _dateRange = null;
      _typeFilter = null;
      _priorityFilter = null;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  bool get _hasActiveFilters =>
      _dateRange != null || _typeFilter != null || _priorityFilter != null || _searchQuery.isNotEmpty;

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: _dateRange ?? DateTimeRange(
        start: now.subtract(const Duration(days: 30)),
        end: now,
      ),
      locale: const Locale('th'),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  List<Incident> _applyFilters(List<Incident> incidents) {
    return incidents.where((i) {
      // Date range filter
      if (_dateRange != null && i.createdAt != null) {
        final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
        final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59);
        if (i.createdAt!.isBefore(start) || i.createdAt!.isAfter(end)) return false;
      }

      // Type filter
      if (_typeFilter != null && i.type != _typeFilter) return false;

      // Priority filter
      if (_priorityFilter != null && i.priority != _priorityFilter) return false;

      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = i.title.toLowerCase().contains(q);
        final matchReporter = (i.reporterName ?? '').toLowerCase().contains(q);
        final matchResponder = (i.responderName ?? '').toLowerCase().contains(q);
        final matchDesc = i.description.toLowerCase().contains(q);
        if (!matchTitle && !matchReporter && !matchResponder && !matchDesc) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(incidentRepositoryProvider);

    return Column(
      children: [
        // === Filter Bar ===
        _buildFilterBar(),

        // === Incident List ===
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: repo.getIncidentsStreamByStatus([IncidentStatus.resolved]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('โหลดข้อมูลไม่สำเร็จ', style: TextStyle(color: Colors.red[700])),
                    ],
                  ),
                );
              }

              final allIncidents = (snapshot.hasData)
                  ? snapshot.data!.docs.map((doc) => Incident.fromFirestore(doc)).toList()
                  : <Incident>[];

              final filtered = _applyFilters(allIncidents);

              // Sort by resolvedAt descending
              filtered.sort((a, b) {
                final aTime = a.resolvedAt ?? a.updatedAt ?? a.createdAt ?? DateTime(2000);
                final bTime = b.resolvedAt ?? b.updatedAt ?? b.createdAt ?? DateTime(2000);
                return bTime.compareTo(aTime);
              });

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        _hasActiveFilters ? 'ไม่พบเหตุที่ตรงกับตัวกรอง' : 'ยังไม่มีเหตุที่เสร็จสิ้น',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      if (_hasActiveFilters) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.clear_all, size: 16),
                          label: const Text('ล้างตัวกรอง', style: TextStyle(fontSize: 12)),
                          onPressed: _clearFilters,
                        ),
                      ],
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // Count bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: Colors.green.shade50,
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'เหตุเสร็จสิ้น ${filtered.length} รายการ${_hasActiveFilters ? " (กรองแล้ว)" : ""}',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  // List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(4),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final incident = filtered[index];
                        return _buildResolvedCard(incident);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey.shade50,
      child: Column(
        children: [
          // Search bar
          SizedBox(
            height: 36,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: '🔍 ค้นหาชื่อเหตุ / ผู้แจ้ง...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),

          const SizedBox(height: 6),

          // Filter chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Date range
                _FilterChipButton(
                  icon: Icons.calendar_today,
                  label: _dateRange != null
                      ? '${_dateRange!.start.day}/${_dateRange!.start.month} - ${_dateRange!.end.day}/${_dateRange!.end.month}'
                      : 'วันที่',
                  isActive: _dateRange != null,
                  onTap: _pickDateRange,
                ),
                const SizedBox(width: 6),

                // Type filter
                _FilterDropdown(
                  icon: Icons.category,
                  label: 'ประเภท',
                  value: _typeFilter,
                  items: const {
                    'accident': 'อุบัติเหตุ',
                    'facility': 'สาธารณูปโภค',
                    'assistance': 'ขอความช่วยเหลือ',
                    'security': 'ความปลอดภัย',
                    'medical': 'การแพทย์',
                  },
                  onChanged: (v) => setState(() => _typeFilter = v),
                ),
                const SizedBox(width: 6),

                // Priority filter
                _FilterDropdown(
                  icon: Icons.priority_high,
                  label: 'ระดับ',
                  value: _priorityFilter,
                  items: const {
                    'CRITICAL': 'วิกฤต',
                    'HIGH': 'เร่งด่วน',
                    'MEDIUM': 'ปานกลาง',
                    'LOW': 'ทั่วไป',
                  },
                  onChanged: (v) => setState(() => _priorityFilter = v),
                ),

                // Clear all button
                if (_hasActiveFilters) ...[
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.clear_all, size: 14, color: Colors.red),
                    label: const Text('ล้าง', style: TextStyle(fontSize: 11, color: Colors.red)),
                    onPressed: _clearFilters,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResolvedCard(Incident incident) {
    final resolvedTime = incident.resolvedAt ?? incident.updatedAt;
    String resolvedStr = '';
    if (resolvedTime != null) {
      resolvedStr = '${resolvedTime.day}/${resolvedTime.month}/${resolvedTime.year} '
          '${resolvedTime.hour}:${resolvedTime.minute.toString().padLeft(2, '0')}';
    }

    // Calculate resolution time
    String durationStr = '';
    if (incident.createdAt != null && resolvedTime != null) {
      final duration = resolvedTime.difference(incident.createdAt!);
      if (duration.inHours > 0) {
        durationStr = '${duration.inHours} ชม. ${duration.inMinutes % 60} นาที';
      } else {
        durationStr = '${duration.inMinutes} นาที';
      }
    }

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IncidentDetailScreen(incidentId: incident.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header badges
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppHelpers.getPriorityColor(incident.priority),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      incident.priorityText,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'เสร็จสิ้น ✓',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    incident.typeText,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Title
              Text(
                incident.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              // Reporter + Responder
              if (incident.reporterName != null)
                Text('👤 ผู้แจ้ง: ${incident.reporterName}',
                    style: const TextStyle(fontSize: 11, color: Colors.black87)),
              if (incident.responderName != null && incident.responderName!.isNotEmpty)
                Text('🚑 ผู้รับเคส: ${incident.responderName}',
                    style: const TextStyle(fontSize: 11, color: Colors.teal)),

              const SizedBox(height: 4),

              // Times
              Text('📅 แจ้งเหตุ: ${incident.formattedTime}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
              if (resolvedStr.isNotEmpty)
                Text('✅ ปิดเคส: $resolvedStr',
                    style: TextStyle(fontSize: 10, color: Colors.green.shade700)),
              if (durationStr.isNotEmpty)
                Text('⏱ ใช้เวลา: $durationStr',
                    style: const TextStyle(fontSize: 10, color: Colors.blue)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filter Chip button widget
class _FilterChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? Colors.blue : Colors.grey.shade300,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? Colors.blue : Colors.grey),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(
              fontSize: 11,
              color: isActive ? Colors.blue : Colors.grey.shade700,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            )),
          ],
        ),
      ),
    );
  }
}

/// Filter Dropdown widget
class _FilterDropdown extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Map<String, String> items;
  final void Function(String?) onChanged;

  const _FilterDropdown({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      onSelected: (v) => onChanged(v == '__clear__' ? null : v),
      itemBuilder: (context) {
        return [
          if (value != null)
            const PopupMenuItem(
              value: '__clear__',
              child: Text('ทั้งหมด', style: TextStyle(fontSize: 12, color: Colors.red)),
            ),
          ...items.entries.map((e) => PopupMenuItem(
            value: e.key,
            child: Text(e.value, style: const TextStyle(fontSize: 12)),
          )),
        ];
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: value != null ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value != null ? Colors.blue : Colors.grey.shade300,
            width: value != null ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: value != null ? Colors.blue : Colors.grey),
            const SizedBox(width: 4),
            Text(
              value != null ? items[value] ?? label : label,
              style: TextStyle(
                fontSize: 11,
                color: value != null ? Colors.blue : Colors.grey.shade700,
                fontWeight: value != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 14, color: value != null ? Colors.blue : Colors.grey),
          ],
        ),
      ),
    );
  }
}
