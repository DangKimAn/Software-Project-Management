import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../app/theme/app_colors.dart';
import '../animations/source_animations.dart';
import 'app_image.dart';

/// Mô hình cụm khu vực địa lý chuẩn tại thành phố biển Vũng Tàu (ví dụ Bãi Sau, Bãi Trước, Long Cung, Chí Linh).
class VungTauLocationGroup {
  /// Khóa định danh chuẩn dạng `snake_case` (ví dụ `'bai_sau'`).
  final String key;

  /// Mã định danh đường dẫn dạng `kebab-case` (ví dụ `'bai-sau'`).
  final String id;

  /// Tên hiển thị tiếng Việt chuẩn của khu vực (ví dụ `'Bãi Sau'`).
  final String label;

  /// Chuỗi liệt kê các tuyến đường tiêu biểu trực thuộc khu vực.
  final String subtitle;

  /// Vĩ độ tâm địa lý (`WGS84`) của khu vực.
  final double lat;

  /// Kinh độ tâm địa lý (`WGS84`) của khu vực.
  final double lng;

  /// Khởi tạo thông tin cụm khu vực Vũng Tàu `VungTauLocationGroup`.
  const VungTauLocationGroup({
    required this.key,
    String? id,
    required this.label,
    required this.subtitle,
    required this.lat,
    required this.lng,
  }) : id = id ?? key;
}

/// Tập hằng số biên địa lý, tâm phường/xã và danh mục 8 cụm khu vực du lịch chuẩn tại Vũng Tàu.
///
/// Cung cấp các phép kiểm tra và kẹp biên hộp giới hạn (`Bounding Box Clamping`) nhằm giữ
/// khung nhìn bản đồ luôn nằm gọn trong địa phận thành phố Vũng Tàu (`10.28..10.50` Bắc, `107.00..107.26` Đông).
class VungTauMapConstants {
  VungTauMapConstants._();

  /// Vĩ độ cực Nam của hộp giới hạn bản đồ Vũng Tàu (khu vực mũi Nghinh Phong / Bãi Sau).
  static const double minLat = 10.28;

  /// Vĩ độ cực Bắc của hộp giới hạn bản đồ Vũng Tàu (khu vực Long Sơn / cửa ngõ thành phố).
  static const double maxLat = 10.50;

  /// Kinh độ cực Tây của hộp giới hạn bản đồ Vũng Tàu (vịnh Gành Rái / Xã Long Sơn / Bãi Dâu).
  static const double minLng = 107.00;

  /// Kinh độ cực Đông của hộp giới hạn bản đồ Vũng Tàu (trục ven biển Chí Linh - Cửa Lấp).
  static const double maxLng = 107.26;

  /// Vĩ độ tâm mặc định của bản đồ Vũng Tàu khi chưa có tọa độ khởi tạo.
  static const double defaultLat = 10.3460;

  /// Kinh độ tâm mặc định của bản đồ Vũng Tàu khi chưa có tọa độ khởi tạo.
  static const double defaultLng = 107.0840;

  /// Bán kính tìm kiếm lân cận mặc định tính bằng mét (`800m`).
  static const int defaultRadiusMeters = 800;

  /// Kiểm tra cặp tọa độ `(lat, lng)` có nằm trọn trong hộp giới hạn địa lý Vũng Tàu hay không.
  static bool isWithinBounds(double lat, double lng) {
    return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
  }

  /// Kẹp cứng tọa độ `(lat, lng)` vào trong hộp giới hạn `[minLat, maxLat] x [minLng, maxLng]` của Vũng Tàu.
  ///
  /// Giải thuật kẹp biên hộp địa lý (Bounding-Box Coordinate Clamping):
  /// Ngăn người dùng kéo hoặc chạm chọn tọa độ trôi ra ngoài biển Đông hoặc lệch sang tỉnh thành khác.
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

