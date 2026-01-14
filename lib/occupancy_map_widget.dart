import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'robot_provider.dart';

class OccupancyMapWidget extends StatelessWidget {
  const OccupancyMapWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<RobotProvider>(
      builder: (context, provider, child) {
        if (provider.mapData.isEmpty) {
          return Container(
            color: Colors.black12,
            child: const Center(
              child: Text(
                "Waiting for Map...",
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        return Container(
          color: Colors.black.withOpacity(0.5), // Background for the map area
          child: CustomPaint(
            painter: MapPainter(
              width: provider.mapWidth,
              height: provider.mapHeight,
              data: provider.mapData,
              carYaw: provider.mapCarYaw,
            ),
            // Ensure the widget takes up available space but maintains aspect ratio if needed
            child: Container(),
          ),
        );
      },
    );
  }
}

class MapPainter extends CustomPainter {
  final int width;
  final int height;
  final List<int> data;
  final double carYaw;

  MapPainter({
    required this.width,
    required this.height,
    required this.data,
    required this.carYaw,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || width == 0 || height == 0) return;

    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Calculate size of each cell to fit the widget area
    final double cellWidth = size.width / width;
    final double cellHeight = size.height / height;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // Index in the 1D array
        int index = y * width + x;
        if (index >= data.length) break;

        int value = data[index];

        // --- Color Logic ---
        // -1 = Unknown (Gray)
        // 0 = Free (White/Transparent)
        // 100 = Occupied (Black/Red)
        // 1-99 = Probabilities

        if (value == -1) {
          // Optional: Don't draw unknown to keep it transparent,
          // or draw gray:
          paint.color = Colors.grey.withOpacity(0.3);
          canvas.drawRect(
            Rect.fromLTWH(x * cellWidth, y * cellHeight, cellWidth, cellHeight),
            paint,
          );
        } else if (value > 50) {
          // Occupied (Wall/Obstacle)
          paint.color = Colors.black;
          canvas.drawRect(
            Rect.fromLTWH(x * cellWidth, y * cellHeight, cellWidth, cellHeight),
            paint,
          );
        } else if (value >= 0 && value <= 50) {
          // Free space - usually we leave it transparent to see the video behind
          // or draw it white/green
          // CHANGED: From green to white/grey
          paint.color = Colors.white.withOpacity(0.2);
          canvas.drawRect(
            Rect.fromLTWH(x * cellWidth, y * cellHeight, cellWidth, cellHeight),
            paint,
          );
        }
      }
    }

    // --- Draw Car Icon ---
    _drawCar(canvas, size.width / 2, size.height / 2, size.width * 0.1, carYaw);
  }

  void _drawCar(Canvas canvas, double x, double y, double size, double yaw) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(
      -yaw,
    ); // Rotation en radians (inversée pour correspondre au sens trigo/horaire)

    // Le dessin se fait maintenant autour de (0,0)
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    // Draw a simple triangle pointing up
    final path = Path();
    path.moveTo(0, -size / 2); // Top (relative to 0,0)
    path.lineTo(-size / 2, size / 2); // Bottom Left
    path.lineTo(size / 2, size / 2); // Bottom Right
    path.close();

    canvas.drawPath(path, paint);

    // Optional: Add a border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) {
    // Repaint if data or yaw changes
    return oldDelegate.data != data || oldDelegate.carYaw != carYaw;
  }
}
