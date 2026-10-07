import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../admin/admin_screen.dart';
import 'alerts_screen.dart';
import 'partner_screen.dart';
import 'photo_credits_screen.dart';
import 'settings_screen.dart';
import 'share_card_screen.dart';
import 'weather_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    Widget tile(IconData icon, Color color, String title, String? subtitle, Widget page) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => go(page),
        );
    return Scaffold(
      appBar: AppBar(title: Text(t.navMore)),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Card(
          child: Column(children: [
            tile(Icons.notifications_active_outlined, const Color(0xFFE65100), t.alertsTitle, null, const AlertsScreen()),
            const Divider(indent: 72),
            tile(Icons.wb_sunny_outlined, const Color(0xFFF9A825), t.weatherTitle, null, const WeatherScreen()),
            const Divider(indent: 72),
            tile(Icons.image_outlined, const Color(0xFF2E7D32), t.shareCardTitle, t.shareCardHint, const ShareCardScreen()),
          ]),
        ),
        Card(
          child: Column(children: [
            tile(Icons.settings_outlined, const Color(0xFF546E7A), t.settingsTitle, t.dataSources, const SettingsScreen()),
            const Divider(indent: 72),
            tile(Icons.photo_library_outlined, const Color(0xFF6D4C41), t.photoCredits, null, const PhotoCreditsScreen()),
          ]),
        ),
        Card(
          child: Column(children: [
            tile(Icons.storefront_outlined, const Color(0xFF1565C0), t.partnerMode, null, const PartnerScreen()),
            const Divider(indent: 72),
            tile(Icons.admin_panel_settings_outlined, const Color(0xFF8D6E63), t.adminMode, null, const AdminScreen()),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(t.disclaimer, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ),
      ]),
    );
  }
}
