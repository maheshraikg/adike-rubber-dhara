import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../app_state.dart';
import '../widgets/format.dart';

Future<void> showCreateAlertDialog(BuildContext context, PriceRow row) async {
  final s = AppScope.read(context);
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  if (!s.fb.available) {
    messenger.showSnackBar(SnackBar(content: Text(t.notConfigured)));
    return;
  }
  var condition = 'above';
  final value = TextEditingController(text: row.modal?.round().toString() ?? '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: Text('${row.label(s.kn)} · ${s.marketName(row.marketId)}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'above', label: Text(t.alertAbove), icon: const Icon(Icons.trending_up)),
              ButtonSegment(value: 'below', label: Text(t.alertBelow), icon: const Icon(Icons.trending_down)),
            ],
            selected: {condition},
            onSelectionChanged: (v) => set(() => condition = v.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: t.alertValue, suffixText: unitLabel(row.crop, t), border: const OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t.alertCreate)),
        ],
      ),
    ),
  );
  final v = parseInput(value.text);
  if (ok != true || v == null || v <= 0) return;
  try {
    await s.fb.createAlert(crop: row.crop, variety: row.variety, marketId: row.marketId, condition: condition, value: v);
    messenger.showSnackBar(SnackBar(content: Text(t.alertSaved)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(t.errorGeneric('$e'))));
  }
}

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  Future<List<AlertDoc>>? future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final s = AppScope.read(context);
    future = s.fb.available ? s.fb.myAlerts() : Future.value(const []);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.alertsTitle)),
      body: !s.fb.available
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(t.notConfigured, textAlign: TextAlign.center)))
          : FutureBuilder<List<AlertDoc>>(
              future: future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (snap.hasError) return Center(child: Text(t.errorGeneric('${snap.error}')));
                final list = snap.data ?? [];
                if (list.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(t.alertNone, textAlign: TextAlign.center)));
                return RefreshIndicator(
                  onRefresh: () async => setState(_load),
                  child: ListView(children: [
                    for (final a in list)
                      ListTile(
                        leading: Icon(a.condition == 'above' ? Icons.trending_up : Icons.trending_down),
                        title: Text(t.alertLine(
                          s.data?.varieties[a.variety]?.name(s.kn) ?? a.variety,
                          s.marketName(a.marketId),
                          a.condition == 'above' ? t.alertAbove : t.alertBelow,
                          '${inr(a.value)} ${unitLabel(a.crop, t)}',
                        )),
                        subtitle: a.active ? null : const Text('—'),
                        trailing: IconButton(
                          tooltip: t.delete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await s.fb.deleteAlert(a.id);
                            setState(_load);
                          },
                        ),
                      ),
                  ]),
                );
              },
            ),
    );
  }
}
