import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/admin_service.dart';
import '../../services/firebase_service.dart';
import '../app_state.dart';
import '../screens/partner_screen.dart';

/// Admin console. Same code runs on Android and as Flutter web on GitHub Pages (/admin).
/// Requires the `admin` custom claim (set with pipeline/tools/set_claim.py).
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('${t.appTitle} · ${t.adminMode}')),
      body: GoogleSignInGate(intro: t.adminMode, builder: (_) => const _AdminGate()),
    );
  }
}

class _AdminGate extends StatelessWidget {
  const _AdminGate();
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = AppScope.of(context);
    return FutureBuilder<UserClaims>(
      future: s.fb.claims(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        if (!snap.data!.admin) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(t.notAdmin, textAlign: TextAlign.center),
                TextButton(onPressed: s.fb.signOut, child: Text(t.signOut)),
              ]),
            ),
          );
        }
        return _AdminTabs(AdminService(s.fb.db), s.fb.user?.email);
      },
    );
  }
}

class _AdminTabs extends StatelessWidget {
  final AdminService svc;
  final String? email;
  const _AdminTabs(this.svc, this.email);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return DefaultTabController(
      length: 5,
      child: Column(children: [
        TabBar(isScrollable: true, tabs: [
          Tab(text: t.adminReview),
          Tab(text: t.adminPartners),
          Tab(text: t.adminConfig),
          Tab(text: t.adminRuns),
          Tab(text: t.adminReports),
        ]),
        Expanded(
          child: TabBarView(children: [
            _ReviewTab(svc, email),
            _PartnersTab(svc),
            _ConfigTab(svc),
            _RunsTab(svc),
            _ReportsTab(svc),
          ]),
        ),
      ]),
    );
  }
}

typedef Docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>;

/// FutureBuilder + pull-to-refresh helper.
class _Loader extends StatefulWidget {
  final Future<Docs> Function() load;
  final Widget Function(BuildContext, Docs, VoidCallback reload) builder;
  const _Loader({required this.load, required this.builder});
  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  late Future<Docs> f = widget.load();
  void reload() => setState(() => f = widget.load());
  @override
  Widget build(BuildContext context) => FutureBuilder<Docs>(
        future: f,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return RefreshIndicator(onRefresh: () async => reload(), child: widget.builder(context, snap.data!, reload));
        },
      );
}

