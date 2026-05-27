import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controllers/admin_session_controller.dart';
import '../data/mock_admin_data.dart';
import 'admin_login_page.dart';
import 'complaints_page.dart';
import 'pending_verifications_page.dart';
import 'telemetry_page.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  ADMIN PANEL — owner-only dashboard.
//  NEVER mounted into the BottomNavigationBar. Reachable only via:
//    Profile → long-press app version badge → passcode → AdminLoginPage.
//  Decoupled from cart / checkout / marketplace — pure read of admin module.
// ═══════════════════════════════════════════════════════════════════════════════

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  // Defensive: re-check on build in case status changes while the page is up.
  void _refresh() => setState(() {});

  Future<void> _signOut() async {
    await AdminSessionController.ensure().signOut();
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // Web deep-link entry: replace with the login screen so the user
      // doesn't land on an empty stack.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminLoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = PendingVerificationProvider.pendingCount();
    final openComplaints = ComplaintProvider.openCount();
    final adminEmail = AdminSessionController.ensure().adminEmail.value;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Row(children: [
          Icon(Icons.admin_panel_settings_rounded,
              size: 18.sp, color: Colors.amber.shade300),
          SizedBox(width: 8.w),
          Text(
            'admin_panel_title'.tr,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ]),
        actions: [
          if (adminEmail.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: Center(
                child: Text(
                  adminEmail,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'admin_sign_out_tooltip'.tr,
            icon: const Icon(Icons.logout_rounded, size: 18),
            onPressed: _signOut,
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, c) {
        // Responsive: ≥1100 px gets two columns (verifications + complaints
        // side by side); ≥700 px gets a centered max-width column so a
        // desktop browser doesn't stretch the form full-width; below that
        // is the mobile single-column layout.
        if (c.maxWidth >= 1100) {
          return _buildDesktopWide(pending, openComplaints);
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _buildSingleColumn(pending, openComplaints),
          ),
        );
      }),
    );
  }

  Widget _buildSingleColumn(int pending, int openComplaints) {
    return ListView(
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 24.h),
      children: [
        _SummaryRow(pending: pending, complaints: openComplaints),
        SizedBox(height: 14.h),
        _AdminTile(
          icon: Icons.verified_user_rounded,
          color: const Color(0xFF1976D2),
          title: 'admin_tile_verif_title'.tr,
          subtitle: 'admin_tile_verif_sub'.tr,
          badge: pending > 0 ? '$pending' : null,
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const PendingVerificationsPage()));
            _refresh();
          },
        ),
        SizedBox(height: 10.h),
        _AdminTile(
          icon: Icons.report_gmailerrorred_rounded,
          color: const Color(0xFFD32F2F),
          title: 'admin_tile_complaints_title'.tr,
          subtitle: 'admin_tile_complaints_sub'.tr,
          badge: openComplaints > 0 ? '$openComplaints' : null,
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ComplaintsPage()));
            _refresh();
          },
        ),
        SizedBox(height: 10.h),
        _AdminTile(
          icon: Icons.insights_rounded,
          color: const Color(0xFF6D28D9),
          title: 'admin_tile_telemetry_title'.tr,
          subtitle: 'admin_tile_telemetry_sub'.tr,
          badge: 'BETA',
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const TelemetryPage()));
            _refresh();
          },
        ),
        SizedBox(height: 18.h),
        _rbacFooter(),
      ],
    );
  }

  Widget _buildDesktopWide(int pending, int openComplaints) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Get.find<AdminSessionController>().adminEmail.value.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Welcome back, ${Get.find<AdminSessionController>().adminEmail.value}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
          _SummaryRow(pending: pending, complaints: openComplaints),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DesktopColumn(
                    title: 'admin_tile_verif_sub'.tr,
                    color: const Color(0xFF1976D2),
                    badge: pending,
                    child: const PendingVerificationsPage(embedded: true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DesktopColumn(
                    title: 'admin_tile_complaints_sub'.tr,
                    color: const Color(0xFFD32F2F),
                    badge: openComplaints,
                    child: const ComplaintsPage(embedded: true),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _rbacFooter(),
        ],
      ),
    );
  }

  Widget _rbacFooter() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10.r),
        border:
            Border.all(color: Colors.amber.withOpacity(0.40), width: 1),
      ),
      child: Row(children: [
        Icon(Icons.shield_moon_rounded,
            size: 16.sp, color: Colors.amber.shade800),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            'admin_rbac_note'.tr,
            style: TextStyle(
              fontSize: 11.sp,
              color: const Color(0xFF92400E),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ]),
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
//  Desktop column wrapper — light header + scrollable child. Used on ≥1100px
//  screens to show Verifications + Complaints side-by-side without leaving
//  the panel.
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopColumn extends StatelessWidget {
  final String title;
  final Color color;
  final int badge;
  final Widget child;

  const _DesktopColumn({
    required this.title,
    required this.color,
    required this.badge,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(
                bottom: BorderSide(color: color.withOpacity(0.18)),
              ),
            ),
            child: Row(children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const Spacer(),
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ]),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final int pending;
  final int complaints;
  const _SummaryRow({required this.pending, required this.complaints});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: _statCard(
          label: 'admin_stat_pending'.tr,
          value: '$pending',
          color: const Color(0xFF1976D2),
          icon: Icons.hourglass_top_rounded,
        ),
      ),
      SizedBox(width: 10.w),
      Expanded(
        child: _statCard(
          label: 'admin_stat_complaints'.tr,
          value: '$complaints',
          color: const Color(0xFFD32F2F),
          icon: Icons.warning_amber_rounded,
        ),
      ),
    ]);
  }

  Widget _statCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.sp, color: color),
          SizedBox(height: 6.h),
          Text(value,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1F2937),
              )),
          Text(label,
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _AdminTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0x14000000)),
          ),
          child: Row(children: [
            Container(
              width: 42.w,
              height: 42.w,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: Center(child: Icon(icon, size: 20.sp, color: color)),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1F2937),
                      )),
                  SizedBox(height: 2.h),
                  Text(subtitle,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey.shade600,
                      )),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999.r),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            SizedBox(width: 4.w),
            Icon(Icons.chevron_right_rounded,
                size: 18.w, color: Colors.grey.shade500),
          ]),
        ),
      ),
    );
  }
}
