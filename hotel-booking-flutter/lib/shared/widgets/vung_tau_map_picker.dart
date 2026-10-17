import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../app/theme/app_colors.dart';
import '../animations/source_animations.dart';

class VungTauLocationGroup {
  final String key;
  final String id;
  final String label;
  final String subtitle;
  final double lat;
  final double lng;

  const VungTauLocationGroup({
    required this.key,
    String? id,
    required this.label,
    required this.subtitle,
    required this.lat,
    required this.lng,
  }) : id = id ?? key;
}

class VungTauMapConstants {
  VungTauMapConstants._();

  static const double minLat = 10.28;
  static const double maxLat = 10.50;
  static const double minLng = 107.01;
  static const double maxLng = 107.26;

  static const double defaultLat = 10.3460;
  static const double defaultLng = 107.0840;
  static const int defaultRadiusMeters = 800;

  static bool isWithinBounds(double lat, double lng) {
    return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
  }

  static ({double lat, double lng}) clampToBounds(double lat, double lng) {
    return (
      lat: lat.clamp(minLat, maxLat),
      lng: lng.clamp(minLng, maxLng),
    );
  }

  /// Exact 8 canonical location groups from
  /// `Source goc/backend/src/common/vung-tau-location-groups.ts` and
  /// `Source goc/frontend/src/data/vungTauLocationGroups.ts`.
  static const List<VungTauLocationGroup> locationGroups = [
    VungTauLocationGroup(
      key: 'bai_sau',
      id: 'bai-sau',
      label: 'Bãi Sau',
      subtitle:
          'Thùy Vân, Phan Chu Trinh, Phó Đức Chính, Hoàng Hoa Thám, Võ Thị Sáu, La Văn Cầu, Lê Hồng Phong, Đồi Ngọc Tước, Hồ Quý Ly, Lạc Long Quân, Tô Hiến Thành, Á Châu, Bàu Sen',
      lat: 10.3396,
      lng: 107.0942,
    ),
    VungTauLocationGroup(
      key: 'bai_truoc',
      id: 'bai-truoc',
      label: 'Bãi Trước',
      subtitle:
          'Trần Phú, Quang Trung, Hạ Long, Lê Quý Đôn, Thủ Khoa Huân, Lý Tự Trọng, Nguyễn Du, Ba Cu',
      lat: 10.3468,
      lng: 107.0746,
    ),
    VungTauLocationGroup(
      key: 'long_cung',
      id: 'long-cung',
      label: 'Long Cung',
      subtitle: 'Long Cung, D5, Thùy Dương, Hà Huy Tập',
      lat: 10.3695,
      lng: 107.1204,
    ),
    VungTauLocationGroup(
      key: 'chi_linh',
      id: 'chi-linh',
      label: 'Chí Linh',
      subtitle: 'Chí Linh, Bình Minh, Nguyễn Hữu Cảnh, Khu đô thị Chí Linh',
      lat: 10.3780,
      lng: 107.1120,
    ),
    VungTauLocationGroup(
      key: 'thuy_tien',
      id: 'thuy-tien',
      label: 'Thủy Tiên',
      subtitle: 'Thủy Tiên, Đường 3/2 ven biển, Khu du lịch Thủy Tiên',
      lat: 10.3735,
      lng: 107.1165,
    ),
    VungTauLocationGroup(
      key: 'trung_tam',
      id: 'trung-tam',
      label: 'Trung tâm',
      subtitle:
          'Lê Hồng Phong, Nguyễn Thái Học, Trương Công Định, Nguyễn An Ninh, Ba Cu, Lý Thường Kiệt',
      lat: 10.3540,
      lng: 107.0840,
    ),
    VungTauLocationGroup(
      key: 'tran_phu',
      id: 'tran-phu',
      label: 'Trần Phú',
      subtitle: 'Trần Phú, Bãi Dâu',
      lat: 10.3672,
      lng: 107.0628,
    ),
    VungTauLocationGroup(
      key: 'thuy_van',
      id: 'thuy-van',
      label: 'Thùy Vân',
      subtitle: 'Thùy Vân',
      lat: 10.3365,
      lng: 107.0928,
    ),
  ];

  /// Finds a [VungTauLocationGroup] by `key` (`bai_sau`), `id` (`bai-sau`), or `label` (`Bãi Sau`).
  static VungTauLocationGroup? findLocationGroup(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim().toLowerCase();
    for (final group in locationGroups) {
      if (group.key.toLowerCase() == trimmed ||
          group.id.toLowerCase() == trimmed ||
          group.label.toLowerCase() == trimmed) {
        return group;
      }
    }
    return null;
  }

