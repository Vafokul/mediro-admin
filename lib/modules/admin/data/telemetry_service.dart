import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  TELEMETRY SERVICE — Beta-test monitoring & diagnostics.
//
//  Three sinks, one privacy contract:
//    1. recordError(...)     → error_logs   (FlutterError.onError, PlatformDispatcher, zoned guards)
//    2. recordFlowEvent(...) → flow_events  ('buyurtma_open', 'buyurtma_submit_success', ...)
//    3. recordFeedback(...)  → beta_feedback ('ux_rating' + tags + optional comment)
//
//  Privacy contract — enforced in [_sanitize] before EVERY write:
//    - any digit run ≥ 7 is collapsed to "[redacted-phone]"
//    - any email-like pattern is collapsed to "[redacted-email]"
//    - free-text values are truncated to 500 chars and stripped of newlines
//    - chat content, names, addresses are NEVER passed in by the caller —
//      the public API only accepts route ids, event ids, exception classes,
//      and short numeric metadata
//    - long stack traces are hashed into a stable `stack_digest` (8-char
//      base16) so we get pattern info without leaking content
//
//  Performance contract:
//    - every public method is `void` and dispatches via `unawaited(...)` so
//      no UI frame is ever blocked on a Supabase round-trip
//    - on network failure / missing table the write is silently dropped to
//      the in-memory MockTelemetryStore so the Admin Panel still has signal
//    - one global kill switch [enabled] flips everything off in O(1)
//
//  Required Supabase schema (apply once via SQL editor):
//
//    create table if not exists public.error_logs (
//      id bigserial primary key,
//      occurred_at timestamptz default now(),
//      session_id text not null,
//      platform text,
//      event_type text not null,
//      exception_class text,
//      message text,
//      stack_digest text,
//      ui_route text,
//      app_version text
//    );
//
//    create table if not exists public.flow_events (
//      id bigserial primary key,
//      occurred_at timestamptz default now(),
//      session_id text not null,
//      event_id text not null,
//      payload jsonb default '{}'::jsonb
//    );
//
//    create table if not exists public.beta_feedback (
//      id bigserial primary key,
//      submitted_at timestamptz default now(),
//      session_id text not null,
//      ux_rating int not null check (ux_rating between 1 and 5),
//      tags text[],
//      comment text
//    );
//
//    alter table public.error_logs   enable row level security;
//    alter table public.flow_events  enable row level security;
//    alter table public.beta_feedback enable row level security;
//    -- Insert-only for anonymous clients:
//    create policy "anon insert" on public.error_logs   for insert to anon with check (true);
//    create policy "anon insert" on public.flow_events  for insert to anon with check (true);
//    create policy "anon insert" on public.beta_feedback for insert to anon with check (true);
//    -- Read restricted to admin role (resolved by your existing profiles.role check):
//    create policy "admin read" on public.error_logs   for select using (
//      exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
//    );
//    -- (repeat the admin-read policy for flow_events and beta_feedback)
// ═══════════════════════════════════════════════════════════════════════════════

class TelemetryService {
  TelemetryService._();
  static final TelemetryService instance = TelemetryService._();

  /// Global kill switch. Defaults to true for the beta phase; flip in main.dart
  /// or via a remote-config bool later if a hot-issue requires silencing.
  bool enabled = true;

  static const _kSessionKey = 'telemetry_session_v1';
  static const _kSessionMintKey = 'telemetry_session_minted_at_v1';
  static const Duration _sessionTtl = Duration(hours: 24);

  final _storage = GetStorage();
  String? _cachedSession;

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // ── Public API ──────────────────────────────────────────────────────────

  /// Records a runtime error event. All free-form fields are sanitized.
  /// Fire-and-forget: returns immediately, schedules the Supabase insert in
  /// a microtask, and falls back to the in-memory store on any failure.
  void recordError({
    required String eventType, // 'flutter_error' | 'platform_dispatcher' | 'zone_uncaught'
    String? exceptionClass,
    String? message,
    String? stack,
    String? uiRoute,
    String? appVersion,
  }) {
    if (!enabled) return;
    final payload = <String, dynamic>{
      'session_id': _sessionId(),
      'platform': _platformTag(),
      'event_type': eventType,
      'exception_class': _sanitize(exceptionClass, max: 80),
      'message': _sanitize(message, max: 500),
      'stack_digest': _stackDigest(stack),
      'ui_route': _sanitize(uiRoute, max: 80),
      'app_version': _sanitize(appVersion, max: 32),
    };
    MockTelemetryStore.addError(payload);
    unawaited(_safeInsert('error_logs', payload));
  }

  /// Records a UI flow event. `payload` is converted to JSON and sanitized
  /// recursively so any accidental free-text value still goes through the
  /// privacy filter.
  void recordFlowEvent({
    required String eventId,
    Map<String, dynamic>? payload,
  }) {
    if (!enabled) return;
    final cleanPayload = _sanitizeMap(payload ?? const {});
    final row = <String, dynamic>{
      'session_id': _sessionId(),
      'event_id': _sanitize(eventId, max: 64) ?? eventId,
      'payload': cleanPayload,
    };
    MockTelemetryStore.addFlow(row);
    unawaited(_safeInsert('flow_events', row));
  }

  /// Records a beta-feedback submission. Rating is clamped 1–5; tags are
  /// sanitized; comment is truncated to 500 chars.
  void recordFeedback({
    required int uxRating,
    List<String> tags = const [],
    String? comment,
  }) {
    if (!enabled) return;
    final clampedRating = uxRating.clamp(1, 5);
    final row = <String, dynamic>{
      'session_id': _sessionId(),
      'ux_rating': clampedRating,
      'tags': tags
          .map((t) => _sanitize(t, max: 32))
          .where((t) => t != null && t.isNotEmpty)
          .toList(),
      'comment': _sanitize(comment, max: 500),
    };
    MockTelemetryStore.addFeedback(row);
    unawaited(_safeInsert('beta_feedback', row));
  }

