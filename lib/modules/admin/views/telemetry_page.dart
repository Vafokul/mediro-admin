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

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();
    if (widget.embedded) return body;
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
      body: body,
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
