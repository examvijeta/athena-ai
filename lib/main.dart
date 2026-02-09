import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'src/athena_app.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Error initializing cameras: $e');
    cameras = [];
  }
  runApp(const AthenaApp());
}
