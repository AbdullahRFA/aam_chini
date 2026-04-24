import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class MangoClassifier {
  Interpreter? _interpreter;
  List<String>? _labels;

  Future<void> loadModel() async {
    try {
      // 1. Load labels
      final labelData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelData.split('\n').where((s) => s.isNotEmpty).toList();

      // 2. Load interpreter with modern options
      _interpreter = await Interpreter.fromAsset('assets/mango_model_v3.tflite');

      print("✅ AmmChini Brain Ready: ${_labels?.length} varieties loaded");
    } catch (e) {
      print("❌ Model Load Error: $e");
    }
  }

  Future<Map<String, dynamic>> predictFromFile(File imageFile) async {
    if (_interpreter == null || _labels == null) {
      return {"label": "Initializing...", "confidence": 0.0};
    }

    try {
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) throw Exception("Decode Error");

      // Match your Python IMG_SIZE
      final img.Image resizedImage = img.copyResize(originalImage, width: 224, height: 224);

      // Convert to Float32 input tensor [1, 224, 224, 3]
      var input = _imageToByteListFloat32(resizedImage);

      // Output tensor shape [1, 10] for your 10 varieties
      var output = List.filled(1 * 10, 0.0).reshape([1, 10]);

      // Run inference
      _interpreter!.run(input, output);

      // Extract results
      double maxScore = -1.0;
      int maxIdx = -1;
      for (int i = 0; i < 10; i++) {
        if (output[0][i] > maxScore) {
          maxScore = output[0][i];
          maxIdx = i;
        }
      }

      return {
        "label": _labels![maxIdx].trim(),
        "confidence": maxScore * 100,
      };
    } catch (e) {
      print("🔮 Inference Error: $e");
      return {"label": "Analysis Failed", "confidence": 0.0};
    }
  }

  Uint8List _imageToByteListFloat32(img.Image image) {
    var convertedBytes = Float32List(1 * 224 * 224 * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        var pixel = image.getPixel(x, y);
        // MobileNetV3 takes raw RGB [0-255]
        buffer[pixelIndex++] = pixel.r.toDouble();
        buffer[pixelIndex++] = pixel.g.toDouble();
        buffer[pixelIndex++] = pixel.b.toDouble();
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  void dispose() {
    _interpreter?.close();
  }
}