  // ── Internals ───────────────────────────────────────────────────────────

  Future<void> _safeInsert(String table, Map<String, dynamic> row) async {
    try {
      final c = _client;
      if (c == null) return;
      await c.from(table).insert(row);
    } catch (e) {
      // Silently swallow: the mock store already received the row, so the
      // admin panel still sees the event. Never let telemetry crash a user
      // flow — that would violate the Zero-Impact contract.
      if (kDebugMode) {
        // ignore: avoid_print
        print('[telemetry] $table insert failed: $e');
      }
    }
  }

  String _sessionId() {
    if (_cachedSession != null) return _cachedSession!;
    final mintedAtMs = _storage.read<int>(_kSessionMintKey) ?? 0;
    final saved = _storage.read<String>(_kSessionKey);
    final now = DateTime.now().millisecondsSinceEpoch;
    final stillFresh = saved != null &&
        now - mintedAtMs < _sessionTtl.inMilliseconds;
    if (stillFresh) {
      _cachedSession = saved;
      return saved;
    }
    final fresh = _newSessionId();
    _storage.write(_kSessionKey, fresh);
    _storage.write(_kSessionMintKey, now);
    _cachedSession = fresh;
    return fresh;
  }

  String _newSessionId() {
    final r = Random.secure();
    final bytes = List<int>.generate(8, (_) => r.nextInt(256));
    return 'sess_${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  String _platformTag() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name; // 'android', 'iOS', ...
  }

  // ── Privacy filter ──────────────────────────────────────────────────────

  static final _phoneRe = RegExp(r'\d{7,}');
  static final _emailRe = RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');
  static final _newlineRe = RegExp(r'\s*\n\s*');

  static String? _sanitize(String? s, {int max = 500}) {
    if (s == null) return null;
    var v = s
        .replaceAll(_emailRe, '[redacted-email]')
        .replaceAll(_phoneRe, '[redacted-phone]')
        .replaceAll(_newlineRe, ' ')
        .trim();
    if (v.length > max) v = '${v.substring(0, max)}…';
    return v.isEmpty ? null : v;
  }

  static Map<String, dynamic> _sanitizeMap(Map<String, dynamic> m) {
    final out = <String, dynamic>{};
    m.forEach((k, v) {
      if (v is String) {
        out[k] = _sanitize(v, max: 200);
      } else if (v is num || v is bool) {
        out[k] = v;
      } else if (v is Map) {
        out[k] = _sanitizeMap(v.cast<String, dynamic>());
      } else if (v is List) {
        out[k] = v
            .map((e) => e is String ? _sanitize(e, max: 200) : e)
            .toList();
      } else if (v == null) {
        out[k] = null;
      } else {
        // Stringify and sanitize unknown types — never leak raw toString().
        out[k] = _sanitize(v.toString(), max: 200);
      }
    });
    return out;
  }

  /// 8-char hex digest of the FIRST 1000 chars of the stack. Stable across
  /// the same crash site, never includes the raw stack text in the DB.
  static String? _stackDigest(String? stack) {
    if (stack == null || stack.isEmpty) return null;
    final s = stack.length > 1000 ? stack.substring(0, 1000) : stack;
    var h = 0x811c9dc5;
    for (final cu in utf8.encode(s)) {
      h = (h ^ cu) * 0x01000193 & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  IN-MEMORY MIRROR — always-on backup so the Admin Panel sees recent
//  events even when offline / when the Supabase tables are not yet provisioned.
//  Each list is capped at 200 entries (FIFO eviction) so RAM stays bounded.
// ─────────────────────────────────────────────────────────────────────────────

class MockTelemetryStore {
  static const int _cap = 200;
  static final List<Map<String, dynamic>> _errors = [];
  static final List<Map<String, dynamic>> _flow = [];
  static final List<Map<String, dynamic>> _feedback = [];

  static void addError(Map<String, dynamic> r) =>
      _push(_errors, {...r, '_at': DateTime.now().toIso8601String()});
  static void addFlow(Map<String, dynamic> r) =>
      _push(_flow, {...r, '_at': DateTime.now().toIso8601String()});
  static void addFeedback(Map<String, dynamic> r) =>
      _push(_feedback, {...r, '_at': DateTime.now().toIso8601String()});

  static List<Map<String, dynamic>> errors() =>
      List<Map<String, dynamic>>.from(_errors.reversed);
  static List<Map<String, dynamic>> flow() =>
      List<Map<String, dynamic>>.from(_flow.reversed);
  static List<Map<String, dynamic>> feedback() =>
      List<Map<String, dynamic>>.from(_feedback.reversed);

  /// Aggregated funnel — total opens vs. total submits, with conversion %.
  static ({int opens, int submits, double conversionPct}) buyurtmaFunnel() {
    var opens = 0;
    var submits = 0;
    for (final e in _flow) {
      final id = (e['event_id'] ?? '').toString();
      if (id == 'buyurtma_open') opens++;
      if (id == 'buyurtma_submit_success') submits++;
    }
    final pct = opens == 0 ? 0.0 : (submits * 100.0 / opens);
    return (opens: opens, submits: submits, conversionPct: pct);
  }

  static void _push(List<Map<String, dynamic>> list, Map<String, dynamic> r) {
    list.add(r);
    if (list.length > _cap) list.removeRange(0, list.length - _cap);
  }
}
