import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../data/telemetry_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  TELEMETRY PAGE — admin-only view of beta diagnostics.
//
//  Three tabs:
//    1. Errors    — last 200 sanitized error events (FlutterError, platform,
//                   zoned, and flow_caught)
//    2. Flow      — 'buyurtma_open' / 'submit_success' / 'submit_invalid' /
//                   'order_completed' funnel, with a top-of-page conversion %
//    3. Feedback  — beta_feedback submissions (rating + tags + sanitized comment)
//
//  Source of truth = MockTelemetryStore (always-on in-memory mirror). Once the
//  Supabase tables are provisioned, swap the list builders to call
//  `Supabase.instance.client.from('...').select()` — UI signatures unchanged.
// ═══════════════════════════════════════════════════════════════════════════════

class TelemetryPage extends StatefulWidget {
  /// When true, render the body only (no Scaffold/AppBar). Used by the
  /// desktop wide layout if it embeds this page later.
  final bool embedded;
  const TelemetryPage({super.key, this.embedded = false});

  @override
  State<TelemetryPage> createState() => _TelemetryPageState();
}

class _TelemetryPageState extends State<TelemetryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  /// 'today' | '7d' | '30d' | 'all' — applied to all three tables when
  /// the desktop wide layout is active.
  String _range = 'all';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  /// Returns rows whose `_at` timestamp is within the active time range.
  List<Map<String, dynamic>> _filterByRange(List<Map<String, dynamic>> rows) {
    if (_range == 'all') return rows;
    final now = DateTime.now();
    final cutoff = switch (_range) {
      'today' => DateTime(now.year, now.month, now.day),
      '7d' => now.subtract(const Duration(days: 7)),
      '30d' => now.subtract(const Duration(days: 30)),
      _ => DateTime.fromMillisecondsSinceEpoch(0),
    };
    return rows.where((r) {
      final at = DateTime.tryParse((r['_at'] ?? '').toString());
      if (at == null) return false;
      return at.isAfter(cutoff);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return LayoutBuilder(builder: (context, c) {
        if (c.maxWidth >= 900) return _buildEmbeddedWide();
        return _buildBody();
      });
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          },
        ),
        title: Text(
          'tele_title'.tr,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800),
          tabs: const [
            Tab(icon: Icon(Icons.bug_report_outlined, size: 16), text: 'Errors'),
            Tab(icon: Icon(Icons.timeline_rounded, size: 16), text: 'Flow'),
            Tab(icon: Icon(Icons.reviews_outlined, size: 16), text: 'Feedback'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _FunnelHeader(),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [
              _ErrorsTab(),
              _FlowTab(),
              _FeedbackTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Desktop wide layout (embedded ≥900px) ────────────────────────────

  Widget _buildEmbeddedWide() {
    final errors = _filterByRange(MockTelemetryStore.errors());
    final flow = _filterByRange(MockTelemetryStore.flow());
    final feedback = _filterByRange(MockTelemetryStore.feedback());
    final funnel = MockTelemetryStore.buyurtmaFunnel();
    final feedbackAvg = feedback.isEmpty
        ? 0.0
        : feedback
                .map((r) => (r['ux_rating'] ?? 0) as int)
                .fold<int>(0, (a, b) => a + b) /
            feedback.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TelemetryToolbar(
          range: _range,
          onRangeChange: (r) => setState(() => _range = r),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: _KpiRow(
            errors: errors.length,
            flow: flow.length,
            conversion: funnel.conversionPct,
            feedbackCount: feedback.length,
            feedbackAvg: feedbackAvg,
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: const Color(0x14000000)),
          ),
          child: TabBar(
            controller: _tab,
            indicatorColor: const Color(0xFF6D28D9),
            indicatorWeight: 3,
            labelColor: const Color(0xFF1F2937),
            unselectedLabelColor: Colors.grey.shade600,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            tabs: const [
              Tab(
                  icon: Icon(Icons.bug_report_outlined, size: 16),
                  text: 'Errors'),
              Tab(
                  icon: Icon(Icons.timeline_rounded, size: 16),
                  text: 'Flow'),
              Tab(
                  icon: Icon(Icons.reviews_outlined, size: 16),
                  text: 'Feedback'),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border.all(color: const Color(0x14000000)),
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: TabBarView(
                controller: _tab,
                children: [
                  _ErrorsTable(rows: errors),
                  _FlowTable(rows: flow),
                  _FeedbackTable(rows: feedback),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Funnel header — Buyurtma berish open → submit conversion rate.
// ─────────────────────────────────────────────────────────────────────────────

class _FunnelHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final f = MockTelemetryStore.buyurtmaFunnel();
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 0),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.shopping_bag_outlined,
                size: 16.sp, color: Colors.amber.shade300),
            SizedBox(width: 6.w),
            Text(
              'tele_funnel_title'.tr,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '${f.conversionPct.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 14.sp,
                color: f.conversionPct >= 50
                    ? Colors.greenAccent.shade400
                    : Colors.amber.shade300,
                fontWeight: FontWeight.w800,
              ),
            ),
          ]),
          SizedBox(height: 8.h),
          Row(children: [
            _funnelCell('tele_funnel_open'.tr, f.opens, Colors.amber.shade300),
            SizedBox(width: 10.w),
            Icon(Icons.arrow_forward_rounded,
                color: Colors.white38, size: 14.sp),
            SizedBox(width: 10.w),
            _funnelCell('tele_funnel_submit'.tr, f.submits, Colors.greenAccent.shade400),
          ]),
        ],
      ),
    );
  }

  Widget _funnelCell(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10.5.sp,
                    color: Colors.white60,
                    fontWeight: FontWeight.w600)),
            Text('$value',
                style: TextStyle(
                    fontSize: 18.sp,
                    color: color,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tab bodies
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorsTab extends StatelessWidget {
  const _ErrorsTab();

  @override
  Widget build(BuildContext context) {
    final list = MockTelemetryStore.errors();
    if (list.isEmpty) return _EmptyTab(text: 'tele_empty_errors'.tr);
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 24.h),
      itemCount: list.length,
      separatorBuilder: (_, __) => SizedBox(height: 8.h),
      itemBuilder: (_, i) => _ErrorCard(row: list[i]),
    );
  }
}