class _ReviewTab extends StatelessWidget {
  final AdminService svc;
  final String? email;
  const _ReviewTab(this.svc, this.email);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _Loader(
      load: svc.pendingReviews,
      builder: (context, docs, reload) {
        if (docs.isEmpty) return ListView(children: [Padding(padding: const EdgeInsets.all(32), child: Text(t.reviewEmpty))]);
        return ListView(children: [
          for (final d in docs) _ReviewCard(d.id, d.data(), onDecide: (dec, [edited]) async {
            await svc.decide(d.id, dec, editedRow: edited, by: email);
            reload();
          }),
        ]);
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> doc;
  final Future<void> Function(String decision, [Map<String, dynamic>? edited]) onDecide;
  const _ReviewCard(this.id, this.doc, {required this.onDecide});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final row = Map<String, dynamic>.from(doc['row'] as Map);
    final flags = List<String>.from(doc['flags'] ?? const []);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(builder: (context, c) {
          final extracted = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${row['crop']} · ${row['variety']} · ${row['marketId']}', style: theme.textTheme.titleMedium),
            Text('${row['sourceId']} (${row['trust']}) · ${row['date']} ${row['time'] ?? ''}'),
            const SizedBox(height: 4),
            Text('min ${row['min']}   max ${row['max']}   modal ${row['modal']}   ${row['unit']}',
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            if (row['confidence'] != null) Text('AI confidence ${row['confidence']}'),
            const SizedBox(height: 4),
            Wrap(spacing: 4, runSpacing: 4, children: [
              for (final f in flags) Chip(label: Text(f), visualDensity: VisualDensity.compact, backgroundColor: Colors.orange.shade100),
            ]),
            if (doc['sourceUrl'] != null) SelectableText('${doc['sourceUrl']}', style: theme.textTheme.bodySmall),
          ]);
          final raw = Container(
            padding: const EdgeInsets.all(8),
            color: theme.colorScheme.surfaceContainerHighest,
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: SelectableText('${t.rawExcerpt}:\n${doc['rawExcerpt'] ?? ''}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          );
          final wide = c.maxWidth > 700;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: extracted),
                    const SizedBox(width: 12),
                    Expanded(child: raw),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [extracted, const SizedBox(height: 8), raw]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              FilledButton(onPressed: () => onDecide('approve'), child: Text(t.approve)),
              OutlinedButton(
                onPressed: () async {
                  final edited = await _editDialog(context, row);
                  if (edited != null) await onDecide('edit', edited);
                },
                child: Text(t.editApprove),
              ),
              TextButton(onPressed: () => onDecide('reject'), child: Text(t.reject)),
            ]),
          ]);
        }),
      ),
    );
  }

  Future<Map<String, dynamic>?> _editDialog(BuildContext context, Map<String, dynamic> row) {
    final t = AppLocalizations.of(context);
    final fields = ['variety', 'marketId', 'min', 'max', 'modal', 'date'];
    final ctrls = {for (final f in fields) f: TextEditingController(text: row[f]?.toString() ?? '')};
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.editApprove),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final f in fields) TextField(controller: ctrls[f], decoration: InputDecoration(labelText: f)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t.cancel)),
          FilledButton(
            onPressed: () {
              num? n(String f) => double.tryParse(ctrls[f]!.text.trim());
              Navigator.pop(c, {
                ...row,
                'variety': ctrls['variety']!.text.trim(),
                'marketId': ctrls['marketId']!.text.trim(),
                'min': n('min'),
                'max': n('max'),
                'modal': n('modal'),
                'date': ctrls['date']!.text.trim(),
                'confidence': null,
              });
            },
            child: Text(t.save),
          ),
        ],
      ),
    );
  }
}

class _PartnersTab extends StatelessWidget {
  final AdminService svc;
  const _PartnersTab(this.svc);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _Loader(
      load: svc.partners,
      builder: (context, docs, reload) => ListView(children: [
        for (final d in docs)
          ListTile(
            leading: Icon(d.data()['approved'] == true ? Icons.verified : Icons.hourglass_empty),
            title: Text('${d.data()['name'] ?? d.id}'),
            subtitle: Text('${d.data()['sourceId'] ?? '—'} · ${d.data()['type'] ?? 'partner'} · ${d.data()['phone'] ?? ''}'),
            onTap: () async {
              final saved = await _editPartner(context, d.id, d.data());
              if (saved) reload();
            },
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('${t.approved}: sourceId + approved → the next pipeline run sets the partner claim.',
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ]),
    );
  }

  Future<bool> _editPartner(BuildContext context, String uid, Map<String, dynamic> p) async {
    final t = AppLocalizations.of(context);
    final keys = ['name', 'name_kn', 'sourceId', 'marketId', 'phone', 'address', 'timings', 'lat', 'lon'];
    final ctrls = {for (final k in keys) k: TextEditingController(text: p[k]?.toString() ?? '')};
    var approved = p['approved'] == true;
    var type = (p['type'] ?? 'partner') as String;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(uid, style: const TextStyle(fontSize: 12)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SwitchListTile(title: Text(t.approved), value: approved, onChanged: (v) => set(() => approved = v)),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: InputDecoration(labelText: t.type),
                items: const [
                  DropdownMenuItem(value: 'partner', child: Text('partner')),
                  DropdownMenuItem(value: 'trader', child: Text('trader')),
                ],
                onChanged: (v) => set(() => type = v!),
              ),
              for (final k in keys) TextField(controller: ctrls[k], decoration: InputDecoration(labelText: k)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.cancel)),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t.save)),
          ],
        ),
      ),
    );
    if (ok != true) return false;
    final data = <String, dynamic>{'approved': approved, 'type': type};
    for (final k in keys) {
      final v = ctrls[k]!.text.trim();
      if (v.isEmpty) continue;
      data[k] = (k == 'lat' || k == 'lon') ? double.tryParse(v) : v;
    }
    await svc.updatePartner(uid, data);
    return true;
  }
}

