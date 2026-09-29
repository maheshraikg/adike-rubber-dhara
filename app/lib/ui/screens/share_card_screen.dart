import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../models/models.dart';
import '../app_state.dart';
import '../widgets/format.dart';

/// Rows for the share card: favourite markets (or all if none), best source per market+variety.
List<PriceRow> shareRows(List<PriceRow> rows, List<String> favourites, String crop, {int max = 12}) {
  final best = <String, PriceRow>{};
  for (final r in rows.where((r) => r.crop == crop && r.modal != null)) {
    if (favourites.isNotEmpty && !favourites.contains(r.marketId)) continue;
    final k = '${r.marketId}|${r.variety}';
    final cur = best[k];
    if (cur == null || r.trust.index < cur.trust.index) best[k] = r;
  }
  final list = best.values.toList()
    ..sort((a, b) {
      final fa = favourites.indexOf(a.marketId), fb = favourites.indexOf(b.marketId);
      return fa != fb ? fa.compareTo(fb) : a.variety.compareTo(b.variety);
    });
  return list.take(max).toList();
}

class ShareCardScreen extends StatefulWidget {
  const ShareCardScreen({super.key});
  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final _key = GlobalKey();
  bool busy = false;

  Future<void> _share() async {
    final t = AppLocalizations.of(context);
    setState(() => busy = true);
    try {
      final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = png!.buffer.asUint8List();
      await SharePlus.instance.share(ShareParams(
        text: t.shareText,
        files: [XFile.fromData(bytes, mimeType: 'image/png', name: 'adike_dhara.png')],
        fileNameOverrides: ['adike_dhara.png'],
      ));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.shareCardTitle)),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Text(t.shareCardHint),
        const SizedBox(height: 12),
        RepaintBoundary(key: _key, child: const RateCard()),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: busy ? null : _share,
            icon: const Icon(Icons.share),
            label: Text(t.shareNow),
          ),
        ),
      ),
    );
  }
}

/// The image that is shared. Light theme always (readable on WhatsApp).
class RateCard extends StatelessWidget {
  const RateCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = AppScope.of(context);
    const green = Color(0xFF2E7D32), brown = Color(0xFF8D6E63);
    Widget section(String crop) {
      final rows = shareRows(s.rows, s.favourites, crop);
      if (rows.isEmpty) return const SizedBox.shrink();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text('${cropLabel(crop, t)} (${unitLabel(crop, t)})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: brown)),
        ),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Expanded(
                child: Text('${s.marketName(r.marketId)} · ${r.label(s.kn)}',
                    style: const TextStyle(fontSize: 14, color: Colors.black87)),
              ),
              Text(inr(r.modal), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(width: 6),
              Text(r.trust == Trust.official ? '🟢' : (r.trust == Trust.partner ? '🔵' : '🟡')),
            ]),
          ),
      ]);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: green, width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🌰', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(t.appTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: green)),
          ),
          Text(shortDate(todayIso(), s.settings.language), style: const TextStyle(color: Colors.black54)),
        ]),
        if (s.data?.latest.sample == true) Text(t.sampleData, style: const TextStyle(color: Colors.deepOrange)),
        section('arecanut'),
        section('rubber'),
        const Divider(),
        Text('🟢 ${t.badgeOfficial}  🔵 ${t.badgePartner}  🟡 ${t.badgeTrader}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
        Text(t.disclaimer, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ]),
    );
  }
}
