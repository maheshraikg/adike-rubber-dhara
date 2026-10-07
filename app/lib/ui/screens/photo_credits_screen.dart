import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/gen/app_localizations.dart';

/// Credits for the real photos used in the app (Wikimedia Commons; the CC
/// licences require naming the author and licence).
class PhotoCreditsScreen extends StatelessWidget {
  const PhotoCreditsScreen({super.key});

  Future<List<Map<String, dynamic>>> _load() async =>
      (jsonDecode(await rootBundle.loadString('assets/images/credits.json')) as List).cast<Map<String, dynamic>>();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.photoCredits)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _load(),
        builder: (context, snap) {
          final items = snap.data ?? const [];
          return ListView(padding: const EdgeInsets.all(12), children: [
            Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 12), child: Text(t.photoCreditsHint)),
            for (final c in items)
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.asset('assets/images/${c['file']}', fit: BoxFit.cover, cacheWidth: 800),
                  ),
                  ListTile(
                    title: Text('${c['title']}'),
                    subtitle: Text('© ${c['author']} · ${c['licence']}'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => launchUrl(Uri.parse('${c['source']}'), mode: LaunchMode.externalApplication),
                  ),
                ]),
              ),
          ]);
        },
      ),
    );
  }
}
