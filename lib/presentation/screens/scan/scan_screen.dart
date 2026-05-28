import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/scan_provider.dart';

class ScanScreen extends ConsumerStatefulWidget {
  final String cancerType;
  const ScanScreen({super.key, required this.cancerType});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  File? _selectedImage;
  final _picker = ImagePicker();

  // Detect if we're on desktop (macOS/Windows/Linux)
  bool get _isDesktop =>
      !kIsWeb &&
      (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  /// Pick image: use file_selector on desktop, image_picker on mobile
  Future<void> _pickImage([ImageSource source = ImageSource.gallery]) async {
    if (_isDesktop) {
      await _pickImageDesktop();
    } else {
      await _pickImageMobile(source);
    }
  }

  Future<void> _pickImageDesktop() async {
    const typeGroup = XTypeGroup(
      label: 'Images',
      extensions: ['jpg', 'jpeg', 'png', 'bmp', 'tiff'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file != null) {
      setState(() => _selectedImage = File(file.path));
    }
  }

  Future<void> _pickImageMobile(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 95,
    );
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _runAnalysis() async {
    if (_selectedImage == null) return;
    await ref.read(scanProvider.notifier).analyze(
          cancerType: widget.cancerType,
          imageFile: _selectedImage!,
        );
    final state = ref.read(scanProvider);
    if (state.scanState == ScanState.success && state.result != null) {
      if (mounted) context.push('/result', extra: state.result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanProvider);
    final isLoading = scanState.scanState == ScanState.loading;
    final cancerName = AppConstants.cancerNames[widget.cancerType]!;

    return Scaffold(
      appBar: AppBar(title: Text('Scan: $cancerName')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image preview area
            Expanded(
              child: GestureDetector(
                onTap: isLoading ? null : () => _pickImage(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.grey[300]!, width: 2),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 72,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _isDesktop
                                  ? 'Click to browse image file'
                                  : 'Tap to select image',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                AppConstants
                                    .cancerDescriptions[widget.cancerType]!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 12),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ).animate().fadeIn(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons — camera only shown on mobile
            if (!_isDesktop)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),

            if (_isDesktop)
              OutlinedButton.icon(
                onPressed: isLoading ? null : () => _pickImage(),
                icon: const Icon(Icons.folder_open),
                label: const Text('Browse Image File'),
              ),

            const SizedBox(height: 12),

            // Analyze button
            FilledButton.icon(
              onPressed:
                  (_selectedImage != null && !isLoading) ? _runAnalysis : null,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search),
              label: Text(isLoading ? 'Analyzing...' : 'Analyze Image'),
            ),

            if (scanState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  scanState.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
