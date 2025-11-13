import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RobotProvider with ChangeNotifier {
  // --- Configuration (avec valeurs par défaut)
  String _serverIP = "192.168.1.2";
  int _tcpControlPort = 5001;
  String _clientID = "controller";
  int _clientRecvUdpPort = 6006;
  
  // Port UDP du serveur (obtenu après enregistrement)
  int? _serverUdpDataPort;

  // --- État en temps réel
  bool _isConnected = false;
  double _odomLinearX = 0.0;
  double _odomAngularZ = 0.0;

  // --- Getters (pour l'UI)
  String get serverIP => _serverIP;
  int get tcpControlPort => _tcpControlPort;
  String get clientID => _clientID;
  int get clientRecvUdpPort => _clientRecvUdpPort;
  int? get serverUdpDataPort => _serverUdpDataPort;
  bool get isConnected => _isConnected;
  double get odomLinearX => _odomLinearX;
  double get odomAngularZ => _odomAngularZ;

  // --- Actions (appelées par le service réseau ou l'UI)

  void setConnectionStatus(bool connected) {
    _isConnected = connected;
    notifyListeners();
  }

  void setServerUdpPort(int port) {
    _serverUdpDataPort = port;
  }

  // Appelé par le service réseau lors de la réception d'un paquet
  void updateOdometry(double linearX, double angularZ) {
    _odomLinearX = linearX;
    _odomAngularZ = angularZ;
    notifyListeners();
  }
  
  // --- Persistance (Sauvegarde & Chargement)
  
  // À appeler au démarrage de l'app
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _serverIP = prefs.getString('serverIP') ?? _serverIP;
    _tcpControlPort = prefs.getInt('tcpControlPort') ?? _tcpControlPort;
    _clientID = prefs.getString('clientID') ?? _clientID;
    _clientRecvUdpPort = prefs.getInt('clientRecvUdpPort') ?? _clientRecvUdpPort;
    notifyListeners();
  }

  // Appelé depuis l'écran de réglages
  Future<void> saveSettings(String ip, int tcpPort, String id, int clientUdp) async {
    _serverIP = ip;
    _tcpControlPort = tcpPort;
    _clientID = id;
    _clientRecvUdpPort = clientUdp;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('serverIP', _serverIP);
    await prefs.setInt('tcpControlPort', _tcpControlPort);
    await prefs.setString('clientID', _clientID);
    await prefs.setInt('clientRecvUdpPort', _clientRecvUdpPort);
    
    notifyListeners();
    print("Réglages sauvegardés");
  }
}