  /// Resolves any location group identifier (`bai_sau`, `bai-sau`, `Bãi Sau`)
  /// into the canonical backend `LocationGroupName` (`"Bãi Sau"`, `"Bãi Trước"`, etc.)
  /// required by `listings.validator.ts` (`isValidLocationGroup`).
  static String? resolveLocationGroupName(String? raw) {
    final group = findLocationGroup(raw);
    return group?.label;
  }

  /// Resolves any location group identifier into its canonical `areaKey` (`bai_sau`, etc.).
  static String? resolveLocationGroupKey(String? raw) {
    final group = findLocationGroup(raw);
    return group?.key;
  }

  static const Map<String, ({double lat, double lng})> wardCenters = {
    'Phường 1': (lat: 10.3485, lng: 107.0742),
    'Phường 2': (lat: 10.3328, lng: 107.0862),
    'Phường 3': (lat: 10.3490, lng: 107.0825),
    'Phường 4': (lat: 10.3552, lng: 107.0790),
    'Phường 5': (lat: 10.3680, lng: 107.0645),
    'Phường 7': (lat: 10.3635, lng: 107.0840),
    'Phường 8': (lat: 10.3545, lng: 107.0940),
    'Phường 9': (lat: 10.3720, lng: 107.0820),
    'Phường 10': (lat: 10.3820, lng: 107.1150),
    'Phường 11': (lat: 10.4020, lng: 107.1310),
    'Phường 12': (lat: 10.4220, lng: 107.1560),
    'Phường Thắng Tam': (lat: 10.3410, lng: 107.0920),
    'Phường Thắng Nhì': (lat: 10.3650, lng: 107.0750),
    'Phường Thắng Nhất': (lat: 10.3830, lng: 107.0920),
    'Phường Nguyễn An Ninh': (lat: 10.3660, lng: 107.0990),
    'Phường Rạch Dừa': (lat: 10.3950, lng: 107.1080),
    'Xã Long Sơn': (lat: 10.4520, lng: 107.0450),
  };
}

/// Interactive Slippy Tile Map Picker for Vũng Tàu (port of LocationMapPicker.tsx & VungTauMapBounds.tsx).
/// Renders OpenStreetMap / Carto Voyager tiles, 800m radius indicator circle, and MapMarkerPulse pin.
class VungTauMapPicker extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final int radiusMeters;
  final double height;
  final bool showRadiusCircle;
  final bool showPresetChips;
  final void Function(double lat, double lng, String? label)? onLocationChanged;

  const VungTauMapPicker({
    super.key,
    this.initialLat = VungTauMapConstants.defaultLat,
    this.initialLng = VungTauMapConstants.defaultLng,
    this.radiusMeters = VungTauMapConstants.defaultRadiusMeters,
    this.height = 300,
    this.showRadiusCircle = true,
    this.showPresetChips = true,
    this.onLocationChanged,
  });

  @override
  State<VungTauMapPicker> createState() => _VungTauMapPickerState();
}

class _VungTauMapPickerState extends State<VungTauMapPicker> {
  late double _lat;
  late double _lng;
  int _zoom = 14; // 12..16

  @override
  void initState() {
    super.initState();
    final clamped = VungTauMapConstants.clampToBounds(
      widget.initialLat,
      widget.initialLng,
    );
    _lat = clamped.lat;
    _lng = clamped.lng;
  }

