import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../models/models.dart';

class TrustBadge extends StatelessWidget {
  final Trust trust;
  final bool compact;
  const TrustBadge(this.trust, {super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final (dot, label, color) = switch (trust) {
      Trust.official => ('🟢', t.badgeOfficial, const Color(0xFF2E7D32)),
      Trust.partner => ('🔵', t.badgePartner, const Color(0xFF1565C0)),
      Trust.trader => ('🟡', t.badgeTrader, const Color(0xFFF9A825)),
    };
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(compact ? dot : '$dot $label', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class ChangeText extends StatelessWidget {
  final double? change, pct;
  final bool rubber;
  const ChangeText(this.change, this.pct, {super.key, this.rubber = false});

  @override
  Widget build(BuildContext context) {
    if (change == null || pct == null) return const SizedBox.shrink();
    final up = change! > 0, flat = change == 0;
    final color = flat ? Colors.grey : (up ? const Color(0xFF2E7D32) : const Color(0xFFC62828));
    final arrow = flat ? '■' : (up ? '▲' : '▼');
    final amount = rubber ? change!.abs().toStringAsFixed(2) : change!.abs().round().toString();
    return Text('$arrow $amount (${pct!.abs().toStringAsFixed(1)}%)',
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13));
  }
}
