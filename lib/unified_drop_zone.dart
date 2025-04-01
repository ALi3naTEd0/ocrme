import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

class UnifiedDropZone extends StatefulWidget {
  final Function(File file) onFileDropped;
  final Widget child;
  final double height;
  final double width;

  const UnifiedDropZone({
    Key? key,
    required this.onFileDropped,
    required this.child,
    this.height = 200,
    this.width = double.infinity,
  }) : super(key: key);

  @override
  State<UnifiedDropZone> createState() => _UnifiedDropZoneState();
}

class _UnifiedDropZoneState extends State<UnifiedDropZone> {
  final _logger = Logger('UnifiedDropZone');
  bool _isDragging = false;
  DropzoneViewController? _controller;

  @override
  Widget build(BuildContext context) {
    // Use Desktop Drop for Linux
    if (Platform.isLinux) {
      return DropTarget(
        onDragDone: (details) async {
          try {
            if (details.files.isNotEmpty) {
              final file = File(details.files.first.path);
              widget.onFileDropped(file);
            }
          } catch (e) {
            _logger.severe('Error handling desktop drop: $e');
          }
        },
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        child: Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            border: Border.all(
              color: _isDragging ? Colors.blue : Colors.grey,
              width: 2.0,
            ),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: widget.child,
        ),
      );
    }
    // Use DropzoneView for Web, macOS, Windows
    else if (kIsWeb || Platform.isMacOS || Platform.isWindows) {
      return Stack(
        children: [
          Container(
            height: widget.height,
            width: widget.width,
            decoration: BoxDecoration(
              border: Border.all(
                color: _isDragging ? Colors.blue : Colors.grey,
                width: 2.0,
              ),
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          SizedBox(
            height: widget.height,
            width: widget.width,
            child: DropzoneView(
              onCreated: (controller) => _controller = controller,
              onDrop: (dynamic event) => _handleDropzoneFile(event),
              onHover: () => setState(() => _isDragging = true),
              onLeave: () => setState(() => _isDragging = false),
            ),
          ),
          SizedBox(
            height: widget.height,
            width: widget.width,
            child: widget.child,
          ),
        ],
      );
    }
    // Fallback for other platforms (Android, iOS)
    else {
      return Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey, width: 2.0),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: widget.child,
      );
    }
  }

  Future<void> _handleDropzoneFile(dynamic event) async {
    setState(() => _isDragging = false);

    try {
      if (_controller == null) {
        _logger.severe('Dropzone controller is null');
        return;
      }

      final bytes = await _controller!.getFileData(event);
      final name = await _controller!.getFilename(event);

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$name');
      await file.writeAsBytes(bytes);

      widget.onFileDropped(file);
      // Automatic OCR processing happens through onFileDropped callback
    } catch (e) {
      _logger.severe('Error handling dropzone file: $e');
    }
  }
}