class _FlowTab extends StatelessWidget {
  const _FlowTab();

  @override
  Widget build(BuildContext context) {
    final list = MockTelemetryStore.flow();
    if (list.isEmpty) return _EmptyTab(text: 'tele_empty_flow'.tr);
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 24.h),
      itemCount: list.length,
      separatorBuilder: (_, __) => SizedBox(height: 8.h),
      itemBuilder: (_, i) => _FlowCard(row: list[i]),
    );
  }
}

class _FeedbackTab extends StatelessWidget {
  const _FeedbackTab();

  @override
  Widget build(BuildContext context) {
    final list = MockTelemetryStore.feedback();
    if (list.isEmpty) return _EmptyTab(text: 'tele_empty_feedback'.tr);
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 24.h),
      itemCount: list.length,
      separatorBuilder: (_, __) => SizedBox(height: 8.h),
      itemBuilder: (_, i) => _FeedbackCard(row: list[i]),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final String text;
  const _EmptyTab({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.w),
        child: Text(text,
            style:
                TextStyle(fontSize: 13.sp, color: Colors.grey.shade600)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Cards
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _ErrorCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final at = _fmtAt(row['_at']);
    final type = (row['event_type'] ?? '').toString();
    final cls = (row['exception_class'] ?? '').toString();
    final msg = (row['message'] ?? '').toString();
    final route = (row['ui_route'] ?? '').toString();
    final digest = (row['stack_digest'] ?? '').toString();
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(type,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    color: const Color(0xFFD32F2F),
                    fontWeight: FontWeight.w800,
                  )),
            ),
            const Spacer(),
            Text(at,
                style: TextStyle(
                    fontSize: 10.5.sp, color: Colors.grey.shade500)),
          ]),
          SizedBox(height: 6.h),
          Text(
            cls.isEmpty ? '(no exception class)' : cls,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1F2937),
            ),
          ),
          if (msg.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(msg,
                style:
                    TextStyle(fontSize: 11.5.sp, color: Colors.grey.shade700)),
          ],
          SizedBox(height: 6.h),
          Wrap(spacing: 6.w, runSpacing: 4.h, children: [
            if (route.isNotEmpty) _miniChip(route, const Color(0xFF1976D2)),
            if (digest.isNotEmpty)
              _miniChip('digest: $digest', const Color(0xFF6D28D9)),
          ]),
        ],
      ),
    );
  }
}

