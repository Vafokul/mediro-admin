import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../data/usta_review_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  USTA REVIEWS PAGE — reading what clients wrote, and taking one down.
//
//  The database refuses the clear-cut cases before anyone reads them. What is
//  left for a person: a lie, a competitor's sabotage, a review about the wrong
//  usta. This is where that person works. Before this page existed, a bad
//  review could only be removed by hand in SQL.
//
//  A takedown is archived (who, when, why) and bars its author from writing
//  about that usta again — otherwise the upsert would simply put it back.
//  «Qayta ruxsat» undoes that.
// ═══════════════════════════════════════════════════════════════════════════

class UstaReviewsPage extends StatefulWidget {
  final bool embedded;
  const UstaReviewsPage({super.key, this.embedded = false});

  @override
  State<UstaReviewsPage> createState() => _UstaReviewsPageState();
}

class _UstaReviewsPageState extends State<UstaReviewsPage> {
  String _filter = 'all';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await UstaReviewProvider.fetchAllFromCloud(force: true);
    if (mounted) setState(() => _loading = false);
  }

  List<UstaReview> _rows() {
    switch (_filter) {
      case 'flagged':
        return UstaReviewProvider.all().where((r) => r.flagged).toList();
      case 'removed':
        return UstaReviewProvider.removed();
      default:
        return UstaReviewProvider.all();
    }
  }

  Future<void> _remove(UstaReview r) async {
    final reason = await _askReason(r);
    if (reason == null) return;
    final ok = await UstaReviewProvider.remove(r.id, reason);
    if (!mounted) return;
    if (!ok) {
      return _toast('Xatolik', "O'chirib bo'lmadi. Ruxsatni tekshiring.", false);
    }
    setState(() {});
    _toast("O'chirildi", 'Sharh olib tashlandi va yozuvga kiritildi.', true);
  }

  Future<void> _restore(UstaReview r) async {
    final ok = await UstaReviewProvider.restore(r.id);
    if (!mounted) return;
    if (!ok) return _toast('Xatolik', "Bajarib bo'lmadi.", false);
    setState(() {});
    _toast('Qayta ruxsat berildi', 'Mijoz bu usta haqida yana yoza oladi.', true);
  }

  /// A takedown without a reason is unanswerable later — «siz mening sharhimni
  /// o'chirdingiz» has no reply if nobody wrote down why.
  Future<String?> _askReason(UstaReview r) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sharhni olib tashlash'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${r.ustaName} · ${r.clientName} · ${r.rating}★\n"${r.comment}"',
              style:
                  TextStyle(fontSize: 12.5.sp, color: const Color(0xFF374151)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Sabab (yozuvda qoladi)',
              hintText: 'masalan: boshqa usta haqida yozilgan',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Mijoz bu usta haqida boshqa yoza olmaydi. Buni keyin '
              '«Qayta ruxsat» bilan bekor qilish mumkin.',
              style:
                  TextStyle(fontSize: 11.5.sp, color: const Color(0xFF6B7280)),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Bekor')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Olib tashlash'),
          ),
        ],
      ),
    );
  }

  void _toast(String title, String msg, bool good) => Get.snackbar(title, msg,
      snackPosition: SnackPosition.TOP,
      backgroundColor: good ? const Color(0xFF198754) : const Color(0xFFD32F2F),
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      borderRadius: 10,
      duration: const Duration(seconds: 3));

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      const spinner = Center(
        child: Padding(
            padding: EdgeInsets.all(40), child: CircularProgressIndicator()),
      );
      return widget.embedded ? spinner : const Scaffold(body: spinner);
    }
    final body = _buildBody();
    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Usta sharhlari'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.5,
      ),
      body: body,
    );
  }

  Widget _buildBody() {
    final list = _rows();
    final filters = [
      ('all', 'Barchasi (${UstaReviewProvider.all().length})'),
      ('flagged', 'Belgilangan (${UstaReviewProvider.flaggedCount()})'),
      ('removed',
          "O'chirilgan (${UstaReviewProvider.removed().where((r) => !r.restored).length})"),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0x14000000))),
        ),
        child: Row(children: [
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: filters.map((f) {
                final active = _filter == f.$1;
                return GestureDetector(
                  onTap: () => setState(() => _filter = f.$1),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF198754)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(f.$2,
                        style: TextStyle(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? Colors.white
                                : const Color(0xFF475569))),
                  ),
                );
              }).toList(),
            ),
          ),
          IconButton(
            tooltip: 'Yangilash',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _load,
          ),
        ]),
      ),
      Expanded(
        child: list.isEmpty
            ? Center(
                child: Text("Sharh yo'q",
                    style: TextStyle(
                        fontSize: 13.sp, color: Colors.grey.shade600)))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _card(list[i], _filter == 'removed'),
              ),
      ),
    ]);
  }

  Widget _card(UstaReview r, bool isRemoved) {
    final when = r.createdAt == null
        ? ''
        : DateFormat('dd.MM.yyyy HH:mm').format(r.createdAt!.toLocal());
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: r.flagged && !isRemoved
                ? const Color(0xFFE65100)
                : const Color(0xFFEAEDF2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(r.ustaName.isEmpty ? r.ustaId : r.ustaName,
                style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827))),
          ),
          Text('${r.rating}★',
              style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: r.rating <= 2
                      ? const Color(0xFFD32F2F)
                      : const Color(0xFF198754))),
          if (r.flagged && !isRemoved) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(6)),
              child: Text('Filtr belgiladi',
                  style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFE65100))),
            ),
          ],
        ]),
        if (r.comment.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('"${r.comment}"',
                style:
                    TextStyle(fontSize: 13.sp, color: const Color(0xFF374151))),
          ),
        const SizedBox(height: 6),
        Text(
            'Mijoz: ${r.clientName.isEmpty ? "—" : r.clientName} · ${r.clientId}',
            style:
                TextStyle(fontSize: 11.5.sp, color: const Color(0xFF6B7280))),
        if (when.isNotEmpty)
          Text(when,
              style:
                  TextStyle(fontSize: 11.sp, color: const Color(0xFF9CA3AF))),
        if (isRemoved) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
                'Olib tashlagan: ${r.removedByEmail.isEmpty ? "—" : r.removedByEmail}'
                '${r.reason.isEmpty ? "" : " · sabab: ${r.reason}"}',
                style: TextStyle(
                    fontSize: 11.5.sp, color: const Color(0xFF6B7280))),
          ),
          const SizedBox(height: 10),
          // A restored row stays on the list, marked: the review did not come
          // back, so the record of the takedown is all there is.
          if (r.restored)
            Text('Qayta ruxsat berilgan — mijoz yana yoza oladi',
                style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF198754)))
          else
            SizedBox(
              height: 32,
              child: OutlinedButton(
                onPressed: () => _restore(r),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF455A64),
                  side: const BorderSide(color: Color(0xFF455A64)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child:
                    const Text('Qayta ruxsat', style: TextStyle(fontSize: 12)),
              ),
            ),
        ] else ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: () => _remove(r),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Olib tashlash',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ]),
    );
  }
}
