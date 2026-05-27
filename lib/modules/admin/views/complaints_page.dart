import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../data/mock_admin_data.dart';

class ComplaintsPage extends StatefulWidget {
  /// When true, render the body only (no Scaffold/AppBar) so the desktop
  /// wide layout can embed this page inside its column wrapper.
  final bool embedded;
  const ComplaintsPage({super.key, this.embedded = false});

  @override
  State<ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends State<ComplaintsPage> {
  void _resolve(Complaint c) {
    setState(() => ComplaintProvider.resolve(c.id));
    Get.snackbar(
      'cmp_admin_snack_resolved'.tr,
      'cmp_admin_snack_resolved_body'.tr.replaceAll('{name}', c.ustaName),
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFF198754),
      colorText: Colors.white,
      margin: EdgeInsets.all(12.w),
      borderRadius: 10,
      duration: const Duration(seconds: 3),
    );
  }

  void _dismiss(Complaint c) {
    setState(() => ComplaintProvider.dismiss(c.id));
    Get.snackbar(
      'cmp_admin_snack_rejected'.tr,
      'cmp_admin_snack_rejected_body'.tr,
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFFB45309),
      colorText: Colors.white,
      margin: EdgeInsets.all(12.w),
      borderRadius: 10,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = ComplaintProvider.all();
    final body = list.isEmpty
        ? Center(
            child: Padding(
              padding: EdgeInsets.all(28.w),
              child: Text('cmp_admin_empty'.tr,
                  style: TextStyle(
                      fontSize: 13.sp, color: Colors.grey.shade600)),
            ),
          )
        : ListView.separated(
            padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 24.h),
            itemCount: list.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (_, i) => _ComplaintCard(
              complaint: list[i],
              onResolve: _resolve,
              onDismiss: _dismiss,
            ),
          );
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
          'cmp_admin_title'.tr,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: body,
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  final Complaint complaint;
  final void Function(Complaint) onResolve;
  final void Function(Complaint) onDismiss;

  const _ComplaintCard({
    required this.complaint,
    required this.onResolve,
    required this.onDismiss,
  });

  ({Color bg, Color fg, String label}) _statusVisual(String s) {
    switch (s) {
      case 'under_review':
        return (
          bg: const Color(0xFFFFEBEE),
          fg: const Color(0xFFD32F2F),
          label: 'cmp_admin_status_review'.tr,
        );
      case 'open':
        return (
          bg: const Color(0xFFFFF3E0),
          fg: const Color(0xFFE65100),
          label: 'cmp_admin_status_open'.tr,
        );
      case 'resolved':
        return (
          bg: const Color(0xFFE8F5E9),
          fg: const Color(0xFF2E7D32),
          label: 'cmp_admin_status_resolved'.tr,
        );
      case 'dismissed':
        return (
          bg: const Color(0xFFECEFF1),
          fg: const Color(0xFF455A64),
          label: 'cmp_admin_status_dismissed'.tr,
        );
      default:
        return (
          bg: const Color(0xFFECEFF1),
          fg: const Color(0xFF455A64),
          label: s,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _statusVisual(complaint.status);
    final actionable =
        complaint.status == 'under_review' || complaint.status == 'open';
    final dateStr =
        DateFormat('d MMM, HH:mm').format(complaint.createdAt);

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    complaint.ustaName,
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '${complaint.clientLabel} · ${complaint.orderId}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: v.bg,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                v.label,
                style: TextStyle(
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w800,
                  color: v.fg,
                ),
              ),
            ),
          ]),
          SizedBox(height: 10.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  complaint.reason,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  complaint.comment,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          if (actionable) ...[
            SizedBox(height: 10.h),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onDismiss(complaint),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB45309),
                    side: const BorderSide(color: Color(0xFFB45309)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 9.h),
                  ),
                  child: Text('cmp_admin_btn_dismiss'.tr,
                      style: TextStyle(fontSize: 12.sp)),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => onResolve(complaint),
                  icon: const Icon(Icons.check_circle_outline_rounded,
                      size: 16),
                  label: Text('cmp_admin_btn_resolve'.tr,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                      )),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF198754),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 9.h),
                  ),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