class _FlowCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _FlowCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final at = _fmtAt(row['_at']);
    final ev = (row['event_id'] ?? '').toString();
    final payload = (row['payload'] as Map?) ?? const {};
    final color = ev.contains('success')
        ? const Color(0xFF2E7D32)
        : ev.contains('invalid')
            ? const Color(0xFFE65100)
            : const Color(0xFF1976D2);
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 8.w,
          height: 8.w,
          margin: EdgeInsets.only(top: 6.h, right: 8.w),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(ev,
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w800,
                        color: color,
                      )),
                ),
                Text(at,
                    style: TextStyle(
                        fontSize: 10.5.sp, color: Colors.grey.shade500)),
              ]),
              if (payload.isNotEmpty) ...[
                SizedBox(height: 4.h),
                Text(
                  payload.entries.map((e) => '${e.key}=${e.value}').join('  ·  '),
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey.shade700,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _FeedbackCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final at = _fmtAt(row['_at']);
    final rating = (row['ux_rating'] ?? 0) as int;
    final tags = (row['tags'] as List?) ?? const [];
    final comment = (row['comment'] ?? '').toString();
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ...List.generate(
                5,
                (i) => Icon(
                      i < rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 16.sp,
                      color: Colors.amber.shade600,
                    )),
            const Spacer(),
            Text(at,
                style:
                    TextStyle(fontSize: 10.5.sp, color: Colors.grey.shade500)),
          ]),
          if (tags.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 4.h,
              children: tags
                  .map((t) => _miniChip(t.toString(), const Color(0xFF6D28D9)))
                  .toList(),
            ),
          ],
          if (comment.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(comment,
                style:
                    TextStyle(fontSize: 12.sp, color: Colors.grey.shade800)),
          ],
        ],
      ),
    );
  }
}

Widget _miniChip(String label, Color color) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(8.r),
      border: Border.all(color: color.withOpacity(0.30)),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10.5.sp,
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

String _fmtAt(dynamic raw) {
  if (raw == null) return '';
  try {
    final dt = DateTime.parse(raw.toString());
    return DateFormat('HH:mm:ss').format(dt.toLocal());
  } catch (_) {
    return raw.toString();
  }
}

