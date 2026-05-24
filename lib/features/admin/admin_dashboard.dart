import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/providers.dart';
import '../../core/constants.dart';
import '../auth/presentation/login_screen.dart';
import '../incident/presentation/incident_list_screen.dart';
import '../map/heatmap_screen.dart';
import 'user_management_screen.dart';

/// AdminDashboard — v3: #23 ปรับปรุง Stats + Rating overview
class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final repo = ref.watch(incidentRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("🔧 แผงควบคุมผู้ดูแล"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),

      body: FutureBuilder<List<int>>(
        future: Future.wait([
          repo.countIncidents(null),
          repo.countIncidents(IncidentStatus.newCase),
          repo.countIncidents(IncidentStatus.inProgress),
          repo.countIncidents(IncidentStatus.resolved),
        ]),

        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          int total = snapshot.data![0];
          int reported = snapshot.data![1];
          int inProgress = snapshot.data![2];
          int resolved = snapshot.data![3];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // === Stats Cards ===
                Row(
                  children: [
                    Expanded(child: _buildMiniStat("ทั้งหมด", total, Colors.blue)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMiniStat("เหตุใหม่", reported, Colors.red)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildMiniStat("กำลังดำเนินการ", inProgress, Colors.orange)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMiniStat("เสร็จสิ้น", resolved, Colors.green)),
                  ],
                ),

                const SizedBox(height: 24),

                // #23: Resolution Rate
                if (total > 0)
                  _buildResolutionRate(resolved, total),

                const SizedBox(height: 24),

                // === Pie Chart ===
                const Text(
                  "📊 สัดส่วนสถานะเหตุการณ์",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                if (total > 0)
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: [
                          if (reported > 0)
                            PieChartSectionData(
                              value: reported.toDouble(),
                              title: '$reported',
                              color: Colors.red,
                              radius: 50,
                              titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          if (inProgress > 0)
                            PieChartSectionData(
                              value: inProgress.toDouble(),
                              title: '$inProgress',
                              color: Colors.orange,
                              radius: 50,
                              titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          if (resolved > 0)
                            PieChartSectionData(
                              value: resolved.toDouble(),
                              title: '$resolved',
                              color: Colors.green,
                              radius: 50,
                              titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                        ],
                      ),
                    ),
                  ),

                if (total > 0) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    children: [
                      _buildLegend("เหตุใหม่", Colors.red),
                      _buildLegend("กำลังดำเนินการ", Colors.orange),
                      _buildLegend("เสร็จสิ้น", Colors.green),
                    ],
                  ),
                ],

                if (total == 0)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text("ยังไม่มีข้อมูลเหตุการณ์", style: TextStyle(color: Colors.grey)),
                    ),
                  ),

                const SizedBox(height: 24),

                // #23: Average Rating Section
                _buildRatingOverview(ref),

                const SizedBox(height: 24),

                // F24: Bar Chart by Incident Type
                _buildTypeBarChart(ref),

                const SizedBox(height: 24),

                // F24: Responder Performance
                _buildResponderPerformance(ref),

                const SizedBox(height: 24),

                // === Action Buttons ===
                const Text(
                  "📋 เมนูจัดการ",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.list_alt),
                    label: const Text("ดูเหตุทั้งหมด"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const IncidentListScreen(),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.people),
                    label: const Text("จัดการผู้ใช้ / มอบสิทธิ์"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UserManagementScreen(),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // F28: Heatmap
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.map),
                    label: const Text("🔥 แผนที่ความเสี่ยง"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HeatmapScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// #23: Resolution Rate Card
  Widget _buildResolutionRate(int resolved, int total) {
    final rate = total > 0 ? (resolved / total * 100) : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("📈 อัตราการแก้ไขเสร็จ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: rate / 100,
                minHeight: 12,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  rate > 70 ? Colors.green : rate > 40 ? Colors.orange : Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "${rate.toStringAsFixed(1)}% ($resolved/$total)",
              style: TextStyle(fontSize: 14, color: rate > 70 ? Colors.green : Colors.orange),
            ),
          ],
        ),
      ),
    );
  }

  /// #23: Average Rating Overview
  Widget _buildRatingOverview(WidgetRef ref) {
    return FutureBuilder<QuerySnapshot>(
      future: ref.read(firestoreProvider)
          .collection('incidents')
          .where('rating', isGreaterThan: 0)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;
        double totalRating = 0;
        final counts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
        for (final doc in docs) {
          final r = (doc.data() as Map<String, dynamic>)['rating'] as int;
          totalRating += r;
          counts[r] = (counts[r] ?? 0) + 1;
        }
        
        final mean = totalRating / docs.length;

        double varianceSum = 0;
        for (final doc in docs) {
          final r = (doc.data() as Map<String, dynamic>)['rating'] as int;
          varianceSum += (r - mean) * (r - mean);
        }
        final sd = docs.length > 1 ? math.sqrt(varianceSum / (docs.length - 1)) : 0.0;

        String qualityLabel;
        Color qualityColor;
        if (mean >= 4.50) {
          qualityLabel = "ดีเยี่ยม (Excellent)";
          qualityColor = Colors.green.shade700;
        } else if (mean >= 3.50) {
          qualityLabel = "ดี (Good)";
          qualityColor = Colors.green;
        } else if (mean >= 2.50) {
          qualityLabel = "ปานกลาง (Fair)";
          qualityColor = Colors.orange;
        } else if (mean >= 1.50) {
          qualityLabel = "พอใช้ (Poor)";
          qualityColor = Colors.redAccent;
        } else {
          qualityLabel = "ต้องปรับปรุง (Very Poor)";
          qualityColor = Colors.red.shade900;
        }

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics_outlined, color: Colors.indigo, size: 22),
                    SizedBox(width: 8),
                    Text(
                      "📊 ผลวิเคราะห์ความพึงพอใจ (UAT Stats)",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const Divider(height: 24),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Big Stats block
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                mean.toStringAsFixed(2),
                                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.indigo),
                              ),
                              const SizedBox(width: 4),
                              const Text("/ 5.00", style: TextStyle(fontSize: 14, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: qualityColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              qualityLabel,
                              style: TextStyle(fontSize: 12, color: qualityColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "ค่าเฉลี่ยรวม (Mean): X̅ = ${mean.toStringAsFixed(2)}",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "ส่วนเบี่ยงเบนมาตรฐาน: S.D. = ${sd.toStringAsFixed(2)}",
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "ขนาดกลุ่มตัวอย่าง: N = ${docs.length}",
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    
                    // Star histograms
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: List.generate(5, (index) {
                          final star = 5 - index;
                          final count = counts[star] ?? 0;
                          final ratio = docs.isNotEmpty ? count / docs.length : 0.0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Text("$star ⭐", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      minHeight: 8,
                                      backgroundColor: Colors.grey.shade100,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo.shade400),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 22,
                                  child: Text(
                                    "$count",
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniStat(String label, int value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  /// F24: Bar Chart — จำนวนเหตุแยกตาม type
  Widget _buildTypeBarChart(WidgetRef ref) {
    return FutureBuilder<QuerySnapshot>(
      future: ref.read(firestoreProvider).collection('incidents').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final typeCounts = <String, int>{};
        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final type = data['type'] as String? ?? 'unknown';
          typeCounts[type] = (typeCounts[type] ?? 0) + 1;
        }

        final typeLabels = {
          'security': '🛡️ ความปลอดภัย',
          'medical': '🏥 การแพทย์',
          'accident': '🚑 อุบัติเหตุ',
          'facility': '🏢 สิ่งอำนวยฯ',
          'assistance': '🤝 ช่วยเหลือ',
          'emergency': '🆘 SOS',
        };

        final typeColors = {
          'security': Colors.blue,
          'medical': Colors.red,
          'accident': Colors.orange,
          'facility': Colors.purple,
          'assistance': Colors.teal,
          'emergency': Colors.pink,
        };

        final entries = typeCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("📊 เหตุการณ์แยกตามประเภท", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (entries.first.value + 2).toDouble(),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final type = entries[group.x.toInt()].key;
                            return BarTooltipItem(
                              '${typeLabels[type] ?? type}\n${rod.toY.toInt()} เหตุ',
                              const TextStyle(color: Colors.white, fontSize: 12),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= entries.length) return const SizedBox.shrink();
                              final type = entries[value.toInt()].key;
                              return Text(
                                type.length > 4 ? '${type.substring(0, 4)}.' : type,
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              if (value == value.roundToDouble()) {
                                return Text('${value.toInt()}', style: const TextStyle(fontSize: 10));
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: true, drawVerticalLine: false),
                      borderData: FlBorderData(show: false),
                      barGroups: entries.asMap().entries.map((e) {
                        final color = typeColors[e.value.key] ?? Colors.grey;
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value.value.toDouble(),
                              color: color,
                              width: 20,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// F24: Responder Performance Table
  Widget _buildResponderPerformance(WidgetRef ref) {
    return FutureBuilder<QuerySnapshot>(
      future: ref.read(firestoreProvider).collection('incidents')
          .where('responderId', isNull: false).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        // รวบรวม stats ต่อ responder
        final Map<String, Map<String, dynamic>> responderStats = {};

        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final rid = data['responderId'] as String? ?? '';
          final rname = data['responderName'] as String? ?? rid;
          final status = data['status'] as String? ?? '';

          if (rid.isEmpty) continue;

          responderStats.putIfAbsent(rid, () => {
            'name': rname,
            'total': 0,
            'resolved': 0,
            'totalRating': 0,
            'ratedCount': 0,
          });

          responderStats[rid]!['total'] = (responderStats[rid]!['total'] as int) + 1;

          if (status == 'RESOLVED') {
            responderStats[rid]!['resolved'] = (responderStats[rid]!['resolved'] as int) + 1;
          }

          final rating = data['rating'] as int?;
          if (rating != null && rating > 0) {
            responderStats[rid]!['totalRating'] = (responderStats[rid]!['totalRating'] as int) + rating;
            responderStats[rid]!['ratedCount'] = (responderStats[rid]!['ratedCount'] as int) + 1;
          }
        }

        final entries = responderStats.entries.toList()
          ..sort((a, b) => (b.value['resolved'] as int).compareTo(a.value['resolved'] as int));

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("🏆 ผลงานผู้ตอบสนอง", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                ...entries.take(10).map((e) {
                  final stats = e.value;
                  final name = stats['name'] as String;
                  final total = stats['total'] as int;
                  final resolved = stats['resolved'] as int;
                  final ratedCount = stats['ratedCount'] as int;
                  final avgRating = ratedCount > 0
                      ? ((stats['totalRating'] as int) / ratedCount)
                      : 0.0;
                  final resolveRate = total > 0 ? (resolved / total * 100) : 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 16,
                          child: Icon(Icons.person, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(
                                'เคสทั้งหมด: $total  แก้ไขแล้ว: $resolved (${resolveRate.toStringAsFixed(0)}%)',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        if (ratedCount > 0) ...[
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          Text(avgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}