import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../providers/receipts_provider.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/constants/app_constants.dart';

class ReceiptCaptureScreen extends ConsumerStatefulWidget {
  const ReceiptCaptureScreen({super.key});

  @override
  ConsumerState<ReceiptCaptureScreen> createState() =>
      _ReceiptCaptureScreenState();
}

class _ReceiptCaptureScreenState extends ConsumerState<ReceiptCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  Uint8List? _capturedImage;

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    var image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image');

    // Resize if needed
    if (image.width > AppConstants.maxImageDimension ||
        image.height > AppConstants.maxImageDimension) {
      image = img.copyResize(
        image,
        width: image.width > image.height
            ? AppConstants.maxImageDimension
            : null,
        height: image.height >= image.width
            ? AppConstants.maxImageDimension
            : null,
        interpolation: img.Interpolation.linear,
      );
    }

    // Compress
    int quality = AppConstants.jpegQuality;
    var compressed =
        Uint8List.fromList(img.encodeJpg(image, quality: quality));

    while (compressed.length > AppConstants.maxImageSizeBytes &&
        quality > AppConstants.minJpegQuality) {
      quality -= 5;
      compressed =
          Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }

    return compressed;
  }

  Future<void> _captureFromCamera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (file != null) {
      await _processImage(await file.readAsBytes(), file.name);
    }
  }

  Future<void> _pickFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (file != null) {
      await _processImage(await file.readAsBytes(), file.name);
    }
  }

  Future<void> _processImage(Uint8List bytes, String filename) async {
    setState(() {
      _isProcessing = true;
      _capturedImage = bytes;
    });

    try {
      final compressed = await _compressImage(bytes);
      final receipt = await ref
          .read(receiptsProvider.notifier)
          .uploadAndProcessReceipt(compressed, filename);

      if (receipt != null && mounted) {
        context.go('/review-receipt', extra: {
          'receipt': receipt,
        });
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to process receipt: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_capturedImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _capturedImage!,
                        height: 300,
                        fit: BoxFit.contain,
                      ),
                    ),
                  const SizedBox(height: 32),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Processing receipt...',
                    style: context.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Extracting items with AI',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 80,
                      color: context.colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Capture Receipt',
                      style: context.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Take a photo or select from gallery.\nAI will extract all line items automatically.',
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 48),
                    ElevatedButton.icon(
                      onPressed: _captureFromCamera,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Choose from Gallery'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
