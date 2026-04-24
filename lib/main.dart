import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'mango_classifier.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  runApp(const AmmChiniApp());
}

class AmmChiniApp extends StatelessWidget {
  const AmmChiniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  final MangoClassifier _classifier = MangoClassifier();

  File? _capturedFile;
  String _resultLabel = "";
  double _confidence = 0.0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _classifier.loadModel();
    controller = CameraController(
      _cameras[0],
      ResolutionPreset.high, // Better resolution for static capture
      enableAudio: false,
    );
    await controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _captureAndProcess() async {
    if (controller == null || !controller!.value.isInitialized || _isProcessing) return;

    try {
      setState(() => _isProcessing = true);

      // 1. Take the picture
      final XFile photo = await controller!.takePicture();

      // 2. Run the AI process
      final result = await _classifier.predictFromFile(File(photo.path));

      setState(() {
        _capturedFile = File(photo.path);
        _resultLabel = result['label'];
        _confidence = result['confidence'];
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void _retake() {
    setState(() {
      _capturedFile = null;
      _resultLabel = "";
      _confidence = 0.0;
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    _classifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("AmmChini AI", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _capturedFile == null ? _buildCameraView() : _buildResultView(),
    );
  }

  // SCREEN 1: Camera UI
  Widget _buildCameraView() {
    return Stack(
      children: [
        Positioned.fill(child: CameraPreview(controller!)),

        // Guidance Box
        Center(
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.yellowAccent, width: 2),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),

        if (_isProcessing)
          const Center(child: CircularProgressIndicator(color: Colors.white)),

        // Capture Button
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: FloatingActionButton.large(
              onPressed: _isProcessing ? null : _captureAndProcess,
              backgroundColor: Colors.white,
              child: const Icon(Icons.camera_alt, color: Colors.green, size: 40),
            ),
          ),
        ),
      ],
    );
  }

  // SCREEN 2: Result UI
  Widget _buildResultView() {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(
                image: FileImage(_capturedFile!),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Identified Variety:", style: TextStyle(fontSize: 16, color: Colors.grey)),
                Text(
                  _resultLabel,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                Text(
                  "Confidence: ${_confidence.toStringAsFixed(1)}%",
                  style: TextStyle(fontSize: 18, color: Colors.green[300]),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _retake,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retake Photo", style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[800],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}