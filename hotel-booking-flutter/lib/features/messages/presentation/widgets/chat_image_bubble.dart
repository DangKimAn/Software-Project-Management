import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_image.dart';

/// Standardized chat image frame distinguishing between:
/// 1. Ảnh ngang (Landscape): Frame chuẩn 240 x 160 (tỷ lệ 3:2 / 16:10)
/// 2. Ảnh dọc (Portrait): Frame chuẩn 185 x 245 (tỷ lệ 3:4)
/// All images fit cleanly into their respective uniform frames with smooth rounded corners.
class ChatImageBubble extends StatefulWidget {
  final String imageUrl;
  final BorderRadius borderRadius;
  final VoidCallback onTap;
  final double maxWidth;

  const ChatImageBubble({
    super.key,
    required this.imageUrl,
    required this.borderRadius,
    required this.onTap,
    this.maxWidth = 260,
  });

  /// In-memory cache for resolved orientation to avoid layout recalculation
  static final Map<String, bool> _isLandscapeCache = {};

  @override
  State<ChatImageBubble> createState() => _ChatImageBubbleState();
}

class _ChatImageBubbleState extends State<ChatImageBubble> {
  bool? _isLandscape;

  @override
  void initState() {
    super.initState();
    _isLandscape = ChatImageBubble._isLandscapeCache[widget.imageUrl];
    if (_isLandscape == null) {
      _resolveDimensions();
    }
  }

  @override
  void didUpdateWidget(covariant ChatImageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _isLandscape = ChatImageBubble._isLandscapeCache[widget.imageUrl];
      if (_isLandscape == null) {
        _resolveDimensions();
      }
    }
  }

  void _resolveDimensions() {
    final raw = widget.imageUrl.trim();
    if (raw.isEmpty) {
      _isLandscape = true;
      return;
    }

    final assetPath = AppImage.resolveLocalAsset(raw);
    final ImageProvider provider = assetPath != null
        ? AssetImage(assetPath) as ImageProvider
        : NetworkImage(AppImage.resolveNetworkUrl(raw)) as ImageProvider;

    final stream = provider.resolve(const ImageConfiguration());
    ImageStreamListener? listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        final w = info.image.width;
        final h = info.image.height;
        final isLandscape = w >= h;
        ChatImageBubble._isLandscapeCache[widget.imageUrl] = isLandscape;
        if (mounted) {
          setState(() {
            _isLandscape = isLandscape;
          });
        }
        if (listener != null) {
          stream.removeListener(listener);
        }
      },
      onError: (dynamic error, StackTrace? stackTrace) {
        if (mounted) {
          setState(() {
            _isLandscape = true;
          });
        }
      },
    );
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = _isLandscape ?? true;

    // Standardized frame dimensions
    // Ảnh ngang: width 240, height 160
    // Ảnh dọc: width 185, height 245
    final double targetWidth = isLandscape
        ? widget.maxWidth.clamp(200.0, 240.0)
        : widget.maxWidth.clamp(160.0, 185.0);

    final double targetHeight = isLandscape ? 160.0 : 245.0;

    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Container(
          width: targetWidth,
          height: targetHeight,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: widget.borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: AppImage(
            url: widget.imageUrl,
            width: targetWidth,
            height: targetHeight,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