  /// Bảng tọa độ tâm hành chính của các phường/xã thuộc thành phố Vũng Tàu phục vụ định vị dự phòng.
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

/// Bản đồ trượt tương tác chọn tọa độ và bán kính tìm kiếm tại Vũng Tàu sử dụng phép chiếu Web Mercator (`EPSG:3857`).
///
/// Giải thuật hình học bản đồ Slippy Tile & phép chiếu Web Mercator:
/// 1. **Không gian bản đồ mức phóng `z`**: Toàn thế giới được chia thành lưới `2^z x 2^z` mảnh ảnh (`tile`),
///    mỗi mảnh kích thước `256 x 256` điểm ảnh, tương ứng kích thước toàn cầu `2^z * 256` pixel.
/// 2. **Phép chiếu thuận `(lat, lng) -> (tileX, tileY)`**:
///    - Kinh độ `lng` ánh xạ tuyến tính: `tileX = ((lng + 180) / 360) * 2^z`.
///    - Vĩ độ `phi = lat * pi / 180` ánh xạ bảo góc Mercator:
///      `tileY = (1 - ln(tan(phi) + sec(phi)) / pi) / 2 * 2^z`, tương đương hằng đẳng thức lượng giác
///      `ln(tan(pi / 4 + phi / 2))`.
/// 3. **Phép chiếu ngược `(tileX, tileY) -> (lat, lng)`**:
///    - `lng = (tileX / 2^z) * 360 - 180`.
///    - Đặt `n = pi - 2 * pi * tileY / 2^z`, suy ra `phi = atan(sinh(n)) = 2 * atan(exp(n)) - pi / 2`,
///      đổi sang độ `lat = phi * 180 / pi`.
/// 4. **Tương tác chạm, kéo tâm, phóng thu và kẹp biên**: Mọi độ lệch điểm ảnh thao tác được quy đổi
///    theo tỷ lệ `256` pixel/tile quanh tâm khung nhìn, chiếu ngược ra `(lat, lng)` và kẹp chặt bởi
///    `VungTauMapConstants.clampToBounds`.
///
/// Interactive Slippy Tile Map Picker for Vũng Tàu (port of LocationMapPicker.tsx & VungTauMapBounds.tsx).
/// Renders OpenStreetMap / Carto Voyager tiles, 800m radius indicator circle, and MapMarkerPulse pin.
class VungTauMapPicker extends StatefulWidget {
  /// Vĩ độ khởi tạo ban đầu của tâm ghim tìm kiếm.
  final double initialLat;

  /// Kinh độ khởi tạo ban đầu của tâm ghim tìm kiếm.
  final double initialLng;

  /// Bán kính vùng tìm kiếm quanh tâm ghim tính bằng mét (ví dụ `800`).
  final int radiusMeters;

  /// Chiều cao khung bản đồ tính bằng điểm ảnh logic.
  final double height;

  /// Cho biết có vẽ vòng tròn hiển thị bán kính `radiusMeters` quanh tâm bản đồ hay không.
  final bool showRadiusCircle;

  /// Cho biết có hiển thị dải chip chọn nhanh 8 khu vực nổi bật phía trên bản đồ hay không.
  final bool showPresetChips;

  /// Hàm gọi lại trả về tọa độ `(lat, lng)` đã kẹp biên và nhãn mô tả khi người dùng chọn vị trí mới.
  final void Function(double lat, double lng, String? label)? onLocationChanged;

  /// Hàm gọi lại khi người dùng điều chỉnh thanh trượt bán kính tìm kiếm (`500m..5000m`).
  final ValueChanged<int>? onRadiusChanged;

