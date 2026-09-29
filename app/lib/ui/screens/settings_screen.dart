import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../models/models.dart';
import '../app_state.dart';
import '../widgets/badges.dart';
import 'onboarding_screen.dart';

/// Free Google Maps link (no Maps SDK / API key).
Uri mapsUri(double lat, double lon) => Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = AppScope.of(context);
    final sources = (s.data?.sources.values.where((x) => x.enabled).toList() ?? <Source>[])
      ..sort((a, b) => a.trust.index.compareTo(b.trust.index));
    return Scaffold(
      appBar: AppBar(title: Text(t.settingsTitle)),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(t.language),
          trailing: SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'kn', label: Text('ಕನ್ನಡ')), ButtonSegment(value: 'en', label: Text('English'))],
            selected: {s.settings.language},
            onSelectionChanged: (v) => s.setLanguage(v.first),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.place_outlined),
          title: Text(t.myMarkets),
          subtitle: Text(s.favourites.map(s.marketName).join(', ')),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingScreen(editing: true))),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: Text(t.dailySummaryNotif),
          subtitle: s.fb.available ? null : Text(t.notConfigured),
          value: s.settings.dailySummary,
          onChanged: s.fb.available ? s.setDailySummary : null,
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(t.dataSources, style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final src in sources) _SourceTile(src),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.disclaimer, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(t.privacyNote),
            const SizedBox(height: 8),
            Text(t.weatherAttribution, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        AboutListTile(
          icon: const Icon(Icons.info_outline),
          applicationName: t.appTitle,
          applicationVersion: '1.0.0',
          aboutBoxChildren: [Text(t.disclaimer)],
        ),
      ]),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final Source src;
  const _SourceTile(this.src);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = AppScope.of(context);
    final p = src.profile;
    return ExpansionTile(
      leading: TrustBadge(src.trust, compact: true),
      title: Text(src.name(s.kn)),
      subtitle: Text(t.trustScore('${(src.score * 100).round()}%')),
      children: [
        if (p.address != null) ListTile(dense: true, leading: const Icon(Icons.home_outlined), title: Text(p.address!)),
        if (p.timings != null) ListTile(dense: true, leading: const Icon(Icons.schedule), title: Text('${t.timings}: ${p.timings}')),
        Wrap(spacing: 8, children: [
          if (src.url.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: Text(t.openLink),
              onPressed: () => launchUrl(Uri.parse(src.url), mode: LaunchMode.externalApplication),
            ),
          if (p.phone != null)
            TextButton.icon(
              icon: const Icon(Icons.call),
              label: Text(t.call),
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: p.phone!.replaceAll(' ', ''))),
            ),
          if (p.lat != null && p.lon != null)
            TextButton.icon(
              icon: const Icon(Icons.map_outlined),
              label: Text(t.map),
              onPressed: () => launchUrl(mapsUri(p.lat!, p.lon!), mode: LaunchMode.externalApplication),
            ),
        ]),
      ],
    );
  }
}
