import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../models/models.dart';
import '../app_state.dart';
import 'badges.dart';
import 'format.dart';

/// Visual min–max range with a marker at the modal price.
class RangeBar extends StatelessWidget {
  final double? min, max, modal;
  const RangeBar({super.key, this.min, this.max, this.modal});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    if (min == null || max == null) return const SizedBox.shrink();
    final span = max! - min!;
    final pos = (modal == null || span <= 0) ? 0.5 : ((modal! - min!) / span).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(children: [
        LayoutBuilder(builder: (context, c) {
          return SizedBox(
            height: 10,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                top: 3,
                bottom: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.15),
                      theme.colorScheme.primary.withValues(alpha: 0.45),
                    ]),
                  ),
                ),
              ),
              Positioned(
                left: (c.maxWidth - 10) * pos,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.surface, width: 2),
                  ),
                ),
              ),
            ]),
          );
        }),
        const SizedBox(height: 2),
        Row(children: [
          Text('${t.minLabel} ${inr(min)}', style: small),
          const Spacer(),
          Text('${t.maxLabel} ${inr(max)}', style: small),
        ]),
      ]),
    );
  }
}

/// One price row: variety, big modal, change, trust badge, "source · time", min–max bar.
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
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final when = row.date == todayIso() ? row.time : '${shortDate(row.date, s.settings.language)} ${row.time}';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(showMarket ? s.marketName(row.marketId) : row.label(s.kn),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                if (showMarket) Text(row.label(s.kn), style: muted),
                const SizedBox(height: 6),
                TrustBadge(row.trust),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(inr(row.modal),
                  style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800, color: theme.colorScheme.primary, letterSpacing: -0.3)),
              Text(t.modal, style: muted),
              const SizedBox(height: 4),
              ChangePill(row.change, row.changePct, rubber: row.crop == 'rubber'),
            ]),
          ]),
          RangeBar(min: row.min, max: row.max, modal: row.modal),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.schedule, size: 13, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Expanded(
              child: Text('${s.sourceName(row.sourceId)} · $when',
                  style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (onTap != null) Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurfaceVariant),
          ]),
        ]),
      ),
    );
  }
}
