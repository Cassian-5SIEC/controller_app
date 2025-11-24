import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class GstPlayerTextureController {
  static const MethodChannel _channel =
  MethodChannel('flutter_gstreamer_player');

  late int textureId;
  static int _id = 0;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<int> initialize(String pipeline) async {
    // Increment id BEFORE sending
    _id++;

    textureId = await _channel.invokeMethod('PlayerRegisterTexture', {
      'pipeline': pipeline,
      'playerId': _id,
    });

    _initialized = true;
    return textureId;
  }

  Future<void> dispose() async {
    if (_initialized) {
      await _channel.invokeMethod('dispose', {
        'textureId': textureId,
      });
      _initialized = false;
    }
  }
}

class GstPlayer extends StatefulWidget {
  final String pipeline;

  const GstPlayer({Key? key, required this.pipeline}) : super(key: key);

  @override
  State<GstPlayer> createState() => _GstPlayerState();
}

class _GstPlayerState extends State<GstPlayer> {
  final GstPlayerTextureController _controller = GstPlayerTextureController();

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(GstPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Pipeline changed: reinitialize
    if (widget.pipeline != oldWidget.pipeline) {
      _initializeController();
    }
  }

  Future<void> _initializeController() async {
    await _controller.dispose();        // clean previous if any
    await _controller.initialize(widget.pipeline);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isInitialized) {
      return const SizedBox.shrink(); // avoids null build crash
    }

    final platform = Theme.of(context).platform;

    switch (platform) {
      case TargetPlatform.android:
      case TargetPlatform.linux:
        return Texture(textureId: _controller.textureId);

      case TargetPlatform.iOS:
        return UiKitView(
          viewType: _controller.textureId.toString(),
          layoutDirection: TextDirection.ltr,
          creationParams: const {},
          creationParamsCodec: StandardMessageCodec(),
        );

      default:
        return const Text("Unsupported platform");
    }
  }
}
