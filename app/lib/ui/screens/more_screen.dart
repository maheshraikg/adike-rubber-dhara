import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../admin/admin_screen.dart';
import 'alerts_screen.dart';
import 'partner_screen.dart';
import 'settings_screen.dart';
import 'share_card_screen.dart';
import 'weather_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    return Scaffold(
      appBar: AppBar(title: Text(t.navMore)),
      body: ListView(children: [
        ListTile(leading: const Icon(Icons.notifications_outlined), title: Text(t.alertsTitle), onTap: () => go(const AlertsScreen())),
        ListTile(leading: const Icon(Icons.wb_sunny_outlined), title: Text(t.weatherTitle), onTap: () => go(const WeatherScreen())),
        ListTile(leading: const Icon(Icons.image_outlined), title: Text(t.shareCardTitle), onTap: () => go(const ShareCardScreen())),
        ListTile(leading: const Icon(Icons.settings_outlined), title: Text(t.settingsTitle), onTap: () => go(const SettingsScreen())),
        const Divider(),
        ListTile(leading: const Icon(Icons.storefront_outlined), title: Text(t.partnerMode), onTap: () => go(const PartnerScreen())),
        ListTile(leading: const Icon(Icons.admin_panel_settings_outlined), title: Text(t.adminMode), onTap: () => go(const AdminScreen())),
      ]),
    );
  }
}
