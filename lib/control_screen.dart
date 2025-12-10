// control_screen.dart
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_gstreamer_player/flutter_gstreamer_player.dart';

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

  // --- 2. Notification State ---
  final List<HudNotification> _notifications = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    _robotService = RobotService(context.read<RobotProvider>());
    final provider = context.read<RobotProvider>();
    _notifSubscription = provider.notificationStream.listen((event) {
      // When a signal comes in, trigger the UI logic
      if (mounted) {
        _showNotification(event.message, isError: event.isError);
      }
    });
    _connect();
  }

  @override
  void dispose() {
    _robotService.disconnect();
    super.dispose();
  }

  // --- 3. Notification Logic ---
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
      _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 300));
    });

    // Auto dismiss after 5 seconds
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
              (context, animation) => _buildNotificationItem(removedItem, animation),
          duration: const Duration(milliseconds: 300),
        );
      });
    }
  }

  // --- 4. Notification Widget Builder ---
  Widget _buildNotificationItem(HudNotification item, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Container(
            // Fixed width helps keep the stack tidy on the right side
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
                )
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    final provider = context.watch<RobotProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // --- 1. VIDEO BACKGROUND ---
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const GstPlayer(
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
                // Gradient for text readability
                Container(
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
              ],
            ),
          ),

          // --- 2. HUD INTERFACE ---
          SafeArea(
            child: Column(
              children: [
                // === TOP BAR ===
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Badge
                      Column(
                        children: [
                          _buildConnectionBadge(provider.isConnected),
                          const SizedBox(height: 10),
                          IconButton(
                            icon: const Icon(Icons.settings, color: Colors.white70),
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
                        ],
                      ),

                      const Spacer(),

                      // Data Display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildOdomItem(Icons.speed, "${provider.odomLinearX.toStringAsFixed(2)} m/s"),
                            const SizedBox(width: 12),
                            Container(width: 1, height: 15, color: Colors.white24),
                            const SizedBox(width: 12),
                            _buildOdomItem(Icons.battery_std, "${provider.batteryLevel.toInt()}%",
                                color: provider.batteryLevel < 20 ? Colors.red : Colors.green),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Map Widget (Top Right)
                      Container(
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
                    ],
                  ),
                ),

                const Spacer(),

                // === BOTTOM CONTROLS ===
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // --- Left Joystick ---
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("THROTTLE", style: TextStyle(color: Colors.white38, fontSize: 10)),
                          const SizedBox(height: 8),
                          Joystick(
                            mode: JoystickMode.vertical,
                            listener: (details) {
                              setState(() => _cmdLinear = -details.y);
                            },
                            // Custom Base
                            base: Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white30, width: 2),
                              ),
                            ),
                            // Custom Stick
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
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // --- Center Console ---
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ToggleSwitch(
                              initialLabelIndex: _modeIndex,
                              minWidth: 40.0,
                              minHeight: 30.0,
                              cornerRadius: 20.0,
                              activeBgColors: const [[Colors.cyan], [Colors.orange], [Colors.purple]],
                              activeFgColor: Colors.white,
                              inactiveBgColor: Colors.grey.shade800,
                              inactiveFgColor: Colors.white54,
                              totalSwitches: 3,
                              icons: const [FontAwesomeIcons.gamepad, FontAwesomeIcons.robot, FontAwesomeIcons.sliders],
                              onToggle: (index) {
                                setState(() => _modeIndex = index ?? 0);
                                _robotService.setMode(index ?? 0);
                                _showNotification("Mode switched: ${index == 0 ? 'Manual' : index == 1 ? 'Auto' : 'Calibration'}");
                              },
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                _buildCircleBtn(Colors.green, Icons.play_arrow, () {
                                  setState(() { _cmdLinear = 0; _cmdAngular = 0; });
                                  _robotService.sendStart();
                                  _showNotification("Robot Started");
                                }),
                                const SizedBox(width: 20),
                                _buildCircleBtn(Colors.red, Icons.stop, () {
                                  setState(() { _cmdLinear = 0; _cmdAngular = 0; });
                                  _robotService.sendImmediateStop();
                                  _showNotification("Emergency Stop", isError: true);
                                }, isBig: true),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // --- Right Joystick ---
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("STEERING", style: TextStyle(color: Colors.white38, fontSize: 10)),
                          const SizedBox(height: 8),
                          Joystick(
                            mode: JoystickMode.horizontal,
                            listener: (details) {
                              setState(() => _cmdAngular = -details.x);
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
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- 5. NOTIFICATION STACK OVERLAY ---
          Positioned(
            top: 150, // Starts below the Map Widget (which is approx 130-140px tall with padding)
            right: 16,
            bottom: 200, // Leave enough space so it doesn't overlap joystick area
            child: SizedBox(
              width: 260,
              child: AnimatedList(
                key: _listKey,
                initialItemCount: _notifications.length,
                itemBuilder: (context, index, animation) {
                  return _buildNotificationItem(_notifications[index], animation);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionBadge(bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
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
    );
  }

  Widget _buildOdomItem(IconData icon, String value, {Color color = Colors.white}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildCircleBtn(Color color, IconData icon, VoidCallback onTap, {bool isBig = false}) {
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
}