// robot_service.dart
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:udp/udp.dart';
import 'robot_provider.dart'; // Importez votre provider

class RobotService {
  final RobotProvider _provider;
  Timer? _cmdVelTimer; // Timer pour envoyer cmd_vel à 10Hz
  UDP? _udpSender;
  StreamSubscription<Datagram?>? _udpListenerSubscription;

  RobotService(this._provider);

  // --- Étape 1: Enregistrement TCP ---
  Future<bool> registerWithServer() async {
    print("[TCP] Connexion à ${_provider.serverIP}:${_provider.tcpControlPort}...");
    try {
      Socket socket = await Socket.connect(
        _provider.serverIP,
        _provider.tcpControlPort,
        timeout: const Duration(seconds: 5),
      );

      // --- LE BLOC QUE VOUS AVEZ MENTIONNÉ (CORRECT) ---
      final registerMsg = {
        "type": "register",
        "client_id": _provider.clientID,
        "recv_udp_port": _provider.clientRecvUdpPort
      };
      // --- FIN DU BLOC ---

      // Envoi du message d'enregistrement
      socket.write(json.encode(registerMsg));
      await socket.flush();

      // Écoute de la réponse
      final responseData = await socket.first; 
      final response = json.decode(utf8.decode(responseData));

      // --- AVEC LES CORRECTIONS DU .get() ---
      if (response["ok"] == true) { 
        final port = response["udp_data_port"];
        if (port != null) {
          _provider.setServerUdpPort(port);
          _provider.setConnectionStatus(true);
          print("[TCP] Enregistrement réussi. Port UDP du serveur: $port");
          socket.destroy();
          return true;
        }
      }

      print("[TCP] Échec de l'enregistrement: ${response['error']}"); 
      socket.destroy();
      return false;

    } catch (e) {
      print("[TCP] Échec de connexion: $e");
      _provider.setConnectionStatus(false);
      return false;
    }
  }

  // --- Étape 2: Démarrer l'écoute UDP (Serveur -> Client) ---
  Future<void> startUdpListener() async {
    print("[UDP-Listener] Démarrage sur port ${_provider.clientRecvUdpPort}");
    
    // Annule l'écoute précédente si elle existe
    await _udpListenerSubscription?.cancel();

    try {
      var receiver = await UDP.bind(Endpoint.any(port: Port(_provider.clientRecvUdpPort)));
      
      _udpListenerSubscription = receiver.asStream().listen((datagram) {
        if (datagram == null) return;
        try {
          final message = json.decode(utf8.decode(datagram.data));
          if (message.get("type") == "real_vel") {
            double lx = message.get('linear_x', 0.0).toDouble();
            double az = message.get('angular_z', 0.0).toDouble();
            
            // Met à jour le provider (ce qui mettra à jour l'UI)
            _provider.updateOdometry(lx, az);
          }
        } catch (e) {
          print("[UDP-Listener] Erreur décodage: $e");
        }
      });

    } catch (e) {
       print("[UDP-Listener] Échec du bind: $e");
       // Gérer l'erreur, par ex. port déjà utilisé
    }
  }

  // --- Étape 3: Démarrer l'envoi UDP (Client -> Serveur) ---
  Future<void> startCmdVelSender(Function() getCmdVel) async {
    if (_provider.serverUdpDataPort == null) {
      print("[UDP-Sender] Port UDP du serveur inconnu. Annulation.");
      return;
    }

    // Arrête le timer précédent s'il existe
    _cmdVelTimer?.cancel();
    
    // Crée le socket d'envoi
    _udpSender = await UDP.bind(Endpoint.any());
    final serverEndpoint = Endpoint.unicast(
      InternetAddress(_provider.serverIP),
      port: Port(_provider.serverUdpDataPort!),
    );

    print("[UDP-Sender] Début de l'envoi vers $serverEndpoint");

    // Envoi à 10Hz (toutes les 100ms)
    _cmdVelTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_provider.isConnected) return; // N'envoie rien si déconnecté

      // Récupère les dernières commandes (via la fonction passée en paramètre)
      final cmd = getCmdVel(); 

      final cmdVelMsg = {
        "client_id": _provider.clientID,
        "type": "cmd_vel",
        "linear_x": cmd['linear'],
        "angular_z": cmd['angular']
      };

      try {
        final payload = utf8.encode(json.encode(cmdVelMsg));
        _udpSender?.send(payload, serverEndpoint);
      } catch (e) {
        print("[UDP-Sender] Erreur d'envoi: $e");
      }
    });
  }

  // --- Nettoyage ---
  void disconnect() {
    print("Déconnexion...");
    _cmdVelTimer?.cancel();
    _udpListenerSubscription?.cancel();
    _udpSender?.close();
    _provider.setConnectionStatus(false);
  }
}