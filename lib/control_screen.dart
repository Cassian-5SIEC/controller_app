import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_gstreamer_player/flutter_gstreamer_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'robot_provider.dart';
import 'robot_service.dart';
import 'settings_screen.dart';
import 'occupancy_map_widget.dart';

// --- 1. Notification Model ---
class HudNotification {
  final String id;
  final String message;
  final IconData icon;
  final Color color;

  HudNotification({
    required this.id,
    required this.message,
    required this.icon,
    required this.color,
  });
}

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  _ControlScreenState createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  late RobotService _robotService;
  double _cmdLinear = 0.0;
  double _cmdAngular = 0.0;
  int _modeIndex = 0;

  StreamSubscription? _notifSubscription;

  // --- Notification State ---
  final List<HudNotification> _notifications = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  // --- Movable Elements State ---
  bool _isEditMode = false;
  Map<String, Offset> _elementPositions = {};
  Map<String, double> _elementScales = {};

  // --- Data Display State ---
  bool _isDataDisplayExpanded = false;

  // Default positions (relative to screen size, will be calculated on first build or reset)
  // We use immediate values for now, but will adjust slightly in build if needed or load from prefs

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _robotService = RobotService(context.read<RobotProvider>());
    final provider = context.read<RobotProvider>();
    _notifSubscription = provider.notificationStream.listen((event) {
      if (mounted) {
        _showNotification(event.message, isError: event.isError);
      }
    });
    _connect();
    _loadPositions();
  }

  Future<void> _loadPositions() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _elementPositions = {
        'topLeft': Offset(
          prefs.getDouble('pos_topLeft_dx') ?? 16.0,
          prefs.getDouble('pos_topLeft_dy') ?? 16.0,
        ),
        'topCenter': Offset(
          prefs.getDouble('pos_topCenter_dx') ?? 300.0, // approximates
          prefs.getDouble('pos_topCenter_dy') ?? 16.0,
        ),
        'topRight': Offset(
          prefs.getDouble('pos_topRight_dx') ?? 650.0, // approximates
          prefs.getDouble('pos_topRight_dy') ?? 16.0,
        ),
        'bottomLeft': Offset(
          prefs.getDouble('pos_bottomLeft_dx') ?? 20.0,
          prefs.getDouble('pos_bottomLeft_dy') ?? 250.0, // approximates
        ),
        'bottomCenter': Offset(
          prefs.getDouble('pos_bottomCenter_dx') ?? 300.0, // approximates
          prefs.getDouble('pos_bottomCenter_dy') ?? 280.0, // approximates
        ),
        'bottomRight': Offset(
          prefs.getDouble('pos_bottomRight_dx') ?? 650.0, // approximates
          prefs.getDouble('pos_bottomRight_dy') ?? 250.0, // approximates
        ),
        'notifications': Offset(
          prefs.getDouble('pos_notifications_dx') ??
              600.0, // Default to right side
          prefs.getDouble('pos_notifications_dy') ?? 150.0,
        ),
        'pickupPopup': Offset(
          prefs.getDouble('pos_pickupPopup_dx') ?? 400.0,
          prefs.getDouble('pos_pickupPopup_dy') ?? 300.0,
        ),
      };

      _elementScales = {
        'topLeft': prefs.getDouble('scale_topLeft') ?? 1.0,
        'topCenter': prefs.getDouble('scale_topCenter') ?? 1.0,
        'topRight': prefs.getDouble('scale_topRight') ?? 1.0,
        'bottomLeft': prefs.getDouble('scale_bottomLeft') ?? 1.0,
        'bottomCenter': prefs.getDouble('scale_bottomCenter') ?? 1.0,
        'bottomRight': prefs.getDouble('scale_bottomRight') ?? 1.0,
        'notifications': prefs.getDouble('scale_notifications') ?? 1.0,
        'pickupPopup': prefs.getDouble('scale_pickupPopup') ?? 1.0,
      };
    });
  }

  Future<void> _savePositions() async {
    final prefs = await SharedPreferences.getInstance();
    _elementPositions.forEach((key, offset) {
      prefs.setDouble('pos_${key}_dx', offset.dx);
      prefs.setDouble('pos_${key}_dy', offset.dy);
    });
    _elementScales.forEach((key, scale) {
      prefs.setDouble('scale_$key', scale);
    });
  }

  void _resetPositions(Size screenSize) {
    // Defines responsive defaults based on current screen size
    setState(() {
      _elementPositions['topLeft'] = const Offset(16, 16);
      _elementPositions['topCenter'] = Offset(screenSize.width / 2 - 100, 16);
      _elementPositions['topRight'] = Offset(screenSize.width - 136, 16);

      _elementPositions['bottomLeft'] = Offset(20, screenSize.height - 180);
      _elementPositions['bottomCenter'] = Offset(
        screenSize.width / 2 - 100,
        screenSize.height - 160,
      );
      _elementPositions['bottomRight'] = Offset(
        screenSize.width - 150,
        screenSize.height - 180,
      );

      _elementPositions['notifications'] = Offset(screenSize.width - 280, 150);
      _elementPositions['pickupPopup'] = Offset(
        screenSize.width / 2 - 150,
        screenSize.height / 2 - 100,
      );

      // Reset scales to 1.0
      _elementScales.updateAll((key, value) => 1.0);
    });
    _savePositions();
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    _robotService.disconnect();
    super.dispose();
  }

  // --- Notification Logic ---
  void _showNotification(String message, {bool isError = false}) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final notification = HudNotification(
      id: id,
      message: message,
      icon: isError ? Icons.warning_amber_rounded : Icons.check_circle_outline,
      color: isError ? Colors.redAccent : Colors.green,
    );

    setState(() {
      _notifications.insert(0, notification);
      _listKey.currentState?.insertItem(
        0,
        duration: const Duration(milliseconds: 300),
      );
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _removeNotification(id);
      }
    });
  }

  void _removeNotification(String id) {
    final index = _notifications.indexWhere((element) => element.id == id);
    if (index >= 0) {
      final removedItem = _notifications[index];
      setState(() {
        _notifications.removeAt(index);
        _listKey.currentState?.removeItem(
          index,
          (context, animation) =>
              _buildNotificationItem(removedItem, animation),
          duration: const Duration(milliseconds: 300),
        );
      });
    }
  }

  Widget _buildNotificationItem(
    HudNotification item,
    Animation<double> animation,
  ) {
    return MergeSemantics(
      child: SizeTransition(
        sizeFactor: animation,
        child: FadeTransition(
          opacity: animation,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: item.color, width: 4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, color: item.color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _connect() async {
    await _robotService.startUdpListener();
    bool success = await _robotService.registerWithServer();
    if (success) {
      _showNotification("Connected to Robot Server");
      _robotService.startCmdVelSender(() {
        return {'linear': _cmdLinear, 'angular': _cmdAngular};
      });
    } else {
      if (mounted) {
        _showNotification("Failed to connect to server", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // final provider = context.watch<RobotProvider>(); // Removed for performance
    final isPickupRequested = context.select<RobotProvider, bool>(
      (p) => p.isPickupRequested,
    );
    final size = MediaQuery.of(context).size;

    // Initialize defaults if empty (first run)
    if (_elementPositions.isEmpty) {
      // Defer to next frame to ensure size is valid if needed,
      // but here we can just do it synchronously for simplicity in build if maps are empty
      _elementPositions['topLeft'] = const Offset(16, 16);
      _elementPositions['topCenter'] = Offset(size.width / 2 - 100, 16);
      _elementPositions['topRight'] = Offset(size.width - 136, 16);
      _elementPositions['bottomLeft'] = Offset(20, size.height - 180);
      _elementPositions['bottomCenter'] = Offset(
        size.width / 2 - 100,
        size.height - 160,
      );
      _elementPositions['bottomRight'] = Offset(
        size.width - 150,
        size.height - 180,
      );
      _elementPositions['notifications'] = Offset(size.width - 280, 150);
    }

    // Ensure scales are initialized
    _elementScales.putIfAbsent('topLeft', () => 1.0);
    _elementScales.putIfAbsent('topCenter', () => 1.0);
    _elementScales.putIfAbsent('topRight', () => 1.0);
    _elementScales.putIfAbsent('bottomLeft', () => 1.0);
    _elementScales.putIfAbsent('bottomCenter', () => 1.0);
    _elementScales.putIfAbsent('bottomRight', () => 1.0);
    _elementScales.putIfAbsent('bottomRight', () => 1.0);
    _elementScales.putIfAbsent('notifications', () => 1.0);
    _elementScales.putIfAbsent('pickupPopup', () => 1.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // --- 1. VIDEO BACKGROUND ---
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ExcludeSemantics(
                  child: const GstPlayer(
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
                ExcludeSemantics(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black87,
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black87,
                        ],
                        stops: [0.0, 0.2, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- 2. MOVABLE HUD ELEMENTS ---

          // Top Left: Status & Settings
          _buildDraggableElement(
            id: 'topLeft',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Selector<RobotProvider, bool>(
                  selector: (_, p) => p.isConnected,
                  builder: (_, isConnected, __) =>
                      _buildConnectionBadge(isConnected),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white70),
                      onPressed: _isEditMode
                          ? null
                          : () async {
                              SystemChrome.setEnabledSystemUIMode(
                                SystemUiMode.edgeToEdge,
                              );
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SettingsScreen(),
                                ),
                              );
                              SystemChrome.setEnabledSystemUIMode(
                                SystemUiMode.immersiveSticky,
                              );
                              _robotService.disconnect();
                              _connect();
                            },
                    ),
                    IconButton(
                      icon: Icon(
                        _isEditMode ? Icons.check : Icons.dashboard_customize,
                        color: _isEditMode
                            ? Colors.greenAccent
                            : Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _isEditMode = !_isEditMode;
                          if (!_isEditMode) {
                            _savePositions();
                            _showNotification("Layout Saved");
                          } else {
                            _showNotification(
                              "Edit Mode: Drag elements to move, +/- to scale",
                            );
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Top Center: Data Display
          _buildDraggableElement(
            id: 'topCenter',
            child: GestureDetector(
              onTap: () {
                if (!_isEditMode) {
                  setState(() {
                    _isDataDisplayExpanded = !_isDataDisplayExpanded;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      Colors.black54, // Slightly clearer for better visibility
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Consumer<RobotProvider>(
                  builder: (context, provider, _) {
                    return MergeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Main Row (Always visible)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildOdomItem(
                                Icons.speed,
                                "${provider.odomLinearX.toStringAsFixed(2)} m/s",
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 1,
                                height: 15,
                                color: Colors.white24,
                              ),
                              const SizedBox(width: 12),
                              _buildOdomItem(
                                Icons.battery_std,
                                "${provider.batteryLevel.toInt()}%",
                                color: provider.batteryLevel < 20
                                    ? Colors.red
                                    : Colors.green,
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 1,
                                height: 15,
                                color: Colors.white24,
                              ),
                              const SizedBox(width: 12),
                              _buildOdomItem(Icons.bolt, "120 W"),
                            ],
                          ),
                          // Expanded Data
                          if (_isDataDisplayExpanded) ...[
                            const SizedBox(height: 12),
                            Container(height: 1, color: Colors.white12),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDetailItem(
                                      "Angular Z",
                                      "${provider.odomAngularZ.toStringAsFixed(2)} rad/s",
                                    ),
                                    const SizedBox(height: 4),
                                    _buildDetailItem(
                                      "Map Yaw",
                                      "${(provider.mapCarYaw * 180 / 3.14159).toStringAsFixed(1)}°",
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 20),
                                Container(
                                  width: 1,
                                  height: 30,
                                  color: Colors.white12,
                                ),
                                const SizedBox(width: 20),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDetailItem("IP", provider.serverIP),
                                    const SizedBox(height: 4),
                                    _buildDetailItem("ID", provider.clientID),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Top Right: Map
          _buildDraggableElement(
            id: 'topRight',
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: const OccupancyMapWidget(),
              ),
            ),
          ),

          // Bottom Left: Throttle Joystick
          _buildDraggableElement(
            id: 'bottomLeft',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "THROTTLE",
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
                const SizedBox(height: 8),
                IgnorePointer(
                  ignoring: _isEditMode,
                  child: ExcludeSemantics(
                    child: Joystick(
                      mode: JoystickMode.vertical,
                      listener: (details) {
                        _cmdLinear = -details.y;
                        // setState(() => _cmdLinear = -details.y); // Removed to prevent full rebuild
                      },
                      base: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white30, width: 2),
                        ),
                      ),
                      stick: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.cyan.withOpacity(0.8),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyan.withOpacity(0.4),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Center: Console
          _buildDraggableElement(
            id: 'bottomCenter',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ToggleSwitch(
                  initialLabelIndex: _modeIndex,
                  minWidth: 40.0,
                  minHeight: 30.0,
                  cornerRadius: 20.0,
                  activeBgColors: const [
                    [Colors.cyan],
                    [Colors.orange],
                    [Colors.purple],
                  ],
                  activeFgColor: Colors.white,
                  inactiveBgColor: Colors.grey.shade800,
                  inactiveFgColor: Colors.white54,
                  totalSwitches: 3,
                  icons: const [
                    FontAwesomeIcons.gamepad,
                    FontAwesomeIcons.robot,
                    FontAwesomeIcons.sliders,
                  ],
                  onToggle: (index) {
                    if (_isEditMode) return;
                    setState(() => _modeIndex = index ?? 0);
                    _robotService.setMode(index ?? 0);
                    _showNotification(
                      "Mode switched: ${index == 0
                          ? 'Manual'
                          : index == 1
                          ? 'Auto'
                          : 'Calibration'}",
                    );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCircleBtn(Colors.green, Icons.play_arrow, () {
                      if (_isEditMode) return;
                      setState(() {
                        _cmdLinear = 0;
                        _cmdAngular = 0;
                      });
                      _robotService.sendStart();
                      _showNotification("Robot Started");
                    }),
                    const SizedBox(width: 20),
                    _buildCircleBtn(Colors.red, Icons.stop, () {
                      if (_isEditMode) return;
                      setState(() {
                        _cmdLinear = 0;
                        _cmdAngular = 0;
                      });
                      _robotService.sendImmediateStop();
                      _showNotification("Emergency Stop", isError: true);
                    }, isBig: true),
                  ],
                ),
                const SizedBox(height: 12),
                Consumer<RobotProvider>(
                  builder: (context, provider, _) =>
                      _buildPickupButton(provider),
                ),

                // Edit Button removed (moved to top left)
              ],
            ),
          ),

          // Bottom Right: Steering Joystick
          _buildDraggableElement(
            id: 'bottomRight',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "STEERING",
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
                const SizedBox(height: 8),
                IgnorePointer(
                  ignoring: _isEditMode,
                  child: ExcludeSemantics(
                    child: Joystick(
                      mode: JoystickMode.horizontal,
                      listener: (details) {
                        _cmdAngular = -details.x;
                        // setState(() => _cmdAngular = -details.x); // Removed to prevent full rebuild
                      },
                      base: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white30, width: 2),
                        ),
                      ),
                      stick: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withOpacity(0.8),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purpleAccent.withOpacity(0.4),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- 5. NOTIFICATION STACK OVERLAY ---
          // Now wrapped in draggable element
          _buildDraggableElement(
            id: 'notifications',
            child: SizedBox(
              width: 260,
              height: 300,
              child: AnimatedList(
                key: _listKey,
                initialItemCount: _notifications.length,
                itemBuilder: (context, index, animation) {
                  return _buildNotificationItem(
                    _notifications[index],
                    animation,
                  );
                },
              ),
            ),
          ),

          // --- 6. PICKUP POPUP ---
          // --- 6. PICKUP POPUP ---
          if (isPickupRequested || _isEditMode)
            _buildDraggableElement(
              id: 'pickupPopup',
              child: BlockSemantics(
                blocking: true,
                child: Consumer<RobotProvider>(
                  builder: (context, provider, _) =>
                      _buildPickupPopup(provider),
                ),
              ),
            ),

          if (_isEditMode)
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton(
                  onPressed: () => _resetPositions(size),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text(
                    "Reset Layout",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDraggableElement({required String id, required Widget child}) {
    final position = _elementPositions[id] ?? const Offset(0, 0);
    final scale = _elementScales[id] ?? 1.0;

    // While dragging, we update position directly.
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanUpdate: _isEditMode
            ? (details) {
                setState(() {
                  final newPos = _elementPositions[id]! + details.delta;
                  _elementPositions[id] = newPos;
                });
              }
            : null,
        child: MergeSemantics(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The Scaled Widget
              Transform.scale(
                scale: scale,
                child: Container(
                  decoration: _isEditMode
                      ? BoxDecoration(
                          border: Border.all(
                            color: Colors.yellowAccent,
                            width: 2 / scale,
                            style: BorderStyle.solid,
                          ),
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  padding: _isEditMode
                      ? const EdgeInsets.all(8)
                      : EdgeInsets.zero,
                  child: child,
                ),
              ),

              // Scaling Controls
              if (_isEditMode)
                Positioned(
                  top: -15,
                  right: -15,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildScaleBtn(Icons.remove, () {
                        setState(() {
                          double s = _elementScales[id] ?? 1.0;
                          s = (s - 0.1).clamp(0.5, 3.0);
                          _elementScales[id] = s;
                        });
                      }),
                      const SizedBox(width: 4),
                      _buildScaleBtn(Icons.add, () {
                        setState(() {
                          double s = _elementScales[id] ?? 1.0;
                          s = (s + 0.1).clamp(0.5, 3.0);
                          _elementScales[id] = s;
                        });
                      }),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScaleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black54),
          boxShadow: [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 2,
              offset: Offset(1, 1),
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: Colors.black),
      ),
    );
  }

  Widget _buildConnectionBadge(bool isConnected) {
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isConnected
              ? Colors.green.withOpacity(0.2)
              : Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isConnected ? Colors.green : Colors.red),
        ),
        child: Text(
          isConnected ? "CONNECTED" : "DISCONNECTED",
          style: TextStyle(
            color: isConnected ? Colors.greenAccent : Colors.redAccent,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildOdomItem(
    IconData icon,
    String value, {
    Color color = Colors.white,
  }) {
    return MergeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 14),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: "monospace",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return MergeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleBtn(
    Color color,
    IconData icon,
    VoidCallback onTap, {
    bool isBig = false,
  }) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 6,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: isBig ? 70 : 50,
          height: isBig ? 70 : 50,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: isBig ? 32 : 24),
        ),
      ),
    );
  }

  Widget _buildPickupPopup(RobotProvider provider) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.precision_manufacturing,
            color: Colors.orangeAccent,
            size: 40,
          ),
          const SizedBox(height: 16),
          const Text(
            "Pickup Request",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Do you want to pickup the can?",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPopupButton(
                label: "NO",
                color: Colors.redAccent,
                onPressed: () {
                  if (_isEditMode) return;
                  _robotService.sendPickupResponse(false);
                  provider.setPickupRequested(false);
                  _showNotification("Pickup Rejected", isError: true);
                },
              ),
              _buildPopupButton(
                label: "YES",
                color: Colors.green,
                onPressed: () {
                  if (_isEditMode) return;
                  _robotService.sendPickupResponse(true);
                  provider.setPickupRequested(false);
                  _showNotification("Pickup Accepted");
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPopupButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildPickupButton(RobotProvider provider) {
    bool isEnabled = provider.isTrashDetected;
    bool isInteractive = isEnabled && !_isEditMode;
    return ElevatedButton.icon(
      onPressed: isInteractive
          ? () {
              // Send the single correct confirmation message
              _robotService.sendTrashPickupConfirm();
              _showNotification("Trash Pickup Confirmed");
            }
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled ? Colors.greenAccent : Colors.grey.shade800,
        foregroundColor: Colors.black,
        disabledBackgroundColor: Colors.grey.shade800,
        disabledForegroundColor: Colors.white24,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
      icon: const Icon(FontAwesomeIcons.trashCan, size: 18),
      label: const Text(
        "PICKUP TRASH",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
