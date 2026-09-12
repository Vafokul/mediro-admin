import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  USTA REVIEW PROVIDER — the takedown queue for client reviews.
//
//  A client who has talked to an usta can rate them and leave a comment. The
//  database refuses the clear-cut cases before they are published (abusive
//  words, phone numbers, links — see moderation_words). Everything it cannot
//  judge — a lie, a competitor's sabotage, a review about the wrong usta —
//  needs a person, and until this page there was nowhere for that person to
//  look: `usta_reviews` had no admin screen at all.
//
//  ⛔ Everything here goes through RPCs, not the table. The functions check
//  `profiles.role` themselves (is_admin_user), so a stolen anon key cannot
//  delete a review even though the reviews are public to read.
// ═══════════════════════════════════════════════════════════════════════════

class UstaReview {
  final String id;
  final String ustaId;
  final String ustaName;
  final String clientId;
  final String clientName;
  final int rating;
  final String comment;
  final DateTime? createdAt;

  /// What the filter WOULD say about this text today. Reviews written before
  /// the rule existed were never checked; this is how they surface without
  /// anyone having to read all of them.
  final bool flagged;

  /// Only on a removed review.
  final DateTime? removedAt;
  final String reason;
  final String removedByEmail;

  /// A takedown that was undone. The row STAYS on the record — the review
  /// itself never comes back, so erasing the row would mean an admin could
  /// remove anything and leave no trace.
  final bool restored;

  UstaReview({
    required this.id,
    required this.ustaId,
    required this.ustaName,
    required this.clientId,
    required this.clientName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.flagged = false,
    this.removedAt,
    this.reason = '',
    this.removedByEmail = '',
    this.restored = false,
  });

  static UstaReview _fromMap(Map<String, dynamic> m) => UstaReview(
        id: (m['id'] ?? '').toString(),
        ustaId: (m['usta_id'] ?? '').toString(),
        ustaName: (m['usta_name'] ?? '').toString(),
        clientId: (m['client_id'] ?? '').toString(),
        clientName: (m['client_name'] ?? '').toString(),
        rating: (m['rating'] as num?)?.toInt() ?? 0,
        comment: (m['comment'] ?? '').toString(),
        createdAt: DateTime.tryParse((m['created_at'] ?? '').toString()),
        flagged: m['flagged'] == true,
        removedAt: DateTime.tryParse((m['removed_at'] ?? '').toString()),
        reason: (m['reason'] ?? '').toString(),
        removedByEmail: (m['removed_by_email'] ?? '').toString(),
        restored: m['restored'] == true,
      );
}

class UstaReviewProvider {
  UstaReviewProvider._();

  static final List<UstaReview> _live = [];
  static final List<UstaReview> _removed = [];
  static bool _hasFetched = false;

  static List<UstaReview> all() => List.unmodifiable(_live);
  static List<UstaReview> removed() => List.unmodifiable(_removed);
  static int flaggedCount() => _live.where((r) => r.flagged).length;

  static Future<void> fetchAllFromCloud({bool force = false}) async {
    if (_hasFetched && !force) return;
    try {
      final live = await Supabase.instance.client.rpc('usta_reviews_admin_list');
      final gone =
          await Supabase.instance.client.rpc('usta_reviews_admin_removed_list');
      _live
        ..clear()
        ..addAll((live as List)
            .map((r) => UstaReview._fromMap(Map<String, dynamic>.from(r as Map))));
      _removed
        ..clear()
        ..addAll((gone as List)
            .map((r) => UstaReview._fromMap(Map<String, dynamic>.from(r as Map))));
      _hasFetched = true;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[usta_reviews] fetch failed: $e');
      }
    }
  }

  /// Takes a review down. Returns false when the server refused — the caller
  /// must not say "removed" unless this is true.
  static Future<bool> remove(String id, String reason) async {
    try {
      await Supabase.instance.client.rpc('usta_review_admin_remove',
          params: {'p_id': id, 'p_reason': reason});
      await fetchAllFromCloud(force: true);
      return true;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[usta_reviews] remove failed: $e');
      }
      return false;
    }
  }

  /// Undoes a takedown: the review itself does not come back, but its author
  /// may write about that usta again. The archive row stays, marked.
  static Future<bool> restore(String id) async {
    try {
      await Supabase.instance.client
          .rpc('usta_review_admin_restore', params: {'p_id': id});
      await fetchAllFromCloud(force: true);
      return true;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[usta_reviews] restore failed: $e');
      }
      return false;
    }
  }
}
