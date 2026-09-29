import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../models/models.dart';
import '../app_state.dart';
import 'badges.dart';
import 'format.dart';

/// One price row: variety, big modal, min–max, change, trust badge, "source · time".
class PriceTile extends StatelessWidget {
  final PriceRow row;
  final VoidCallback? onTap;
  final bool showMarket;
  const PriceTile(this.row, {super.key, this.onTap, this.showMarket = false});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final when = row.date == todayIso() ? row.time : '${shortDate(row.date, s.settings.language)} ${row.time}';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(showMarket ? s.marketName(row.marketId) : row.label(s.kn),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  if (showMarket) Text(row.label(s.kn), style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    TrustBadge(row.trust),
                    Text('${s.sourceName(row.sourceId)} · $when',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(inr(row.modal),
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                Text('${t.minLabel}–${t.maxLabel}: ${inr(row.min)} – ${inr(row.max)}', style: theme.textTheme.bodySmall),
                ChangeText(row.change, row.changePct, rubber: row.crop == 'rubber'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
