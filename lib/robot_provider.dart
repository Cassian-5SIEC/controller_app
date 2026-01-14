import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // Don't forget this import

// 1. Define a simple helper class for the event
class NotificationEvent {
  final String message;
  final bool isError;
  NotificationEvent(this.message, {this.isError = false});
}

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
  double _batteryLevel = 0.0;

  // --- Map Data ---
  List<int> _mapData = [];
  int _mapWidth = 0;
  int _mapHeight = 0;
  double _mapResolution = 0.05;
  double _mapCarYaw = 0.0;

  List<int> get mapData => _mapData;
  int get mapWidth => _mapWidth;
  int get mapHeight => _mapHeight;
  double get mapResolution => _mapResolution;
  double get mapCarYaw => _mapCarYaw;

  // --- Getters (pour l'UI)
  String get serverIP => _serverIP;
  int get tcpControlPort => _tcpControlPort;
  String get clientID => _clientID;
  int get clientRecvUdpPort => _clientRecvUdpPort;
  int? get serverUdpDataPort => _serverUdpDataPort;
  bool get isConnected => _isConnected;
  double get odomLinearX => _odomLinearX;
  double get odomAngularZ => _odomAngularZ;
  double get batteryLevel => _batteryLevel;

  // Notifications
  final _notificationController =
      StreamController<NotificationEvent>.broadcast();

  // 3. Expose the stream (The UI will listen to this)
  Stream<NotificationEvent> get notificationStream =>
      _notificationController.stream;

  // --- Actions (appelées par le service réseau ou l'UI)

  bool _isPickupRequested = false;
  bool get isPickupRequested => _isPickupRequested;

  void setPickupRequested(bool value) {
    _isPickupRequested = value;
    notifyListeners();
  }

  void showNotification(String message, {bool isError = false}) {
    _notificationController.add(NotificationEvent(message, isError: isError));
  }

  void setConnectionStatus(bool connected) {
    _isConnected = connected;
    notifyListeners();
  }

  void setServerUdpPort(int port) {
    _serverUdpDataPort = port;
  }

  // Appelé par le service réseau lors de la réception d'un paquet
  void updateOdometry(double linearX, double angularZ) {
    const double epsilon = 5e-2; // or any small value
    _odomLinearX = (linearX.abs() < epsilon) ? 0.0 : linearX + 0.0;
    _odomAngularZ = angularZ;
    notifyListeners();
  }

  bool hasBeenNotifyLowBattery = false;
  void updateBatteryLevel(double voltage) {
    // Convert the raw voltage to a percentage using lead-acid curve
    double newPercentage = _getLeadAcidPercentage(voltage);

    // Optional: Add simple smoothing (low-pass filter) to prevent UI flickering
    // if the voltage fluctuates rapidly due to motor spikes.
    // _batteryLevel = (_batteryLevel * 0.8) + (newPercentage * 0.2);

    if (newPercentage < 20 && !hasBeenNotifyLowBattery) {
      showNotification("Battery Low", isError: true);
      hasBeenNotifyLowBattery = true;
    }

    if (newPercentage > 90) {
      hasBeenNotifyLowBattery = false;
    }

    _batteryLevel = newPercentage;
    notifyListeners();
  }

  /// Calculates percentage for a 12V Lead-Acid Battery
  /// Based on standard discharge curves under light-to-medium load.
  double _getLeadAcidPercentage(double voltage) {
    // 1. Cap values above max charge (Charging state can go up to 14V+)
    if (voltage >= 12.7) return 100.0;

    // 2. Cutoff for "Dead" (Deep discharge damages lead batteries)
    if (voltage <= 10.5) return 0.0;

    // 3. The Lookup Table (Voltage Threshold -> Percentage)
    // Adjust these values based on your specific battery datasheet if needed.
    // [Voltage, Percentage]
    const List<List<double>> lookup = [
      [12.7, 100], // Full Resting
      [12.5, 90],
      [12.42, 80],
      [12.32, 70],
      [12.20, 60],
      [12.06, 50], // Nominal center
      [11.90, 40],
      [11.75, 30],
      [11.58, 20],
      [11.31, 10],
      [10.50, 0], // Danger zone
    ];

    // 4. Find where the current voltage fits in the table and interpolate
    for (int i = 0; i < lookup.length - 1; i++) {
      double highV = lookup[i][0];
      double lowV = lookup[i + 1][0];

      if (voltage <= highV && voltage > lowV) {
        double highP = lookup[i][1];
        double lowP = lookup[i + 1][1];

        // Linear interpolation formula between these two specific points
        // percentage = lowP + ( (voltage - lowV) * (highP - lowP) / (highV - lowV) )
        return lowP + ((voltage - lowV) * (highP - lowP) / (highV - lowV));
      }
    }

    return 0.0; // Fallback
  }

  void updateMap(
    int width,
    int height,
    List<int> data,
    double resolution,
    double carYaw,
  ) {
    _mapWidth = width;
    _mapHeight = height;
    _mapData = data;
    _mapResolution = resolution;
    _mapCarYaw = carYaw;
    notifyListeners();
  }

  // --- Persistance (Sauvegarde & Chargement)

  // À appeler au démarrage de l'app
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _serverIP = prefs.getString('serverIP') ?? _serverIP;
    _tcpControlPort = prefs.getInt('tcpControlPort') ?? _tcpControlPort;
    _clientID = prefs.getString('clientID') ?? _clientID;
    _clientRecvUdpPort =
        prefs.getInt('clientRecvUdpPort') ?? _clientRecvUdpPort;
    notifyListeners();
  }

  // Appelé depuis l'écran de réglages
  Future<void> saveSettings(
    String ip,
    int tcpPort,
    String id,
    int clientUdp,
  ) async {
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

  @override
  void dispose() {
    _notificationController.close();
    super.dispose();
  }
}