String _fmtFullAt(dynamic raw) {
  if (raw == null) return '';
  try {
    final dt = DateTime.parse(raw.toString()).toLocal();
    return DateFormat('MMM d, HH:mm:ss').format(dt);
  } catch (_) {
    return raw.toString();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  DESKTOP WIDE — toolbar, KPI row, sortable tables for the embedded ≥900px
//  layout. Mobile/standalone path still uses the original card list.
// ═══════════════════════════════════════════════════════════════════════════════

class _TelemetryToolbar extends StatelessWidget {
  final String range;
  final ValueChanged<String> onRangeChange;

  const _TelemetryToolbar({
    required this.range,
    required this.onRangeChange,
  });

  @override
  Widget build(BuildContext context) {
    final ranges = const [
      ('today', 'Today'),
      ('7d', '7 days'),
      ('30d', '30 days'),
      ('all', 'All'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0x14000000))),
      ),
      child: Row(children: [
        Icon(Icons.filter_alt_outlined,
            size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          'Time range:',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        Wrap(
          spacing: 6,
          children: ranges.map((r) {
            final active = range == r.$1;
            return Material(
              color: active ? const Color(0xFF6D28D9) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onRangeChange(r.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active
                          ? const Color(0xFF6D28D9)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    r.$2,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: active
                          ? Colors.white
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

class _KpiRow extends StatelessWidget {
  final int errors;
  final int flow;
  final double conversion;
  final int feedbackCount;
  final double feedbackAvg;

  const _KpiRow({
    required this.errors,
    required this.flow,
    required this.conversion,
    required this.feedbackCount,
    required this.feedbackAvg,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: _KpiCard(
          label: 'Errors',
          value: '$errors',
          icon: Icons.bug_report_outlined,
          color: const Color(0xFFD32F2F),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _KpiCard(
          label: 'Flow events',
          value: '$flow',
          icon: Icons.timeline_rounded,
          color: const Color(0xFF1976D2),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _KpiCard(
          label: 'Funnel conversion',
          value: '${conversion.toStringAsFixed(1)}%',
          icon: Icons.trending_up_rounded,
          color: conversion >= 50
              ? const Color(0xFF2E7D32)
              : const Color(0xFFE65100),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _KpiCard(
          label: 'Feedback ($feedbackCount)',
          value: feedbackCount == 0
              ? '—'
              : '${feedbackAvg.toStringAsFixed(1)} ★',
          icon: Icons.reviews_outlined,
          color: const Color(0xFF6D28D9),
        ),
      ),
    ]);
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Errors table ────────────────────────────────────────────────────────

class _ErrorsTable extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  const _ErrorsTable({required this.rows});
  @override
  State<_ErrorsTable> createState() => _ErrorsTableState();
}

class _ErrorsTableState extends State<_ErrorsTable> {
  int _sortIdx = 0;
  bool _asc = false;

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text('tele_empty_errors'.tr,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ),
      );
    }
    final rows = List<Map<String, dynamic>>.from(widget.rows);
    rows.sort((a, b) {
      int cmp;
      switch (_sortIdx) {
        case 1:
          cmp = (a['event_type'] ?? '')
              .toString()
              .compareTo((b['event_type'] ?? '').toString());
          break;
        case 2:
          cmp = (a['exception_class'] ?? '')
              .toString()
              .compareTo((b['exception_class'] ?? '').toString());
          break;
        case 3:
          cmp = (a['ui_route'] ?? '')
              .toString()
              .compareTo((b['ui_route'] ?? '').toString());
          break;
        case 0:
        default:
          cmp = (a['_at'] ?? '')
              .toString()
              .compareTo((b['_at'] ?? '').toString());
      }
      return _asc ? cmp : -cmp;
    });
    return SingleChildScrollView(
      child: DataTable(
        sortColumnIndex: _sortIdx,
        sortAscending: _asc,
        headingRowColor:
            WidgetStateProperty.all(const Color(0xFFF1F5F9)),
        headingTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFF334155),
          letterSpacing: 0.4,
        ),
        dataRowMinHeight: 48,
        dataRowMaxHeight: 64,
        columnSpacing: 18,
        horizontalMargin: 16,
        columns: [
          DataColumn(
              label: const Text('TIME'),
              onSort: (i, a) => setState(() {
                    _sortIdx = i;
                    _asc = a;
                  })),
          DataColumn(
              label: const Text('TYPE'),
              onSort: (i, a) => setState(() {
                    _sortIdx = i;
                    _asc = a;
                  })),
          DataColumn(
              label: const Text('EXCEPTION'),
              onSort: (i, a) => setState(() {
                    _sortIdx = i;
                    _asc = a;
                  })),
          DataColumn(
              label: const Text('ROUTE'),
              onSort: (i, a) => setState(() {
                    _sortIdx = i;
                    _asc = a;
                  })),
          const DataColumn(label: Text('MESSAGE')),
        ],
        rows: rows.map((r) {
          return DataRow(cells: [
            DataCell(Text(_fmtFullAt(r['_at']),
                style: TextStyle(
                    fontSize: 11.5, color: Colors.grey.shade600))),
            DataCell(Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                (r['event_type'] ?? '').toString(),
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFFD32F2F),
                  fontWeight: FontWeight.w800,
                ),
              ),
            )),
            DataCell(Text(
              (r['exception_class'] ?? '—').toString(),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700),
            )),
            DataCell(Text(
              (r['ui_route'] ?? '').toString(),
              style: TextStyle(
                fontSize: 11.5,
                color: const Color(0xFF1976D2),
                fontWeight: FontWeight.w600,
              ),
            )),
            DataCell(SizedBox(
              width: 320,
              child: Text(
                (r['message'] ?? '').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            )),
          ]);
        }).toList(),
      ),
    );
  }
}

// ─── Flow table ──────────────────────────────────────────────────────────

class _FlowTable extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  const _FlowTable({required this.rows});
  @override
  State<_FlowTable> createState() => _FlowTableState();
}

class _FlowTableState extends State<_FlowTable> {
  int _sortIdx = 0;
  bool _asc = false;

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text('tele_empty_flow'.tr,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ),
      );
    }
    final rows = List<Map<String, dynamic>>.from(widget.rows);
    rows.sort((a, b) {
      int cmp;
      switch (_sortIdx) {
        case 1:
          cmp = (a['event_id'] ?? '')
              .toString()
              .compareTo((b['event_id'] ?? '').toString());
          break;
        case 0:
        default:
          cmp = (a['_at'] ?? '')
              .toString()
              .compareTo((b['_at'] ?? '').toString());
      }
      return _asc ? cmp : -cmp;
    });
    return SingleChildScrollView(
      child: DataTable(
        sortColumnIndex: _sortIdx,
        sortAscending: _asc,
        headingRowColor:
            WidgetStateProperty.all(const Color(0xFFF1F5F9)),
        headingTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFF334155),
          letterSpacing: 0.4,
        ),
        dataRowMinHeight: 48,
        dataRowMaxHeight: 72,
        columnSpacing: 18,
        horizontalMargin: 16,
        columns: [
          DataColumn(
              label: const Text('TIME'),
              onSort: (i, a) => setState(() {
                    _sortIdx = i;
                    _asc = a;
                  })),
          DataColumn(
              label: const Text('EVENT'),
              onSort: (i, a) => setState(() {
                    _sortIdx = i;
                    _asc = a;
                  })),
          const DataColumn(label: Text('PAYLOAD')),
        ],
        rows: rows.map((r) {
          final ev = (r['event_id'] ?? '').toString();
          final color = ev.contains('success')
              ? const Color(0xFF2E7D32)
              : ev.contains('invalid')
                  ? const Color(0xFFE65100)
                  : const Color(0xFF1976D2);
          final payload = (r['payload'] as Map?) ?? const {};
          return DataRow(cells: [
            DataCell(Text(_fmtFullAt(r['_at']),
                style: TextStyle(
                    fontSize: 11.5, color: Colors.grey.shade600))),
            DataCell(Row(children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                ev,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ])),
            DataCell(SizedBox(
              width: 360,
              child: Text(
                payload.isEmpty
                    ? '—'
                    : payload.entries
                        .map((e) => '${e.key}=${e.value}')
                        .join('  ·  '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                ),
              ),
            )),
          ]);
        }).toList(),
      ),
    );
  }
}

