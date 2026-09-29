import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../services/firebase_service.dart';
import '../admin/admin_screen.dart';
import '../app_state.dart';

/// Resize to max 1024 px and re-encode as JPEG until ≤ 300 KB.
Future<Uint8List?> compressForUpload(Uint8List input) async {
  for (final q in [80, 65, 50, 35]) {
    final out = await FlutterImageCompress.compressWithList(input, minWidth: 1024, minHeight: 1024, quality: q);
    if (out.lengthInBytes <= 300 * 1024) return out;
  }
  return null;
}

class GoogleSignInGate extends StatelessWidget {
  final Widget Function(BuildContext) builder;
  final String intro;
  const GoogleSignInGate({super.key, required this.builder, required this.intro});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = AppScope.of(context);
    if (!s.fb.available) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(t.notConfigured, textAlign: TextAlign.center)));
    }
    return StreamBuilder(
      stream: s.fb.authChanges(),
      builder: (context, snap) {
        final u = s.fb.user;
        if (u != null && !u.isAnonymous) return builder(context);
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(intro, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.login),
                label: Text(t.signInGoogle),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    if (u != null && u.isAnonymous) await s.fb.signOut();
                    await s.fb.signInWithGoogle();
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text(t.errorGeneric('$e'))));
                  }
                },
              ),
            ]),
          ),
        );
      },
    );
  }
}

class PartnerScreen extends StatelessWidget {
  const PartnerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.partnerMode)),
      body: GoogleSignInGate(intro: t.partnerIntro, builder: (_) => const _PartnerHome()),
    );
  }
}

class _PartnerHome extends StatefulWidget {
  const _PartnerHome();
  @override
  State<_PartnerHome> createState() => _PartnerHomeState();
}

class _PartnerHomeState extends State<_PartnerHome> {
  late Future<UserClaims> claims;
  final text = TextEditingController();
  Uint8List? photo;
  bool busy = false;
  Future<List<SubmissionDoc>>? subs;

  @override
  void initState() {
    super.initState();
    claims = AppScope.read(context).fb.claims();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = AppScope.of(context);
    return FutureBuilder<UserClaims>(
      future: claims,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final c = snap.data!;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Expanded(child: Text(s.fb.user?.email ?? '')),
            TextButton(onPressed: () => s.fb.signOut(), child: Text(t.signOut)),
          ]),
          if (c.admin)
            FilledButton.tonalIcon(
              icon: const Icon(Icons.admin_panel_settings),
              label: Text(t.adminMode),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen())),
            ),
          const SizedBox(height: 12),
          if (c.partner && c.sourceId != null) ..._submitForm(context, c.sourceId!) else _Application(),
        ]);
      },
    );
  }

  List<Widget> _submitForm(BuildContext context, String sourceId) {
    final t = AppLocalizations.of(context);
    final s = AppScope.of(context);
    subs ??= s.fb.mySubmissions();
    final src = s.source(sourceId);
    return [
      Text(src?.name(s.kn) ?? sourceId, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      TextField(
        controller: text,
        maxLines: 6,
        maxLength: 5000,
        decoration: InputDecoration(labelText: t.partnerSubmitText, border: const OutlineInputBorder()),
      ),
      Row(children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(t.partnerAddPhoto),
          onPressed: () async {
            final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2048);
            if (x == null) return;
            final compressed = await compressForUpload(await x.readAsBytes());
            setState(() => photo = compressed);
          },
        ),
        if (photo != null) ...[
          const SizedBox(width: 8),
          Image.memory(photo!, height: 56),
          IconButton(onPressed: () => setState(() => photo = null), icon: const Icon(Icons.close)),
        ],
      ]),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                if (text.text.trim().isEmpty && photo == null) return;
                final messenger = ScaffoldMessenger.of(context);
                setState(() => busy = true);
                try {
                  await s.fb.submitRates(sourceId: sourceId, text: text.text, imageB64: photo == null ? null : base64Encode(photo!));
                  text.clear();
                  photo = null;
                  subs = s.fb.mySubmissions();
                  messenger.showSnackBar(SnackBar(content: Text(t.submitted)));
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text(t.errorGeneric('$e'))));
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
        child: Text(t.submit),
      ),
      const SizedBox(height: 16),
      Text(t.mySubmissions, style: Theme.of(context).textTheme.titleMedium),
      FutureBuilder<List<SubmissionDoc>>(
        future: subs,
        builder: (context, snap) {
          if (!snap.hasData) return const LinearProgressIndicator();
          return Column(children: [
            for (final d in snap.data!)
              ListTile(
                leading: Icon(switch (d.status) { 'processed' => Icons.check_circle, 'failed' => Icons.error, _ => Icons.schedule }),
                title: Text(d.createdAt == null ? '' : DateFormat('d MMM, h:mm a').format(d.createdAt!)),
                subtitle: Text([
                  switch (d.status) { 'processed' => t.statusProcessed, 'failed' => t.statusFailed, _ => t.statusNew },
                  if (d.status == 'processed') '${d.rows}',
                  if (d.error != null) d.error!,
                ].join(' · ')),
              ),
          ]);
        },
      ),
    ];
  }
}

class _Application extends StatefulWidget {
  @override
  State<_Application> createState() => _ApplicationState();
}

class _ApplicationState extends State<_Application> {
  final name = TextEditingController(), phone = TextEditingController(), address = TextEditingController();
  Future<Map<String, dynamic>?>? existing;

  @override
  void initState() {
    super.initState();
    existing = AppScope.read(context).fb.myPartnerDoc();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = AppScope.of(context);
    return FutureBuilder<Map<String, dynamic>?>(
      future: existing,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LinearProgressIndicator();
        if (snap.data != null) return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(t.partnerPending)));
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t.partnerApply, style: Theme.of(context).textTheme.titleMedium),
          TextField(controller: name, decoration: InputDecoration(labelText: t.name)),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: t.phone)),
          TextField(controller: address, decoration: InputDecoration(labelText: t.address)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await s.fb.applyAsPartner(name: name.text.trim(), phone: phone.text.trim(), address: address.text.trim());
              setState(() => existing = s.fb.myPartnerDoc());
            },
            child: Text(t.submit),
          ),
        ]);
      },
    );
  }
}
