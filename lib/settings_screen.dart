// settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'robot_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _ipController;
  late TextEditingController _tcpPortController;
  late TextEditingController _clientIdController;
  late TextEditingController _clientUdpPortController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<RobotProvider>();
    _ipController = TextEditingController(text: provider.serverIP);
    _tcpPortController = TextEditingController(text: provider.tcpControlPort.toString());
    _clientIdController = TextEditingController(text: provider.clientID);
    _clientUdpPortController = TextEditingController(text: provider.clientRecvUdpPort.toString());
  }

  @override
  void dispose() {
    _ipController.dispose();
    _tcpPortController.dispose();
    _clientIdController.dispose();
    _clientUdpPortController.dispose();
    super.dispose();
  }

  void _save() {
    final provider = context.read<RobotProvider>();
    provider.saveSettings(
      _ipController.text,
      int.tryParse(_tcpPortController.text) ?? 5001,
      _clientIdController.text,
      int.tryParse(_clientUdpPortController.text) ?? 6006,
    );
    Navigator.pop(context); // Revient à l'écran de contrôle
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Réglages"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(labelText: "IP du Serveur"),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: _tcpPortController,
              decoration: const InputDecoration(labelText: "Port de Contrôle TCP"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _clientIdController,
              decoration: const InputDecoration(labelText: "Client ID"),
            ),
            TextField(
              controller: _clientUdpPortController,
              decoration: const InputDecoration(labelText: "Port d'écoute UDP (Client)"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _save,
              child: const Text("Sauvegarder et Reconnecter"),
            ),
          ],
        ),
      ),
    );
  }
}