  @override
  void didUpdateWidget(covariant VungTauMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.initialLat - widget.initialLat).abs() > 0.0001 ||
        (oldWidget.initialLng - widget.initialLng).abs() > 0.0001) {
      final clamped = VungTauMapConstants.clampToBounds(
        widget.initialLat,
        widget.initialLng,
      );
      _lat = clamped.lat;
      _lng = clamped.lng;
    }
  }

  double _lngToTileX(double lng, int zoom) {
    return ((lng + 180.0) / 360.0) * (1 << zoom);
  }

  double _latToTileY(double lat, int zoom) {
    final latRad = lat * math.pi / 180.0;
    return (1.0 -
            math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
        2.0 *
        (1 << zoom);
  }

  double _tileXToLng(double tileX, int zoom) {
    return tileX / (1 << zoom) * 360.0 - 180.0;
  }

  double _tileYToLat(double tileY, int zoom) {
    final n = math.pi - 2.0 * math.pi * tileY / (1 << zoom);
    return 180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
  }

  void _handleMapTap(TapUpDetails details, Size size) {
    final centerTileX = _lngToTileX(_lng, _zoom);
    final centerTileY = _latToTileY(_lat, _zoom);

    final dxPixels = details.localPosition.dx - size.width / 2;
    final dyPixels = details.localPosition.dy - size.height / 2;

    final tappedTileX = centerTileX + dxPixels / 256.0;
    final tappedTileY = centerTileY + dyPixels / 256.0;

    final rawLat = _tileYToLat(tappedTileY, _zoom);
    final rawLng = _tileXToLng(tappedTileX, _zoom);
    final clamped = VungTauMapConstants.clampToBounds(rawLat, rawLng);

    setState(() {
      _lat = clamped.lat;
      _lng = clamped.lng;
    });
    widget.onLocationChanged?.call(
      _lat,
      _lng,
      'Vị trí bản đồ (${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)})',
    );
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final centerTileX = _lngToTileX(_lng, _zoom);
    final centerTileY = _latToTileY(_lat, _zoom);

    final nextTileX = centerTileX - details.delta.dx / 256.0;
    final nextTileY = centerTileY - details.delta.dy / 256.0;

    final rawLat = _tileYToLat(nextTileY, _zoom);
    final rawLng = _tileXToLng(nextTileX, _zoom);
    final clamped = VungTauMapConstants.clampToBounds(rawLat, rawLng);

    setState(() {
      _lat = clamped.lat;
      _lng = clamped.lng;
    });
    widget.onLocationChanged?.call(
      _lat,
      _lng,
      'Vị trí bản đồ (${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)})',
    );
  }

  double _metersToPixels(int meters, double lat, int zoom) {
    final metersPerPixel =
        156543.03392 * math.cos(lat * math.pi / 180.0) / (1 << zoom);
    return (meters / metersPerPixel).clamp(24.0, 140.0);
  }

  @override
  Widget build(BuildContext context) {
    final radiusPx = _metersToPixels(widget.radiusMeters, _lat, _zoom);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final effectiveHeight =
        screenWidth < 380 ? math.min(widget.height, 220.0) : widget.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showPresetChips) ...[
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: VungTauMapConstants.locationGroups.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final group = VungTauMapConstants.locationGroups[index];
                final isSelected = (_lat - group.lat).abs() < 0.005 &&
                    (_lng - group.lng).abs() < 0.005;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _lat = group.lat;
                      _lng = group.lng;
                    });
                    widget.onLocationChanged?.call(
                      group.lat,
                      group.lng,
                      group.label,
                    );
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color:
                            isSelected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Text(
                      group.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color:
                            isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: effectiveHeight,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EEF2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                final centerTileX = _lngToTileX(_lng, _zoom);
                final centerTileY = _latToTileY(_lat, _zoom);
                final baseTileX = centerTileX.floor();
                final baseTileY = centerTileY.floor();
                final offsetX = (centerTileX - baseTileX) * 256.0;
                final offsetY = (centerTileY - baseTileY) * 256.0;

                final tiles = <Widget>[];
                for (int dx = -2; dx <= 2; dx++) {
                  for (int dy = -2; dy <= 2; dy++) {
                    final tx = baseTileX + dx;
                    final ty = baseTileY + dy;
                    final left = size.width / 2 - offsetX + dx * 256.0;
                    final top = size.height / 2 - offsetY + dy * 256.0;
                    final tileUrl =
                        'https://a.basemaps.cartocdn.com/rastertiles/voyager/$_zoom/$tx/$ty.png';
                    tiles.add(
                      Positioned(
                        left: left,
                        top: top,
                        width: 256,
                        height: 256,
                        child: Image.network(
                          tileUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => CustomPaint(
                            painter: _FallbackMapGridPainter(),
                          ),
                        ),
                      ),
                    );
                  }
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _handleMapTap(d, size),
                  onPanUpdate: _handlePanUpdate,
                  child: Stack(
                    children: [
                      ...tiles,
                      if (widget.showRadiusCircle)
                        Center(
                          child: IgnorePointer(
                            child: Container(
                              width: radiusPx * 2,
                              height: radiusPx * 2,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.transparent,
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Center Marker with MapMarkerPulse animation
                      const Center(
                        child: IgnorePointer(
                          child: MapMarkerPulse(),
                        ),
                      ),
                      // Top-left coordinates & radius badge
                      Positioned(
                        top: 10,
                        left: 10,
                        right: 10,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              'Vũng Tàu • ${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)}'
                              '${widget.showRadiusCircle ? ' (Bán kính ${widget.radiusMeters}m)' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Zoom controls (strict monochrome stroke icons, 48x48 touch target)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: _zoom < 16
                                    ? () => setState(() => _zoom++)
                                    : null,
                                child: const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Center(
                                    child: Icon(
                                      LucideIcons.plus,
                                      size: 16,
                                      color: AppColors.iconStrong,
                                    ),
                                  ),
                                ),
                              ),
                              const Divider(height: 1, color: AppColors.border),
                              InkWell(
                                onTap: _zoom > 12
                                    ? () => setState(() => _zoom--)
                                    : null,
                                child: const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Center(
                                    child: Icon(
                                      LucideIcons.minus,
                                      size: 16,
                                      color: AppColors.iconStrong,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FallbackMapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFEAF0F4);
    canvas.drawRect(Offset.zero & size, bg);
    final line = Paint()
      ..color = const Color(0xFFD6E0E8)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
