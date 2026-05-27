import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controllers/admin_session_controller.dart';
import 'admin_panel_page.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  ADMIN LOGIN — cloud-first force-login for the Admin Panel.
//
//  Primary path: Supabase email + password → profiles.role check.
//  Fallback   : demo passcode (debug builds only — kDebugMode-gated in the
//                controller).
//
//  Responsive: on a wide window (≥ 700 px) the form sits centered with a
//  bounded width so it doesn't stretch across the desktop browser. On mobile
//  it fills the screen.
// ═══════════════════════════════════════════════════════════════════════════════

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passcodeCtrl = TextEditingController();

  String? _error;
  bool _busy = false;
  bool _showDemoPanel = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitCloud() async {
    if (_busy) return;
    final email = _emailCtrl.text.trim();
    final pwd = _passwordCtrl.text;
    if (email.isEmpty || pwd.isEmpty) {
      setState(() => _error = 'login_err_creds_empty'.tr);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await AdminSessionController.ensure()
        .signInWithEmail(email: email, password: pwd);
    if (!mounted) return;
    if (err == null) {
      _gotoPanel();
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  void _submitDemo() {
    final ok = AdminSessionController.ensure()
        .unlockWithDemoPasscode(_passcodeCtrl.text);
    if (ok) {
      _gotoPanel();
    } else {
      setState(() => _error = kDebugMode
          ? 'login_err_invalid_demo'.tr
          : 'login_err_release'.tr);
    }
  }

  void _gotoPanel() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AdminPanelPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          'login_title'.tr,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: LayoutBuilder(builder: (context, c) {
        // Responsive bound: desktop browsers get a centered 480px form,
        // mobile uses the full width.
        final isWide = c.maxWidth >= 700;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isWide ? 480 : double.infinity),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 20.h),
              child: _buildForm(),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64.w,
            height: 64.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.amber.withOpacity(0.40), width: 1.4),
            ),
            child: Icon(Icons.admin_panel_settings_rounded,
                size: 30.sp, color: Colors.amber.shade300),
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          'login_restricted'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          'login_restricted_sub'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12.sp,
            height: 1.4,
          ),
        ),
        SizedBox(height: 24.h),

        // ── Cloud login fields ─────────────────────────────────────────
        _Label(text: 'login_label_email'.tr),
        SizedBox(height: 6.h),
        TextField(
          controller: _emailCtrl,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          style: TextStyle(color: Colors.white, fontSize: 14.sp),
          decoration: _darkInputDecoration(hint: 'admin@example.com'),
        ),
        SizedBox(height: 12.h),
        _Label(text: 'login_label_password'.tr),
        SizedBox(height: 6.h),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          style: TextStyle(color: Colors.white, fontSize: 14.sp),
          decoration: _darkInputDecoration(hint: '••••••••'),
          onSubmitted: (_) => _submitCloud(),
        ),
        if (_error != null) ...[
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.red.withOpacity(0.30)),
            ),
            child: Row(children: [
              Icon(Icons.error_outline_rounded,
                  size: 14.sp, color: Colors.redAccent.shade100),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Colors.redAccent.shade100,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]),
          ),
        ],
        SizedBox(height: 14.h),
        ElevatedButton.icon(
          onPressed: _busy ? null : _submitCloud,
          icon: const Icon(Icons.cloud_done_rounded, size: 16),
          label: _busy
              ? SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: const CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black87),
                )
              : Text(
                  'login_cloud_btn'.tr,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.sp,
                    letterSpacing: 0.2,
                  ),
                ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber.shade400,
            foregroundColor: Colors.black87,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            elevation: 0,
          ),
        ),

        // ── Demo passcode fallback (debug builds only) ─────────────────
        if (kDebugMode) ...[
          SizedBox(height: 18.h),
          GestureDetector(
            onTap: () =>
                setState(() => _showDemoPanel = !_showDemoPanel),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(
                _showDemoPanel
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 16.sp,
                color: Colors.white54,
              ),
              SizedBox(width: 4.w),
              Text(
                'login_demo_toggle'.tr,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
          if (_showDemoPanel) ...[
            SizedBox(height: 10.h),
            TextField(
              controller: _passcodeCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
              ),
              decoration: _darkInputDecoration(hint: '••••').copyWith(
                counterText: '',
              ),
              onSubmitted: (_) => _submitDemo(),
            ),
            SizedBox(height: 8.h),
            OutlinedButton(
              onPressed: _submitDemo,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.amber.shade300,
                side: BorderSide(color: Colors.amber.shade300),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'login_demo_btn'.tr,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.sp,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  InputDecoration _darkInputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white24, fontSize: 13.sp),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      contentPadding:
          EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: Colors.amber, width: 1.4),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white70,
        fontSize: 11.5.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }
}