class _ConfigTab extends StatefulWidget {
  final AdminService svc;
  const _ConfigTab(this.svc);
  @override
  State<_ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends State<_ConfigTab> {
  final validation = TextEditingController();
  final aliases = TextEditingController();
  bool loaded = false;

  static const _defaults = {
    'arecanut': {'minQtl': 5000, 'maxQtl': 150000},
    'rubber': {'minKg': 50, 'maxKg': 500},
    'maxDailyChangePct': 8,
    'maxCrossSourceDiffPct': 10,
    'aiEnabled': true,
    'maxAiCallsPerRun': 30,
  };

  @override
  void initState() {
    super.initState();
    Future.wait([widget.svc.config('validation'), widget.svc.config('aliases')]).then((r) {
      if (!mounted) return;
      const enc = JsonEncoder.withIndent('  ');
      setState(() {
        validation.text = enc.convert(r[0].isEmpty ? _defaults : r[0]);
        aliases.text = enc.convert(r[1].isEmpty ? {'markets': {}, 'varieties': {'arecanut': {}, 'rubber': {}}} : r[1]);
        loaded = true;
      });
    });
  }

  Future<void> _save(String doc, TextEditingController c) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = jsonDecode(c.text) as Map<String, dynamic>;
      await widget.svc.setConfig(doc, data);
      messenger.showSnackBar(SnackBar(content: Text(t.savedOk)));
    } on FormatException {
      messenger.showSnackBar(SnackBar(content: Text(t.invalidJson)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (!loaded) return const Center(child: CircularProgressIndicator());
    Widget editor(String title, TextEditingController c, String doc) => Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              TextField(controller: c, maxLines: 14, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: () => _save(doc, c), child: Text(t.save))),
            ]),
          ),
        );
    return ListView(padding: const EdgeInsets.all(8), children: [
      editor('config/validation', validation, 'validation'),
      editor('${t.aliasesJson} — config/aliases', aliases, 'aliases'),
    ]);
  }
}

class _RunsTab extends StatelessWidget {
  final AdminService svc;
  const _RunsTab(this.svc);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _Loader(
      load: svc.runs,
      builder: (context, docs, reload) => ListView(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: Text(t.runNow),
            onPressed: () => launchUrl(Uri.parse(AppConfig.collectWorkflowUrl), mode: LaunchMode.externalApplication),
          ),
        ),
        for (final d in docs)
          ExpansionTile(
            title: Text('${d.data()['startedAt']}  ·  published ${d.data()['published']}  ·  flagged ${d.data()['flagged']}'),
            subtitle: Text('AI calls ${d.data()['aiCalls']} (${d.data()['aiProvider']})'),
            children: [
              for (final e in ((d.data()['sources'] ?? {}) as Map).entries)
                ListTile(
                  dense: true,
                  leading: Icon((e.value as Map)['ok'] == true ? Icons.check : Icons.error, color: (e.value as Map)['ok'] == true ? Colors.green : Colors.red),
                  title: Text('${e.key}: ${(e.value as Map)['rows']} rows'),
                  subtitle: Text('${(e.value as Map)['error'] ?? (e.value as Map)['note'] ?? ''}'),
                ),
            ],
          ),
      ]),
    );
  }
}

class _ReportsTab extends StatelessWidget {
  final AdminService svc;
  const _ReportsTab(this.svc);

  @override
  Widget build(BuildContext context) {
    return _Loader(
      load: svc.reports,
      builder: (context, docs, reload) => ListView(children: [
        for (final d in docs)
          ListTile(
            title: Text('${d.data()['priceKey']}'),
            subtitle: Text('${d.data()['reason']} ${d.data()['note'] ?? ''}'),
            trailing: IconButton(
              icon: const Icon(Icons.done),
              onPressed: () async {
                await svc.deleteReport(d.id);
                reload();
              },
            ),
          ),
      ]),
    );
  }
}