// ─── Feedback table ──────────────────────────────────────────────────────

class _FeedbackTable extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  const _FeedbackTable({required this.rows});
  @override
  State<_FeedbackTable> createState() => _FeedbackTableState();
}

class _FeedbackTableState extends State<_FeedbackTable> {
  int _sortIdx = 0;
  bool _asc = false;

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text('tele_empty_feedback'.tr,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ),
      );
    }
    final rows = List<Map<String, dynamic>>.from(widget.rows);
    rows.sort((a, b) {
      int cmp;
      switch (_sortIdx) {
        case 1:
          cmp = ((a['ux_rating'] ?? 0) as int)
              .compareTo((b['ux_rating'] ?? 0) as int);
          break;
        case 0:
        default:
          cmp = (a['_at'] ?? '')
              .toString()
              .compareTo((b['_at'] ?? '').toString());
      }
      return _asc ? cmp : -cmp;
    });
    return SingleChildScrollView(
      child: DataTable(
        sortColumnIndex: _sortIdx,
        sortAscending: _asc,
        headingRowColor:
            WidgetStateProperty.all(const Color(0xFFF1F5F9)),
        headingTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFF334155),
          letterSpacing: 0.4,
        ),
        dataRowMinHeight: 48,
        dataRowMaxHeight: 72,
        columnSpacing: 18,
        horizontalMargin: 16,
        columns: [
          DataColumn(
              label: const Text('TIME'),
              onSort: (i, a) => setState(() {
                    _sortIdx = i;
                    _asc = a;
                  })),
          DataColumn(
              label: const Text('RATING'),
              numeric: true,
              onSort: (i, a) => setState(() {
                    _sortIdx = i;
                    _asc = a;
                  })),
          const DataColumn(label: Text('TAGS')),
          const DataColumn(label: Text('COMMENT')),
        ],
        rows: rows.map((r) {
          final rating = (r['ux_rating'] ?? 0) as int;
          final tags = (r['tags'] as List?) ?? const [];
          return DataRow(cells: [
            DataCell(Text(_fmtFullAt(r['_at']),
                style: TextStyle(
                    fontSize: 11.5, color: Colors.grey.shade600))),
            DataCell(Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: List.generate(
                5,
                (i) => Icon(
                  i < rating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 14,
                  color: Colors.amber.shade600,
                ),
              ),
            )),
            DataCell(SizedBox(
              width: 220,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: tags
                    .take(4)
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0x196D28D9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            t.toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF6D28D9),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            )),
            DataCell(SizedBox(
              width: 280,
              child: Text(
                (r['comment'] ?? '').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            )),
          ]);
        }).toList(),
      ),
    );
  }
}
