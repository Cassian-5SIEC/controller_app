// robot_service.dart
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:udp/udp.dart';
import 'robot_provider.dart';

class RobotService {
  final RobotProvider _provider;
  Timer? _cmdVelTimer; // Timer pour envoyer cmd_vel à 10Hz
  UDP? _udpSender;
  StreamSubscription<Datagram?>? _udpListenerSubscription;
  // Socket TCP persistant vers le serveur de contrôle
  Socket? _tcpSocket;
  StreamSubscription? _tcpListener;

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
        "recv_udp_port": _provider.clientRecvUdpPort,
        "recv_image_port": 5004,
      };
      // --- FIN DU BLOC ---

      // Envoi du message d'enregistrement
      socket.write(json.encode(registerMsg));
      await socket.flush();

      // Prépare la socket persistante et un listener unique. On utilise un
      // Completer pour attendre la première réponse (sans appeler socket.first
      // qui attacherait un listener séparé et provoquerait "Stream has already
      // been listened to").
      _tcpSocket = socket;
      final completer = Completer<Map<String, dynamic>>();

      _tcpListener = _tcpSocket!
          .cast<List<int>>()          // <-- this is the key part
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((data) {
        try {
          final decoded = json.decode(data);
          // Assure que c'est un map
          Map<String, dynamic> msg;
          try {
            msg = Map<String, dynamic>.from(decoded);
          } catch (e) {
            // Si ce n'est pas un objet JSON, on skip
            print('[TCP] Message non-objet reçu: $decoded');
            if (!completer.isCompleted) completer.completeError(StateError('Invalid registration response'));
            return;
          }

          if (!completer.isCompleted) {
            // Première réponse : utilisée pour l'enregistrement
            completer.complete(msg);
          } else {
            // Messages TCP suivants
            // Si le serveur envoie un heartbeat, on renvoie un ack
            final type = msg['type'];
            if (type == 'heartbeat') {
              try {
                final ack = json.encode({'type': 'heartbeat_ack'});
                _tcpSocket?.write(ack);
                _tcpSocket?.flush();
                print('[TCP] Heartbeat reçu - ack envoyé');
              } catch (e) {
                print('[TCP] Erreur en envoyant heartbeat_ack: $e');
              }
            } else {
              print('[TCP] Message reçu du serveur: $msg');
            }
          }
        } catch (e) {
          print('[TCP] Erreur décodage message TCP: $e');
          if (!completer.isCompleted) completer.completeError(e);
        }
      }, onError: (e) {
        print('[TCP] Erreur socket: $e');
        if (!completer.isCompleted) completer.completeError(e);
      }, onDone: () {
        print('[TCP] Socket fermée par le serveur');
        _provider.setConnectionStatus(false);
        _tcpSocket = null;
        if (!completer.isCompleted) {
          completer.completeError(StateError('Socket closed before response'));
        }
      }, cancelOnError: true);

      // Attend la première réponse (timeout raisonnable)
      Map<String, dynamic> response;
      try {
        response = await completer.future.timeout(const Duration(seconds: 5));
      } catch (e) {
        print('[TCP] Échec lecture réponse d\'enregistrement: $e');
        // Nettoyage en cas d'échec
        try {
          await _tcpListener?.cancel();
        } catch (_) {}
        try {
          _tcpSocket?.destroy();
        } catch (_) {}
        _tcpSocket = null;
        _provider.setConnectionStatus(false);
        return false;
      }

      // --- AVEC LES CORRECTIONS DU .get() ---
      if (response["ok"] == true) { 
        final port = response["udp_data_port"];
        if (port != null) {
          _provider.setServerUdpPort(port);
          _provider.setConnectionStatus(true);
          print("[TCP] Enregistrement réussi. Port UDP du serveur: $port");
          return true;
        }
      }
      print("[TCP] Échec de l'enregistrement: ${response['error']}"); 
      // Si l'enregistrement a échoué, on ferme la socket car elle n'est pas utile
      try {
        socket.destroy();
      } catch (_) {}
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
          if (message["type"] == "real_vel") {
            double lx = (message['linear_x'] ?? 0.0).toDouble();
            double az = (message['angular_z'] ?? 0.0).toDouble();
            
            // Met à jour le provider (ce qui mettra à jour l'UI)
            _provider.updateOdometry(lx, az);
          } else if (message["type"] == "general_data") {
            double level = (message['battery_level'] ?? 0.0).toDouble();
            _provider.updateBatteryLevel(level);
          } else if (message["type"] == "occupancy_grid") {
            int w = message['width'];
            int h = message['height'];
            // JSON arrays are technically dynamic, cast them to int
            List<int> data = List<int>.from(message['data']);
            double res = (message['resolution'] ?? 0.05).toDouble();

            _provider.updateMap(w, h, data, res);
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

  // --- Envoi d'une commande d'arrêt immédiate via TCP pour assurer l'arrêt ---
  void sendImmediateStop() {
    print("[TCP] Envoi d'une commande d'arrêt immédiate.");
    final stopMsg = {
      "type": "emergency_stop",
      "client_id": _provider.clientID
    };

    if (_tcpSocket != null) {
      try {
        _tcpSocket!.write(json.encode(stopMsg));
        _tcpSocket!.flush();
      } catch (e) {
        print("[TCP] Erreur en envoyant stop via socket existante: $e");
      }
      return;
    }

    // Si pas de socket persistante, on ouvre une connexion éphémère
    Socket.connect(
      _provider.serverIP,
      _provider.tcpControlPort,
      timeout: const Duration(seconds: 5),
    ).then((socket) {
      try {
        socket.write(json.encode(stopMsg));
        socket.flush().then((_) => socket.destroy());
      } catch (e) {
        print("[TCP] Erreur en envoyant stop (connexion éphémère): $e");
        try {
          socket.destroy();
        } catch (_) {}
      }
    }).catchError((e) {
      print("[TCP] Échec de connexion pour l'arrêt immédiat: $e");
    });
  }

  void sendStart() {
    print("[TCP] Envoi d'une commande de démarrage.");
    final startMsg = {
      "type": "start",
      "client_id": _provider.clientID
    };

    if (_tcpSocket != null) {
      try {
        _tcpSocket!.write(json.encode(startMsg));
        _tcpSocket!.flush();
      } catch (e) {
        print("[TCP] Erreur en envoyant start via socket existante: $e");
      }
      return;
    }

    // Si pas de socket persistante, on ouvre une connexion éphémère
    Socket.connect(
      _provider.serverIP,
      _provider.tcpControlPort,
      timeout: const Duration(seconds: 5),
    ).then((socket) {
      try {
        socket.write(json.encode(startMsg));
        socket.flush().then((_) => socket.destroy());
      } catch (e) {
        print("[TCP] Erreur en envoyant start (connexion éphémère): $e");
        try {
          socket.destroy();
        } catch (_) {}
      }
    }).catchError((e) {
      print("[TCP] Échec de connexion pour le démarrage: $e");
    });
  }

  void setMode(int modeIndex) {
    print("[TCP] Envoi d'une commande de changement de mode: $modeIndex");
    final modeMsg = {
      "type": "set_mode",
      "client_id": _provider.clientID,
      "mode": modeIndex
    };

    if (_tcpSocket != null) {
      try {
        _tcpSocket!.write(json.encode(modeMsg));
        _tcpSocket!.flush();
      } catch (e) {
        print("[TCP] Erreur en envoyant set_mode via socket existante: $e");
      }
      return;
    }

    // Si pas de socket persistante, on ouvre une connexion éphémère
    Socket.connect(
      _provider.serverIP,
      _provider.tcpControlPort,
      timeout: const Duration(seconds: 5),
    ).then((socket) {
      try {
        socket.write(json.encode(modeMsg));
        socket.flush().then((_) => socket.destroy());
      } catch (e) {
        print("[TCP] Erreur en envoyant set_mode (connexion éphémère): $e");
        try {
          socket.destroy();
        } catch (_) {}
      }
    }).catchError((e) {
      print("[TCP] Échec de connexion pour le changement de mode: $e");
    });
  }

  // --- Nettoyage ---
  void disconnect() {
    print("Déconnexion...");
    _cmdVelTimer?.cancel();
    _udpListenerSubscription?.cancel();
    _udpSender?.close();
    // Ferme la connexion TCP persistante si elle existe
    _tcpListener?.cancel();
    try {
      _tcpSocket?.destroy();
    } catch (_) {}
    _tcpSocket = null;
    _provider.setConnectionStatus(false);
  }
}