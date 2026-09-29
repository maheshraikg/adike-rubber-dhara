import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/diary.dart';
import '../../l10n/gen/app_localizations.dart';
import '../app_state.dart';
import '../widgets/format.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});
  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = AppScope.of(context);
    final entries = s.diary.all();
    final totals = seasonTotals(entries);
    return Scaffold(
      appBar: AppBar(title: Text(t.diaryTitle), actions: [
        IconButton(
          tooltip: t.exportCsv,
          icon: const Icon(Icons.file_download_outlined),
          onPressed: entries.isEmpty
              ? null
              : () {
                  final bytes = utf8.encode('﻿${diaryCsv(entries)}'); // BOM so Excel shows Kannada
                  SharePlus.instance.share(ShareParams(
                    files: [XFile.fromData(bytes, mimeType: 'text/csv', name: 'adike_sales_diary.csv')],
                    fileNameOverrides: ['adike_sales_diary.csv'],
                  ));
                },
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: Text(t.diaryAdd),
      ),
      body: ListView(padding: const EdgeInsets.only(bottom: 96), children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            const Icon(Icons.lock_outline, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(t.diaryPrivate, style: Theme.of(context).textTheme.bodySmall)),
          ]),
        ),
        for (final tot in totals)
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              title: Text('${t.seasonTotal(tot.season)} · ${cropLabel(tot.crop, t)}'),
              subtitle: Text('${plainNum(tot.qtyKg)} ${t.unitKgShort} · ${inr(tot.avgPerKg)}/${t.unitKgShort}'),
              trailing: Text(inr(tot.amount), style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
        if (entries.isEmpty) Padding(padding: const EdgeInsets.all(32), child: Text(t.diaryEmpty, textAlign: TextAlign.center)),
        for (final e in entries)
          Dismissible(
            key: ValueKey(e.id),
            background: Container(color: Colors.red.shade100, alignment: Alignment.centerRight, padding: const EdgeInsets.all(16), child: const Icon(Icons.delete)),
            direction: DismissDirection.endToStart,
            onDismissed: (_) async {
              await s.diary.remove(e.id);
              setState(() {});
            },
            child: ListTile(
              title: Text('${cropLabel(e.crop, t)} ${e.variety.isEmpty ? '' : '· ${e.variety}'}'),
              subtitle: Text([
                DateFormat('d MMM yyyy', s.settings.language).format(DateTime.parse(e.date)),
                '${plainNum(e.qtyKg)} ${t.unitKgShort}',
                if (e.buyer.isNotEmpty) e.buyer,
              ].join(' · ')),
              trailing: Text(inr(e.amount)),
            ),
          ),
      ]),
    );
  }

  Future<void> _add(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final s = AppScope.read(context);
    var date = DateTime.now();
    var crop = s.crop;
    final variety = TextEditingController(), qty = TextEditingController(), amount = TextEditingController();
    final buyer = TextEditingController(), note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(t.diaryAdd),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(DateFormat('d MMM yyyy', s.settings.language).format(date)),
                onTap: () async {
                  final d = await showDatePicker(context: c, initialDate: date, firstDate: DateTime(2015), lastDate: DateTime.now());
                  if (d != null) set(() => date = d);
                },
              ),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'arecanut', label: Text(t.cropArecanut)),
                  ButtonSegment(value: 'rubber', label: Text(t.cropRubber)),
                ],
                selected: {crop},
                onSelectionChanged: (v) => set(() => crop = v.first),
              ),
              TextField(controller: variety, decoration: InputDecoration(labelText: t.variety)),
              TextField(controller: qty, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t.diaryQtyKg)),
              TextField(controller: amount, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t.diaryAmount)),
              TextField(controller: buyer, decoration: InputDecoration(labelText: t.diaryBuyer)),
              TextField(controller: note, decoration: InputDecoration(labelText: t.diaryNote)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.cancel)),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t.save)),
          ],
        ),
      ),
    );
    final q = parseInput(qty.text), a = parseInput(amount.text);
    if (ok != true || q == null || a == null) return;
    await s.diary.add(DiaryEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: DateFormat('yyyy-MM-dd').format(date),
      crop: crop,
      variety: variety.text.trim(),
      qtyKg: q,
      amount: a,
      buyer: buyer.text.trim(),
      note: note.text.trim(),
    ));
    if (mounted) setState(() {});
  }
}
