import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../controllers/admin_session_controller.dart';
import 'admin_login_page.dart';
import 'admin_panel_page.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  ADMIN ENTRY ROUTE — guard widget used by the `/admin` GetPage and the
//  in-app mobile entry. On every hit it re-verifies the Supabase session
//  against `profiles.role`; an admin whose role was revoked server-side
//  loses access on the very next navigation, satisfying the spec's
//  "Force Login" requirement.
//
//  Renders:
//    1. spinner during verification,
//    2. AdminPanelPage on success,
//    3. AdminLoginPage on failure / no session.
// ═══════════════════════════════════════════════════════════════════════════════

class AdminEntryRoute extends StatefulWidget {
  const AdminEntryRoute({super.key});

  @override
  State<AdminEntryRoute> createState() => _AdminEntryRouteState();
}

class _AdminEntryRouteState extends State<AdminEntryRoute> {
  late final Future<bool> _verification;

  @override
  void initState() {
    super.initState();
    _verification = AdminSessionController.ensure().verifyCurrentSession();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _verification,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.amber),
                  SizedBox(height: 14.h),
                  Text(
                    "Cloud orqali tekshirilmoqda...",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final ok = snap.data ?? false;
        return ok ? const AdminPanelPage() : const AdminLoginPage();
      },
    );
  }
}
