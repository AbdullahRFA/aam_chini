import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart'; // Import Image Picker
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
  final ImagePicker _picker = ImagePicker(); // Initialize Picker

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
      ResolutionPreset.high,
      enableAudio: false,
    );
    await controller!.initialize();
    if (mounted) setState(() {});
  }

  // Handle Gallery Uploads
  Future<void> _pickAndProcessImage() async {
    if (_isProcessing) return;

    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      await _processImage(File(pickedFile.path));
    }
  }

  // Handle Real-time Camera Capture
  Future<void> _captureAndProcess() async {
    if (controller == null || !controller!.value.isInitialized || _isProcessing) return;

    final XFile photo = await controller!.takePicture();
    await _processImage(File(photo.path));
  }

  // Unified Processing Logic
  Future<void> _processImage(File file) async {
    try {
      setState(() => _isProcessing = true);

      final result = await _classifier.predictFromFile(file);

      setState(() {
        _capturedFile = file;
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

  Widget _buildCameraView() {
    return Stack(
      children: [
        Positioned.fill(child: CameraPreview(controller!)),

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

        // Bottom Controls
        Positioned(
          bottom: 40,
          left: 30,
          right: 30,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Gallery Button
              FloatingActionButton(
                heroTag: "gallery",
                onPressed: _isProcessing ? null : _pickAndProcessImage,
                backgroundColor: Colors.white,
                child: const Icon(Icons.photo_library, color: Colors.green),
              ),

              // Capture Button
              FloatingActionButton.large(
                heroTag: "capture",
                onPressed: _isProcessing ? null : _captureAndProcess,
                backgroundColor: Colors.white,
                child: const Icon(Icons.camera_alt, color: Colors.green, size: 40),
              ),

              // Placeholder for layout balance
              const SizedBox(width: 56),
            ],
          ),
        ),
      ],
    );
  }

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
                  label: const Text("Retake / New Photo", style: TextStyle(fontSize: 18)),
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