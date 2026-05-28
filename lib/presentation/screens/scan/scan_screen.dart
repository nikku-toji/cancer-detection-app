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

const _cancerGradients = {
  'skin': [Color(0xFF6D4C41), Color(0xFFBCAAA4)],
  'lung': [Color(0xFF1565C0), Color(0xFF42A5F5)],
  'breast': [Color(0xFFAD1457), Color(0xFFF48FB1)],
  'brain': [Color(0xFF4527A0), Color(0xFF9575CD)],
};

class ScanScreen extends ConsumerStatefulWidget {
  final String cancerType;
  const ScanScreen({super.key, required this.cancerType});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  File? _selectedImage;
  final _picker = ImagePicker();

  bool get _isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  Future<void> _pickImage([ImageSource source = ImageSource.gallery]) async {
    if (_isDesktop) {
      final file = await openFile(acceptedTypeGroups: [
        const XTypeGroup(label: 'Images', extensions: ['jpg', 'jpeg', 'png', 'bmp', 'tiff'])
      ]);
      if (file != null) setState(() => _selectedImage = File(file.path));
    } else {
      final picked = await _picker.pickImage(source: source, imageQuality: 95);
      if (picked != null) setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _runAnalysis() async {
    if (_selectedImage == null) return;
    await ref.read(scanProvider.notifier).analyze(
          cancerType: widget.cancerType, imageFile: _selectedImage!);
    final state = ref.read(scanProvider);
    if (state.scanState == ScanState.success && state.result != null) {
      if (mounted) context.push('/result', extra: state.result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanProvider);
    final isLoading = scanState.scanState == ScanState.loading;
    final gradColors = _cancerGradients[widget.cancerType]!;
    final cancerName = AppConstants.cancerNames[widget.cancerType]!;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: gradColors[0],
            flexibleSpace: FlexibleSpaceBar(
              title: Text('Scan: $cancerName',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Image drop zone
                GestureDetector(
                  onTap: isLoading ? null : () => _pickImage(),
                  child: AnimatedContainer(
                    duration: 300.ms,
                    height: 280,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _selectedImage != null
                            ? gradColors[0].withOpacity(0.5)
                            : Colors.grey.shade200,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.file(_selectedImage!, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    gradColors[0].withOpacity(0.1),
                                    gradColors[1].withOpacity(0.1),
                                  ]),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.add_photo_alternate_outlined,
                                    size: 52, color: gradColors[0]),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _isDesktop ? 'Click to browse image' : 'Tap to select image',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF37474F)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'JPG, PNG, BMP supported',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                            ],
                          ).animate().fadeIn(),
                  ),
                ),
                const SizedBox(height: 16),

                // Tips card
                if (_selectedImage == null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: gradColors[0].withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: gradColors[0].withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: gradColors[0], size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AppConstants.cancerDescriptions[widget.cancerType]!,
                            style: TextStyle(color: gradColors[0], fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 16),

                // Action buttons
                if (!_isDesktop)
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.camera_alt_rounded,
                          label: 'Camera',
                          color: gradColors[0],
                          onTap: isLoading ? null : () => _pickImage(ImageSource.camera),
                          outlined: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.photo_library_rounded,
                          label: 'Gallery',
                          color: gradColors[0],
                          onTap: isLoading ? null : () => _pickImage(ImageSource.gallery),
                          outlined: true,
                        ),
                      ),
                    ],
                  )
                else
                  _ActionButton(
                    icon: Icons.folder_open_rounded,
                    label: 'Browse Image File',
                    color: gradColors[0],
                    onTap: isLoading ? null : () => _pickImage(),
                    outlined: true,
                    fullWidth: true,
                  ),

                const SizedBox(height: 12),

                // Analyze button
                AnimatedContainer(
                  duration: 200.ms,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _selectedImage != null && !isLoading
                        ? LinearGradient(colors: gradColors)
                        : null,
                    color: _selectedImage == null || isLoading ? Colors.grey.shade300 : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _selectedImage != null && !isLoading
                        ? [BoxShadow(color: gradColors[0].withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))]
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: (_selectedImage != null && !isLoading) ? _runAnalysis : null,
                      child: Center(
                        child: isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                  const SizedBox(width: 12),
                                  Text('Analyzing...', style: TextStyle(
                                      color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_rounded,
                                      color: _selectedImage != null ? Colors.white : Colors.grey.shade500),
                                  const SizedBox(width: 8),
                                  Text('Analyze Image',
                                      style: TextStyle(
                                        color: _selectedImage != null ? Colors.white : Colors.grey.shade500,
                                        fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),

                if (scanState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(scanState.errorMessage!,
                        style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                  ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool outlined;
  final bool fullWidth;

  const _ActionButton({
    required this.icon, required this.label, required this.color,
    this.onTap, this.outlined = false, this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