  /// Khởi tạo bộ chọn bản đồ Vũng Tàu `VungTauMapPicker`.
  const VungTauMapPicker({
    super.key,
    this.initialLat = VungTauMapConstants.defaultLat,
    this.initialLng = VungTauMapConstants.defaultLng,
    this.radiusMeters = VungTauMapConstants.defaultRadiusMeters,
    this.height = 300,
    this.showRadiusCircle = true,
    this.showPresetChips = true,
    this.onLocationChanged,
    this.onRadiusChanged,
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

  /// Chiếu thuận kinh độ `lng` (độ) sang tọa độ mảnh ngang `tileX` thực trên lưới `2^zoom` của Web Mercator.
  double _lngToTileX(double lng, int zoom) {
    // Giải thuật chiếu tuyến tính kinh độ sang không gian mảnh Web Mercator (tương ứng pixel thế giới chia 256):
    return ((lng + 180.0) / 360.0) * (1 << zoom);
  }

  /// Chiếu thuận vĩ độ `lat` (độ) sang tọa độ mảnh dọc `tileY` thực theo công thức bảo góc Web Mercator.
  ///
  /// Sử dụng hệ thức `ln(tan(phi) + 1 / cos(phi)) == ln(tan(pi / 4 + phi / 2))` với `phi` tính bằng radian,
  /// chuẩn hóa miền giá trị về `[0, 2^zoom)` (gốc `0` tại cực Bắc `~85.0511` độ, tăng dần về cực Nam).
  double _latToTileY(double lat, int zoom) {
    // Giải thuật chiếu vĩ độ cầu sang tọa độ dọc Web Mercator qua tích phân ln(tan(pi/4 + phi/2)):
    final latRad = lat * math.pi / 180.0;
    return (1.0 -
            math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
        2.0 *
        (1 << zoom);
  }

  /// Chiếu ngược tọa độ mảnh ngang `tileX` trên lưới `2^zoom` về lại kinh độ địa lý (`-180..180` độ).
  double _tileXToLng(double tileX, int zoom) {
    // Giải thuật chiếu ngược tọa độ mảnh ngang về kinh độ WGS84:
    return tileX / (1 << zoom) * 360.0 - 180.0;
  }

  /// Chiếu ngược tọa độ mảnh dọc `tileY` trên lưới `2^zoom` về lại vĩ độ địa lý (độ).
  ///
  /// Tính tham số chuẩn hóa `n = pi - 2 * pi * tileY / 2^zoom`, sau đó khôi phục góc vĩ độ
  /// `phi = atan(sinh(n)) = 2 * atan(exp(n)) - pi / 2` và đổi từ radian sang độ thập phân.
  double _tileYToLat(double tileY, int zoom) {
    // Giải thuật chiếu ngược Web Mercator từ tọa độ mảnh dọc về vĩ độ qua hàm hyperbolic sinh(n) tương đương 2*atan(exp(n)) - pi/2:
    final n = math.pi - 2.0 * math.pi * tileY / (1 << zoom);
    return 180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
  }

  /// Xử lý bắt điểm chạm trên khung bản đồ, quy đổi độ lệch pixel so với tâm sang tọa độ địa lý đã kẹp biên.
  void _handleMapTap(TapUpDetails details, Size size) {
    // Giải thuật bắt điểm chạm (Tap Hit-Testing & Focal Offset Unprojection):
    // Tính khoảng cách pixel (dxPixels, dyPixels) từ điểm chạm tới tâm khung nhìn, chia cho kích thước chuẩn
    // 256px của mỗi mảnh để cộng vào (centerTileX, centerTileY), sau đó chiếu ngược ra (lat, lng) và kẹp biên Vũng Tàu.
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

  /// Dịch chuyển tâm bản đồ mượt theo vector kéo ngón tay / chuột `details.delta` trong không gian mảnh `2^zoom * 256`.
  void _handlePanUpdate(DragUpdateDetails details) {
    // Giải thuật tịnh tiến tâm bản đồ khi kéo (Pan Translation in Web Mercator Pixel Space):
    // Trừ đi delta / 256.0 (kéo nền bản đồ sang phải đồng nghĩa dời tâm quan sát sang phía Tây),
    // sau đó chiếu ngược về tọa độ WGS84 và khóa cứng trong hộp biên Vũng Tàu.
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

  /// Quy đổi bán kính mặt đất thực tế `meters` sang bán kính điểm ảnh trên màn hình tại vĩ độ `lat` và mức phóng `zoom`.
  double _metersToPixels(int meters, double lat, int zoom) {
    // Giải thuật quy đổi độ phân giải mặt đất Web Mercator theo vĩ độ và mức phóng 2^zoom:
    // Hằng số 156543.03392 = (2 * pi * 6378137m) / 256px là số mét trên 1 pixel tại xích đạo ở zoom = 0;
    // nhân cos(lat) và chia cho 2^zoom để ra tỷ lệ m/px thực tế tại Vũng Tàu, kẹp bán kính hiển thị trong [24, 140] px.
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
          // Giải thuật co giãn chiều cao chip khu vực bản đồ theo tỷ lệ chữ (`1.0x–2.0x`):
          // Thay `SizedBox(height: 36)` cố định bằng `SingleChildScrollView` ngang kết hợp `BoxConstraints(minHeight: 36)`
          // và khoảng đệm dọc thoáng để dấu tiếng Việt không bao giờ bị cắt xén khi phóng chữ.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0;
                    index < VungTauMapConstants.locationGroups.length;
                    index++) ...[
                  if (index > 0) const SizedBox(width: 8),
                  Builder(
                    builder: (context) {
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
                          constraints: const BoxConstraints(minHeight: 36),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            group.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.25,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
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
                // Giải thuật lắp ghép ma trận mảnh bản đồ 5x5 quanh tâm tiêu điểm (Slippy Tile Viewport Matrix):
                // Tách phần nguyên (baseTileX, baseTileY) và phần lẻ pixel (offsetX, offsetY) của tâm khung nhìn,
                // sau đó xếp 25 mảnh 256x256 (dx, dy thuộc [-2..2]) sao cho tâm (_lat, _lng) luôn trùng khít tâm khung.
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
                        child: AppImage(
                          imageUrl: tileUrl,
                          width: 256,
                          height: 256,
                          fit: BoxFit.cover,
                          errorWidget: CustomPaint(
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
        if (widget.showRadiusCircle && widget.onRadiusChanged != null) ...[
          const SizedBox(height: 10),
          // Giải thuật lượng tử hóa bán kính tìm kiếm địa lý (500m..5000m, bước nhảy 500m):
          // Kẹp giá trị hiện tại vào đoạn [500, 5000] để tương thích cả mức mặc định 800m lẫn các nấc kéo 0.5km - 5.0km.
          Builder(
            builder: (context) {
              final clampedMeters = widget.radiusMeters.clamp(500, 5000);
              final kmLabel = (clampedMeters / 1000).toStringAsFixed(1);
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bán kính tìm kiếm',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '$kmLabel km (${widget.radiusMeters}m)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: AppColors.border,
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.primary.withValues(alpha: 0.12),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        key: const ValueKey('vung_tau_map_radius_slider'),
                        min: 500,
                        max: 5000,
                        divisions: 9,
                        value: clampedMeters.toDouble(),
                        label: '$kmLabel km',
                        onChanged: (next) {
                          final rounded =
                              ((next / 500).round() * 500).clamp(500, 5000);
                          widget.onRadiusChanged?.call(rounded);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Bộ vẽ nền lưới tọa độ dự phòng hiển thị thay thế khi thiết bị ngoại tuyến hoặc mảnh ảnh bản đồ mạng bị lỗi tải.
class _FallbackMapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Giải thuật vẽ lưới ô vuông tọa độ dự phòng (Offline Cartesian Fallback Grid):
    // Tô nền xanh xám nhạt dịu mắt rồi kẻ hệ trục dọc - ngang cách đều mỗi bước 32px
    // giúp duy trì cảm nhận tỷ lệ kéo và khoảng cách ngay cả khi chưa tải được ảnh vệ tinh / đường phố.
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
