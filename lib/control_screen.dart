// control_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:provider/provider.dart';
import 'robot_provider.dart';
import 'robot_service.dart';
import 'settings_screen.dart';
import 'package:flutter/services.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:flutter_gstreamer_player/flutter_gstreamer_player.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  _ControlScreenState createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  late RobotService _robotService;

  // Valeurs actuelles des Joysticks
  double _cmdLinear = 0.0;
  double _cmdAngular = 0.0;

  int _modeIndex = 0; // 0: Manuel, 1: Auto, 2: Configuration

  @override
  void initState() {
    super.initState();
    // Lie le service au provide
    _robotService = RobotService(context.read<RobotProvider>());
    _connect(); // Tente la connexion au démarrage
  }

  @override
  void dispose() {
    _robotService.disconnect(); // Nettoie les connexions
    super.dispose();
  }

  Future<void> _connect() async {
    // 1. Démarrer l'écoute (le client doit écouter AVANT de s'enregistrer)
    await _robotService.startUdpListener();

    // 2. S'enregistrer en TCP
    bool success = await _robotService.registerWithServer();

    // 3. Si succès, démarrer l'envoi
    if (success) {
      _robotService.startCmdVelSender(() {
        // Cette fonction fournit les dernières valeurs du joystick au service
        return {'linear': _cmdLinear, 'angular': _cmdAngular};
      });
    } else {
      // Afficher une erreur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Échec de l'enregistrement au serveur")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Met l'app en plein écran immersif (cache la barre de statut)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Observe les changements du provider
    final provider = context.watch<RobotProvider>();

    return Scaffold(
      body: SafeArea(
        // On utilise un Stack pour superposer les éléments
        child: Stack(
          children: [

            // --- 0. Vidéo (Background) ---
            Center(
              child: AspectRatio(
                aspectRatio: 4 / 3, // <-- set your desired aspect ratio here
                child: GstPlayer(
                  pipeline: '''
udpsrc port=5004 
! application/x-rtp,media=video,clock-rate=90000,encoding-name=H264,payload=96 
! rtph264depay 
! h264parse 
! decodebin 
! videoconvert 
! video/x-raw,format=RGBA 
! appsink name=sink sync=false
''',
                ),
              ),
            ),

            // --- 1. Contenu principal (Joysticks et Odom) ---
            Column(
              children: [
                // --- Section Odométrie ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 40.0, 16.0, 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildOdomDisplay("Linéaire (X)", provider.odomLinearX),
                      _buildOdomDisplay("Angulaire (Z)", provider.odomAngularZ),
                    ],
                  ),
                ),

                // --- Section Joysticks ---
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [

                      // --- Joystick Gauche (Linéaire) ---
                      Padding(
                        padding: const EdgeInsets.only(left: 32.0),
                        child: Joystick(
                          mode: JoystickMode.vertical,
                          listener: (details) {
                            setState(() {
                              _cmdLinear = -details.y;
                            });
                          },
                        ),
                      ),

                      // --- Joystick Droit (Angulaire) ---
                      Padding(
                        padding: const EdgeInsets.only(right: 32.0),
                        child: Joystick(
                          mode: JoystickMode.horizontal,
                          listener: (details) {
                            setState(() {
                              _cmdAngular = details.x;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // --- 2. Bouton Paramètres (flottant en haut à droite) ---
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.settings, color: Colors.black54),
                iconSize: 30,
                onPressed: () async {
                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                  _robotService.disconnect();
                  _connect();
                },
              ),
            ),

            // --- 3. Indicateur de Connexion (flottant en haut à gauche) ---
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: provider.isConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),

            // --- NOUVEAU : Panneau de contrôle central (Start, Stop, Mode) ---
            Positioned(
              bottom: 20, // Positionné en bas
              left: 0,    // Centré horizontalement
              right: 0,
              child: Column( // Empile le switch et les boutons
                mainAxisSize: MainAxisSize.min, // Prend la hauteur minimale
                children: [
                  // --- Switch de mode ---
                  ToggleSwitch(
                    initialLabelIndex: _modeIndex,
                    customWidths: [50.0, 50.0, 50.0],
                    cornerRadius: 2.0,
                    activeBgColors: [[Colors.cyan], [Colors.cyan], [Colors.cyan]],
                    activeFgColor: Colors.white,
                    inactiveBgColor: Colors.grey,
                    inactiveFgColor: Colors.white,
                    totalSwitches: 3,
                    labels: ['', '', ''],
                    icons: [FontAwesomeIcons.user, FontAwesomeIcons.robot, FontAwesomeIcons.gear],
                    onToggle: (index) {
                      print('switched to: $index');
                      setState(() {
                        _modeIndex = index ?? 0;
                      });
                      _robotService.setMode(index ?? 0);
                    },
                  ),

                  const SizedBox(height: 15), // Espace entre le switch et les boutons

                  // --- Rangée pour les boutons Start/Stop ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // --- Bouton de démarrage ---
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(15),
                          minimumSize: const Size(70, 70), // Taille augmentée
                        ),
                        onPressed: () {
                          setState(() {
                            _cmdLinear = 0.0;
                            _cmdAngular = 0.0;
                          });
                          _robotService.sendStart();
                        },
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
                      ),

                      const SizedBox(width: 30), // Espace entre les boutons

                      // --- Bouton d'arret d'urgence ---
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(20),
                          minimumSize: const Size(80, 80), // Taille principale
                        ),
                        onPressed: () {
                          setState(() {
                            _cmdLinear = 0.0;
                            _cmdAngular = 0.0;
                          });
                          _robotService.sendImmediateStop();
                        },
                        child: const Icon(Icons.stop, color: Colors.white, size: 30),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // --- SUPPRIMÉ : Les anciens boutons Positioned (4, 5, 6) ont été
            // ---           regroupés dans le panneau de contrôle ci-dessus.
          ],
        ),
      ),
    );
  }

  Widget _buildOdomDisplay(String label, double value) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black87)),
        Text(
          value.toStringAsFixed(2),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ],
    );
  }
}
