// settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'robot_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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
    _tcpPortController = TextEditingController(
      text: provider.tcpControlPort.toString(),
    );
    _clientIdController = TextEditingController(text: provider.clientID);
    _clientUdpPortController = TextEditingController(
      text: provider.clientRecvUdpPort.toString(),
    );
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Réglages"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Connexion Robot",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _ipController,
                        label: "IP du Serveur",
                        icon: Icons.wifi,
                        keyboardType: TextInputType.url,
                      ),
                      _buildTextField(
                        controller: _tcpPortController,
                        label: "Port de Contrôle TCP",
                        icon: Icons.settings_input_component,
                        keyboardType: TextInputType.number,
                      ),
                      _buildTextField(
                        controller: _clientIdController,
                        label: "Identifiant Client (ID)",
                        icon: Icons.badge,
                      ),
                      _buildTextField(
                        controller: _clientUdpPortController,
                        label: "Port d'écoute UDP",
                        icon: Icons.hearing,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text(
                  "Enregistrer et Connecter",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
