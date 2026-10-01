import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../models/models.dart';

const officialColor = Color(0xFF2E7D32);
const partnerColor = Color(0xFF1565C0);
const traderColor = Color(0xFFB7791F);

Color trustColor(Trust t) => switch (t) {
      Trust.official => officialColor,
      Trust.partner => partnerColor,
      Trust.trader => traderColor,
    };

String trustLabel(Trust t, AppLocalizations l) => switch (t) {
      Trust.official => l.badgeOfficial,
      Trust.partner => l.badgePartner,
      Trust.trader => l.badgeTrader,
    };

/// Small filled dot in the trust colour (drawn, so it looks the same on every device).
class TrustDot extends StatelessWidget {
  final Trust trust;
  final double size;
  const TrustDot(this.trust, {super.key, this.size = 8});
  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: trustColor(trust), shape: BoxShape.circle));
}

/// 🟢 Official / 🔵 Partner / 🟡 Trader badge.
class TrustBadge extends StatelessWidget {
  final Trust trust;
  final bool compact;
  const TrustBadge(this.trust, {super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final color = trustColor(trust);
    final label = trustLabel(trust, t);
    if (compact) return Tooltip(message: label, child: TrustDot(trust, size: 12));
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 2, 8, 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (trust == Trust.official)
            Icon(Icons.verified, size: 13, color: color)
          else
            TrustDot(trust),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

/// ▲ 257 (0.6%) as a coloured pill. Hidden when there is no previous price.
class ChangePill extends StatelessWidget {
  final double? change, pct;
  final bool rubber;
  const ChangePill(this.change, this.pct, {super.key, this.rubber = false});

  @override
  Widget build(BuildContext context) {
    if (change == null || pct == null) return const SizedBox.shrink();
    final up = change! > 0, flat = change == 0;
    final color = flat ? Colors.blueGrey : (up ? const Color(0xFF2E7D32) : const Color(0xFFC62828));
    final icon = flat ? Icons.remove : (up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded);
    final amount = rubber ? change!.abs().toStringAsFixed(2) : change!.abs().round().toString();
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text('$amount (${pct!.abs().toStringAsFixed(1)}%)',
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
      ]),
    );
  }
}
