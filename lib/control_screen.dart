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

class ControlScreen extends StatefulWidget {
  const ControlScreen({Key? key}) : super(key: key);

  @override
  _ControlScreenState createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  late RobotService _robotService;
  
  // Valeurs actuelles du Joystick
  double _cmdLinear = 0.0;
  double _cmdAngular = 0.0;

  int _modeIndex = 0; // 0: Manuel, 1: Auto, 2: Configuration

  @override
  void initState() {
    super.initState();
    // Lie le service au provider
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Échec de l'enregistrement au serveur")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ---- AJOUTÉ ----
    // Met l'app en plein écran immersif (cache la barre de statut)
    // Le mode "sticky" la fait réapparaître si on glisse depuis le bord.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Observe les changements du provider
    final provider = context.watch<RobotProvider>();

    return Scaffold(
      // --- SUPPRIMÉ ---
      // appBar: AppBar( ... ), 

      // On utilise un SafeArea pour que nos boutons flottants
      // n'aillent pas sous l'encoche ("notch") du téléphone.
      body: SafeArea(
        // On utilise un Stack pour superposer les éléments
        child: Stack(
          children: [
            
            // --- 1. Votre contenu principal (Joystick et Odom) ---
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // --- Section Odométrie ---
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildOdomDisplay("Linéaire (X)", provider.odomLinearX),
                      _buildOdomDisplay("Angulaire (Z)", provider.odomAngularZ),
                    ],
                  ),
                ),
                
                // --- Section Joystick ---
                Align(
                  alignment: Alignment.centerLeft, // Positionne le joystick à gauche
                  child: Padding(
                    padding: const EdgeInsets.only(left: 32.0), // petit décalage du bord
                    child: Joystick(
                      mode: JoystickMode.all,
                      listener: (details) {
                        setState(() {
                          _cmdLinear = -details.y;
                          _cmdAngular = -details.x;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),

            // --- 2. Bouton Paramètres (flottant en haut à droite) ---
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                // On met une couleur visible sur n'importe quel fond
                icon: const Icon(Icons.settings, color: Colors.black54),
                iconSize: 30, // Un peu plus gros pour être facile à taper
                onPressed: () async {
                  // On désactive le plein écran avant d'aller aux réglages
                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                  // On se reconnecte au cas où les réglages ont changé
                  _robotService.disconnect();
                  _connect();
                },
              ),
            ),

            // --- 3. Indicateur de Connexion (flottant en haut à gauche) ---
            Positioned(
              top: 20, // Ajusté pour aligner visuellement
              left: 20,
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: provider.isConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [ // Ombre pour la visibilité
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),

            // --- 4. Bouton d'arret d'urgence (flottant en bas a droite) ---
            Positioned(
              bottom: 20,
              right: 20,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(20),
                  minimumSize: const Size(100, 100),
                ),
                onPressed: () {
                  setState(() {
                    _cmdLinear = 0.0;
                    _cmdAngular = 0.0;
                  });
                  // Optionnel: Envoyer immédiatement une commande d'arrêt
                  _robotService.sendImmediateStop();
                },
                child: const Icon(Icons.stop, color: Colors.white, size: 30),
              ),
            ),

            // --- 5. Switch de mode (flottant en bas au centre) ---
            Positioned(
              bottom: 20,
              left: MediaQuery.of(context).size.width / 2 - 30,
              child: ToggleSwitch(
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
            ),

            // --- 4. Bouton de démarrage (flottant en bas à droite du bouton d'arrêt) ---
            Positioned(
              bottom: 20,
              right: 150,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(20),
                  minimumSize: const Size(40, 40),
                ),
                onPressed: () {
                  setState(() {
                    _cmdLinear = 0.0;
                    _cmdAngular = 0.0;
                  });
                  // Optionnel: Envoyer immédiatement une commande de démarrage
                  _robotService.sendStart();
                },
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildOdomDisplay(String label, double value) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        Text(
          value.toStringAsFixed(2), // 2 chiffres après la virgule
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ],
    );
  }
}