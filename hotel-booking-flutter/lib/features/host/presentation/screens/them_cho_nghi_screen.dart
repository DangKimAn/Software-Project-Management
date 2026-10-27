import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/host_repository.dart';
import '../../domain/host_models.dart';
import '../../services/host_file_picker_service.dart';

enum QueuedImageUploadStatus {
  queued,
  uploading,
  success,
  analyzing,
  tagged,
  analysisFailed,
  failed;

  String get labelVi {
    switch (this) {
      case QueuedImageUploadStatus.queued:
        return 'Chờ tải lên';
      case QueuedImageUploadStatus.uploading:
        return 'Đang tải ảnh lên R2...';
      case QueuedImageUploadStatus.success:
        return 'Đã tải ảnh lên';
      case QueuedImageUploadStatus.analyzing:
        return 'Đang phân tích ảnh bằng AI...';
      case QueuedImageUploadStatus.tagged:
        return 'Đã gắn tag AI';
      case QueuedImageUploadStatus.analysisFailed:
        return 'Phân tích lỗi, thử lại';
      case QueuedImageUploadStatus.failed:
        return 'Tải ảnh thất bại';
    }
  }
}

class QueuedListingImage {
  final String id;
  final HostPickedFile file;
  final QueuedImageUploadStatus status;
  final double progress;
  final String? error;
  final String? uploadedPublicUrl;
  final String? uploadedKey;
  final int? savedImageId;

  const QueuedListingImage({
    required this.id,
    required this.file,
    this.status = QueuedImageUploadStatus.queued,
    this.progress = 0,
    this.error,
    this.uploadedPublicUrl,
    this.uploadedKey,
    this.savedImageId,
  });

  QueuedListingImage copyWith({
    QueuedImageUploadStatus? status,
    double? progress,
    String? error,
    bool clearError = false,
    String? uploadedPublicUrl,
    String? uploadedKey,
    int? savedImageId,
  }) {
    return QueuedListingImage(
      id: id,
      file: file,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: clearError ? null : (error ?? this.error),
      uploadedPublicUrl: uploadedPublicUrl ?? this.uploadedPublicUrl,
      uploadedKey: uploadedKey ?? this.uploadedKey,
      savedImageId: savedImageId ?? this.savedImageId,
    );
  }
}

class ThemChoNghiScreen extends ConsumerStatefulWidget {
  final String? listingId;
  final VoidCallback? onSaved;
  final VoidCallback? onCancel;
  final bool embedded;

  const ThemChoNghiScreen({
    super.key,
    this.listingId,
    this.onSaved,
    this.onCancel,
    this.embedded = false,
  });

  @override
  ConsumerState<ThemChoNghiScreen> createState() => _ThemChoNghiScreenState();
}

bool isApprovedHostRole(String? role) {
  final normalized = (role ?? '').trim().toLowerCase();
  return normalized == 'host' || normalized == 'admin';
}

class _ThemChoNghiScreenState extends ConsumerState<ThemChoNghiScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController(
    text: kDefaultVungTauLat.toStringAsFixed(6),
  );
  final _lngController = TextEditingController(
    text: kDefaultVungTauLng.toStringAsFixed(6),
  );
  final _maxGuestsController = TextEditingController(text: '4');
  final _bedroomsController = TextEditingController(text: '2');
  final _bedsController = TextEditingController(text: '2');
  final _bathroomsController = TextEditingController(text: '2');
  final _basePriceController = TextEditingController(text: '1500000');
  final _weekendPriceController = TextEditingController(text: '1500000');
  final _cleaningFeeController = TextEditingController(text: '0');
  final _surchargeController = TextEditingController(text: '0');
  final _minNightsController = TextEditingController(text: '1');
  final _maxNightsController = TextEditingController();
  final _quietHoursController = TextEditingController(text: '22:00 - 06:00');

  HostPropertyType _propertyType = HostPropertyType.villa;
  HostRoomType _roomType = HostRoomType.entirePlace;
  HostCancellationPolicy _cancellationPolicy = HostCancellationPolicy.flexible;
  HostListingStatus _initialCreateStatus = HostListingStatus.draft;

  String _selectedWard = kVungTauWards.first.name;
  String _checkInFrom = '14:00';
  String _checkOutBefore = '12:00';
  bool _instantBookEnabled = false;
  bool _weekendPriceManuallyChanged = false;

  // House rules
  bool _smokingAllowed = false;
  bool _petsAllowed = false;
  bool _partyAllowed = false;

  // Amenities
  List<Map<String, dynamic>> _availableAmenities = [];
  final Set<int> _selectedAmenityIds = {};

  // Existing & Queued Images + AI Vision Taxonomy
  String? _activeListingId;
  List<ExistingListingImage> _existingImages = [];
  List<QueuedListingImage> _queuedImages = [];
  List<ImageTagTaxonomy> _tagTaxonomies = kDefaultImageTagTaxonomies;
  final Set<int> _analyzingImageIds = {};
  final Set<int> _savingTagImageIds = {};
  bool _analyzingAllAi = false;

  bool _loadingInitial = false;
  bool _saving = false;
  String? _errorMessage;
  String? _successMessage;
  String? _uploadStatusMessage;
  String? _aiStatusMessage;

  bool get _isEditMode =>
      _activeListingId != null && _activeListingId!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _activeListingId = widget.listingId;
    final firstWard = kVungTauWards.first;
    _latController.text = firstWard.latitude.toStringAsFixed(6);
    _lngController.text = firstWard.longitude.toStringAsFixed(6);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  @override
  void didUpdateWidget(covariant ThemChoNghiScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listingId != widget.listingId) {
      _activeListingId = widget.listingId;
      _initializeData();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _maxGuestsController.dispose();
    _bedroomsController.dispose();
    _bedsController.dispose();
    _bathroomsController.dispose();
    _basePriceController.dispose();
    _weekendPriceController.dispose();
    _cleaningFeeController.dispose();
    _surchargeController.dispose();
    _minNightsController.dispose();
    _maxNightsController.dispose();
    _quietHoursController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() {
      _loadingInitial = true;
      _errorMessage = null;
    });

    final repo = ref.read(hostRepositoryProvider);

    try {
      final amenitiesFuture = repo.getPublicAmenities().catchError(
            (_) => <Map<String, dynamic>>[],
          );

      if (_isEditMode) {
        final detailFuture = repo.getHostListingById(_activeListingId!);
        final analysisFuture =
            repo.getListingImagesAnalysis(_activeListingId!).catchError(
                  (_) => (
                    images: <ExistingListingImage>[],
                    tagTaxonomies: kDefaultImageTagTaxonomies,
                    summary: const <String, dynamic>{},
                  ),
                );

        final results = await Future.wait<dynamic>([
          amenitiesFuture,
          detailFuture,
          analysisFuture,
        ]);

        if (!mounted) return;

        final amenities = results[0] as List<Map<String, dynamic>>;
        final detail = results[1] as Map<String, dynamic>;
        final analysis = results[2] as ({
          List<ExistingListingImage> images,
          List<ImageTagTaxonomy> tagTaxonomies,
          Map<String, dynamic> summary,
        });

        _availableAmenities = amenities;
        _populateFromListingDetail(detail, analysis);
      } else {
        final amenities = await amenitiesFuture;
        if (!mounted) return;
        _availableAmenities = amenities;
      }

      setState(() => _loadingInitial = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingInitial = false;
        _errorMessage = repo.extractErrorMessage(
          e,
          'Không thể tải dữ liệu chỗ nghỉ.',
        );
      });
    }
  }

  void _populateFromListingDetail(
    Map<String, dynamic> detail,
    ({
      List<ExistingListingImage> images,
      List<ImageTagTaxonomy> tagTaxonomies,
      Map<String, dynamic> summary,
    }) analysis,
  ) {
    _titleController.text = (detail['title'] ?? '').toString();
    _descriptionController.text = (detail['description'] ?? '').toString();
    _addressController.text = (detail['addressLine'] ?? '').toString();

    final ward = (detail['ward'] ?? '').toString().trim();
    if (ward.isNotEmpty) {
      _selectedWard = ward;
    }

    final lat = detail['latitude'] is num
        ? (detail['latitude'] as num).toDouble()
        : double.tryParse('${detail['latitude'] ?? ''}');
    final lng = detail['longitude'] is num
        ? (detail['longitude'] as num).toDouble()
        : double.tryParse('${detail['longitude'] ?? ''}');
    if (lat != null) _latController.text = lat.toStringAsFixed(6);
    if (lng != null) _lngController.text = lng.toStringAsFixed(6);

    _propertyType = HostPropertyType.fromApi(detail['propertyType']);
    _roomType = HostRoomType.fromApi(detail['roomType']);
    _cancellationPolicy =
        HostCancellationPolicy.fromApi(detail['cancellationPolicy']);
    _initialCreateStatus = HostListingStatus.fromApi(detail['status']);

    _maxGuestsController.text = '${detail['maxGuests'] ?? 4}';
    _bedroomsController.text = '${detail['bedrooms'] ?? 2}';
    _bedsController.text = '${detail['beds'] ?? 2}';
    _bathroomsController.text = '${detail['bathrooms'] ?? 1}';

    final basePrice = detail['basePrice'] ?? detail['pricePerNight'] ?? 0;
    final weekendPrice = detail['weekendPrice'] ?? basePrice;
    _basePriceController.text = _formatNumericInput(basePrice);
    _weekendPriceController.text = _formatNumericInput(weekendPrice);
    _weekendPriceManuallyChanged =
        _weekendPriceController.text != _basePriceController.text;

    _cleaningFeeController.text =
        _formatNumericInput(detail['cleaningFee'] ?? 0);
    _surchargeController.text =
        _formatNumericInput(detail['surchargeAmount'] ?? 0);
    _minNightsController.text = '${detail['minNights'] ?? 1}';
    _maxNightsController.text =
        detail['maxNights'] != null ? '${detail['maxNights']}' : '';

    final checkIn = (detail['checkInFrom'] ?? '14:00').toString();
    if (kHalfHourTimeOptions.contains(checkIn)) {
      _checkInFrom = checkIn;
    }
    final checkOut = (detail['checkOutBefore'] ?? '12:00').toString();
    if (kHalfHourTimeOptions.contains(checkOut)) {
      _checkOutBefore = checkOut;
    }

    _instantBookEnabled =
        detail['instantBookEnabled'] == true || detail['instantBook'] == true;

    // House rules
    final rules = detail['rules'] is Map<Object?, Object?>
        ? Map<String, dynamic>.from(detail['rules'] as Map<Object?, Object?>)
        : detail;
    _smokingAllowed = rules['smokingAllowed'] == true;
    _petsAllowed = rules['petsAllowed'] == true;
    _partyAllowed = rules['partyAllowed'] == true;
    if (rules['quietHours'] != null) {
      _quietHoursController.text = rules['quietHours'].toString();
    }

    // Amenities
    _selectedAmenityIds.clear();
    final rawAmenities = detail['amenities'] ?? detail['amenityIds'];
    if (rawAmenities is List) {
      for (final item in rawAmenities) {
        if (item is num) {
          _selectedAmenityIds.add(item.toInt());
        } else if (item is Map<Object?, Object?>) {
          final id = item['amenityId'] ?? item['id'];
          final parsed = id is num ? id.toInt() : int.tryParse('${id ?? ''}');
          if (parsed != null && parsed > 0) _selectedAmenityIds.add(parsed);
        } else {
          final parsed = int.tryParse('$item');
          if (parsed != null && parsed > 0) _selectedAmenityIds.add(parsed);
        }
      }
    }

    // Taxonomies & Images
    _tagTaxonomies = analysis.tagTaxonomies.isNotEmpty
        ? analysis.tagTaxonomies
        : kDefaultImageTagTaxonomies;

    if (analysis.images.isNotEmpty) {
      _existingImages = analysis.images;
    } else if (detail['images'] is List) {
      _existingImages = (detail['images'] as List)
          .whereType<Map<Object?, Object?>>()
          .map(
            (e) => ExistingListingImage.fromJson(
              Map<String, dynamic>.from(e),
              taxonomies: _tagTaxonomies,
            ),
          )
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
  }

  String _formatNumericInput(dynamic raw) {
    if (raw == null) return '0';
    if (raw is int) return '$raw';
    if (raw is double) {
      return raw == raw.roundToDouble() ? '${raw.toInt()}' : '$raw';
    }
    final parsed = double.tryParse('$raw');
    if (parsed == null) return '0';
    return parsed == parsed.roundToDouble() ? '${parsed.toInt()}' : '$parsed';
  }

  void _handleWardChanged(String? wardName) {
    if (wardName == null || wardName.isEmpty) return;
    setState(() {
      _selectedWard = wardName;
      final ward = kVungTauWards.cast<VungTauWard?>().firstWhere(
            (w) => w?.name == wardName,
            orElse: () => null,
          );
      if (ward != null) {
        _latController.text = ward.latitude.toStringAsFixed(6);
        _lngController.text = ward.longitude.toStringAsFixed(6);
      }
    });
  }

  void _handleBasePriceChanged(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits != value) {
      _basePriceController.value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    }
    if (!_weekendPriceManuallyChanged) {
      _weekendPriceController.text = digits;
    }
  }

  void _handleWeekendPriceChanged(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits != value) {
      _weekendPriceController.value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    }
    _weekendPriceManuallyChanged = digits.isNotEmpty;
  }

  // ===========================================================================
  // R2 Image Picking, Queuing, Retry & Existing Image Management
  // ===========================================================================

  Future<void> _pickImagesFromDevice() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    final totalCount = _existingImages.length + _queuedImages.length;
    final remainingSlots = kMaxListingImagesCount - totalCount;
    if (remainingSlots <= 0) {
      setState(() {
        _errorMessage =
            'Mỗi chỗ nghỉ chỉ được tối đa $kMaxListingImagesCount ảnh.';
      });
      return;
    }

    try {
      final picker = ref.read(hostFilePickerProvider);
      final files = await picker.pickListingImages(
        context: context,
        maxImages: remainingSlots,
      );
      if (files.isEmpty || !mounted) return;

      for (final file in files) {
        final err = validateListingImagePickedFile(file);
        if (err != null) {
          setState(() => _errorMessage = err);
          return;
        }
      }

      final nowMs = DateTime.now().microsecondsSinceEpoch;
      final additions = <QueuedListingImage>[];
      for (var i = 0; i < files.length; i++) {
        additions.add(
          QueuedListingImage(
            id: 'queued_${nowMs}_$i',
            file: files[i],
          ),
        );
      }

      setState(() {
        _queuedImages = [..._queuedImages, ...additions];
      });
    } catch (e) {
      if (!mounted) return;
      final repo = ref.read(hostRepositoryProvider);
      setState(() {
        _errorMessage = repo.extractErrorMessage(
          e,
          'Không thể chọn ảnh từ thiết bị.',
        );
      });
    }
  }

  void _removeQueuedImage(String id) {
    setState(() {
      _queuedImages = _queuedImages.where((item) => item.id != id).toList();
    });
  }

  void _clearAllQueuedImages() {
    setState(() {
      _queuedImages = [];
    });
  }

  void _moveQueuedImage(int index, int delta) {
    final targetIndex = index + delta;
    if (targetIndex < 0 || targetIndex >= _queuedImages.length) return;
    setState(() {
      final list = List<QueuedListingImage>.from(_queuedImages);
      final moved = list.removeAt(index);
      list.insert(targetIndex, moved);
      _queuedImages = list;
    });
  }

  void _updateQueuedImage(
    String id,
    QueuedListingImage Function(QueuedListingImage current) updater,
  ) {
    setState(() {
      _queuedImages = _queuedImages
          .map((item) => item.id == id ? updater(item) : item)
          .toList();
    });
  }

  void _mergeExistingImage(ExistingListingImage updated) {
    setState(() {
      final exists =
          _existingImages.any((img) => img.imageId == updated.imageId);
      if (!exists) {
        _existingImages = [..._existingImages, updated]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      } else {
        _existingImages = _existingImages
            .map(
              (img) => img.imageId == updated.imageId
                  ? updated.copyWith(isCover: updated.isCover || img.isCover)
                  : img,
            )
            .toList();
      }
    });
  }

  Future<
      ({
        int successCount,
        List<String> failures,
        List<String> analysisFailures
      })> _uploadQueuedImagesForListing(
    String listingId,
    List<QueuedListingImage> imagesToProcess,
  ) async {
    final repo = ref.read(hostRepositoryProvider);
    final failures = <String>[];
    final analysisFailures = <String>[];
    int successCount = 0;

    final initialExistingCount = _existingImages.length;
    var nextSortOrder = _existingImages.isEmpty
        ? 0
        : (_existingImages
                .map((e) => e.sortOrder)
                .reduce((a, b) => a > b ? a : b) +
            1);
    if (nextSortOrder < _existingImages.length) {
      nextSortOrder = _existingImages.length;
    }

    for (var i = 0; i < imagesToProcess.length; i++) {
      final item = imagesToProcess[i];
      if (!mounted) break;

      setState(() {
        _uploadStatusMessage =
            'Đang tải ảnh ${i + 1}/${imagesToProcess.length} (${item.file.name})...';
      });
      _updateQueuedImage(
        item.id,
        (cur) => cur.copyWith(
          status: QueuedImageUploadStatus.uploading,
          progress: 0,
          clearError: true,
        ),
      );

      try {
        String publicUrl;
        String? objectKey;
        if (item.uploadedPublicUrl != null &&
            item.uploadedPublicUrl!.trim().isNotEmpty) {
          publicUrl = item.uploadedPublicUrl!.trim();
          objectKey = item.uploadedKey;
        } else {
          final uploaded = await repo.uploadFileToR2(
            item.file,
            folder: 'listings',
            listingId: listingId,
            onSendProgress: (sent, total) {
              if (!mounted || total <= 0) return;
              _updateQueuedImage(
                item.id,
                (cur) => cur.copyWith(progress: (sent / total).clamp(0.0, 1.0)),
              );
            },
          );
          publicUrl = uploaded.publicUrl;
          objectKey = uploaded.key;
          _updateQueuedImage(
            item.id,
            (cur) => cur.copyWith(
              uploadedPublicUrl: publicUrl,
              uploadedKey: objectKey,
            ),
          );
        }

        final assignedSortOrder = nextSortOrder++;
        final savedImages = await repo.addListingImages(
          listingId,
          [
            {
              'url': publicUrl,
              'key': objectKey,
              'originalFilename': item.file.name,
              'displayTitle': null,
              'altText': _titleController.text.trim().isNotEmpty
                  ? _titleController.text.trim()
                  : 'Ảnh chỗ nghỉ',
              'caption': null,
              'isCover': initialExistingCount == 0 && successCount == 0,
              'sortOrder': assignedSortOrder,
            },
          ],
          taxonomies: _tagTaxonomies,
        );

        successCount += 1;
        final createdImage = savedImages.isNotEmpty ? savedImages.first : null;
        if (createdImage != null) {
          _mergeExistingImage(createdImage);
        }

        _updateQueuedImage(
          item.id,
          (cur) => cur.copyWith(
            status: QueuedImageUploadStatus.success,
            progress: 1.0,
            uploadedPublicUrl: publicUrl,
            uploadedKey: objectKey,
            savedImageId: createdImage?.imageId,
          ),
        );

        if (createdImage != null && createdImage.imageId > 0) {
          setState(() {
            _uploadStatusMessage =
                'Đang phân tích ảnh bằng AI ${i + 1}/${imagesToProcess.length}...';
          });
          _updateQueuedImage(
            item.id,
            (cur) => cur.copyWith(status: QueuedImageUploadStatus.analyzing),
          );

          try {
            final analyzed = await repo.analyzeSingleListingImage(
              listingId,
              createdImage.imageId,
              taxonomies: _tagTaxonomies,
            );
            _mergeExistingImage(analyzed);
            if (analyzed.aiAnalysisStatus == 'analyzed') {
              _updateQueuedImage(
                item.id,
                (cur) => cur.copyWith(status: QueuedImageUploadStatus.tagged),
              );
            } else {
              final msg =
                  analyzed.aiErrorMessage ?? 'Phân tích AI chưa hoàn tất.';
              analysisFailures.add('${item.file.name}: $msg');
              _updateQueuedImage(
                item.id,
                (cur) => cur.copyWith(
                  status: QueuedImageUploadStatus.analysisFailed,
                  error: msg,
                ),
              );
            }
          } catch (aiErr) {
            final msg = repo.extractErrorMessage(
              aiErr,
              'Phân tích lỗi, thử lại.',
            );
            analysisFailures.add('${item.file.name}: $msg');
            _mergeExistingImage(
              createdImage.copyWith(
                aiAnalysisStatus: 'failed',
                aiErrorMessage: msg,
              ),
            );
            _updateQueuedImage(
              item.id,
              (cur) => cur.copyWith(
                status: QueuedImageUploadStatus.analysisFailed,
                error: msg,
              ),
            );
          }
        }
      } catch (uploadErr) {
        final msg = repo.extractErrorMessage(
          uploadErr,
          'Upload ảnh thất bại.',
        );
        failures.add('${item.file.name}: $msg');
        _updateQueuedImage(
          item.id,
          (cur) => cur.copyWith(
            status: QueuedImageUploadStatus.failed,
            error: msg,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _uploadStatusMessage = analysisFailures.isNotEmpty
            ? 'Một số ảnh phân tích AI chưa thành công, bạn có thể thử lại hoặc gắn nhãn thủ công.'
            : (successCount > 0 ? 'Đã tải lên và gắn nhãn ảnh.' : null);
      });
    }

    return (
      successCount: successCount,
      failures: failures,
      analysisFailures: analysisFailures,
    );
  }

  Future<void> _retryFailedQueuedImage(QueuedListingImage item) async {
    if (!_isEditMode) {
      setState(() {
        _errorMessage = 'Vui lòng nhấn Lưu chỗ nghỉ để tải ảnh lên.';
      });
      return;
    }
    await _uploadQueuedImagesForListing(_activeListingId!, [item]);
  }

  Future<void> _handleSetCoverImage(int imageId) async {
    if (!_isEditMode) return;
    final repo = ref.read(hostRepositoryProvider);
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await repo.setListingCoverImage(_activeListingId!, imageId);
      if (!mounted) return;
      setState(() {
        _existingImages = _existingImages
            .map((img) => img.copyWith(isCover: img.imageId == imageId))
            .toList();
        _successMessage = 'Đã cập nhật ảnh bìa.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = repo.extractErrorMessage(
          e,
          'Không thể cập nhật ảnh bìa.',
        );
      });
    }
  }

  Future<void> _handleDeleteExistingImage(ExistingListingImage image) async {
    if (!_isEditMode) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Xóa ảnh chỗ nghỉ'),
        content: const Text('Bạn có chắc chắn muốn xóa ảnh này khỏi chỗ nghỉ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBE123C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa ảnh'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repo = ref.read(hostRepositoryProvider);
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await repo.deleteHostImage(image.imageId);
      if (!mounted) return;
      setState(() {
        _existingImages = _existingImages
            .where((img) => img.imageId != image.imageId)
            .toList();
        _successMessage = 'Đã xóa ảnh.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = repo.extractErrorMessage(e, 'Không thể xóa ảnh.');
      });
    }
  }

  Future<void> _moveExistingImage(int index, int delta) async {
    final targetIndex = index + delta;
    if (targetIndex < 0 || targetIndex >= _existingImages.length) return;
    final list = List<ExistingListingImage>.from(_existingImages);
    final moved = list.removeAt(index);
    list.insert(targetIndex, moved);
    setState(() {
      _existingImages = [
        for (var i = 0; i < list.length; i++) list[i].copyWith(sortOrder: i),
      ];
    });
    if (targetIndex == 0 &&
        _isEditMode &&
        !moved.isCover &&
        moved.imageId > 0) {
      await _handleSetCoverImage(moved.imageId);
    }
  }

  Future<void> _handleAnalyzeSingleImage(int imageId) async {
    if (!_isEditMode) return;
    final repo = ref.read(hostRepositoryProvider);
    setState(() {
      _analyzingImageIds.add(imageId);
      _aiStatusMessage = 'Đang phân tích ảnh bằng AI...';
      _errorMessage = null;
    });

    try {
      final result = await repo.analyzeSingleListingImage(
        _activeListingId!,
        imageId,
        taxonomies: _tagTaxonomies,
      );
      if (!mounted) return;
      _mergeExistingImage(result);
      setState(() {
        _aiStatusMessage = result.aiAnalysisStatus == 'analyzed'
            ? 'Đã gắn tag AI cho ảnh.'
            : 'Phân tích AI chưa hoàn tất. Bạn có thể chọn tag thủ công bên dưới.';
      });
    } catch (e) {
      if (!mounted) return;
      final msg = repo.extractErrorMessage(
        e,
        'Không thể phân tích ảnh bằng AI.',
      );
      setState(() {
        _existingImages = _existingImages
            .map(
              (img) => img.imageId == imageId
                  ? img.copyWith(
                      aiAnalysisStatus: 'failed',
                      aiErrorMessage: msg,
                    )
                  : img,
            )
            .toList();
        _aiStatusMessage =
            'Phân tích AI tạm thời gián đoạn ($msg). Bạn vẫn có thể gắn tag thủ công và lưu chỗ nghỉ.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _analyzingImageIds.remove(imageId);
        });
      }
    }
  }

  Future<void> _handleAnalyzeAllImagesWithAi() async {
    if (!_isEditMode) {
      setState(() {
        _aiStatusMessage =
            'Bạn cần lưu chỗ nghỉ trước khi phân tích ảnh bằng AI.';
      });
      return;
    }
    if (_existingImages.isEmpty) {
      setState(() {
        _aiStatusMessage = 'Chỗ nghỉ này chưa có ảnh đã lưu để phân tích.';
      });
      return;
    }

    final repo = ref.read(hostRepositoryProvider);
    setState(() {
      _analyzingAllAi = true;
      _aiStatusMessage = 'Đang phân tích toàn bộ ảnh bằng AI...';
      _errorMessage = null;
    });

    try {
      final result = await repo.analyzeAllListingImages(
        _activeListingId!,
        force: true,
        taxonomies: _tagTaxonomies,
      );
      final refreshed = await repo.getListingImagesAnalysis(_activeListingId!);
      if (!mounted) return;
      setState(() {
        _tagTaxonomies = refreshed.tagTaxonomies;
        if (refreshed.images.isNotEmpty) {
          _existingImages = refreshed.images;
        }
        _aiStatusMessage =
            'Đã phân tích ${result.analyzedCount} ảnh${result.failedCount > 0 ? ', ${result.failedCount} ảnh lỗi (có thể gắn tag thủ công)' : ''}.';
      });
    } catch (e) {
      if (!mounted) return;
      final msg = repo.extractErrorMessage(
        e,
        'Không thể phân tích ảnh bằng AI.',
      );
      setState(() {
        _aiStatusMessage =
            'Phân tích AI tạm thời gián đoạn ($msg). Bạn vẫn có thể gắn tag thủ công từ 22 nhãn có sẵn.';
      });
    } finally {
      if (mounted) {
        setState(() => _analyzingAllAi = false);
      }
    }
  }

  Future<void> _handleUpdateImageTags(
    ExistingListingImage image,
    List<String> nextTagCodes,
  ) async {
    final repo = ref.read(hostRepositoryProvider);
    setState(() {
      _savingTagImageIds.add(image.imageId);
      _errorMessage = null;
    });

    try {
      final updated = await repo.updateListingImageTags(
        image.imageId,
        nextTagCodes,
        taxonomies: _tagTaxonomies,
      );
      if (!mounted) return;
      _mergeExistingImage(updated);
      setState(() {
        _successMessage = 'Đã cập nhật nhãn ảnh.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = repo.extractErrorMessage(
          e,
          'Không thể cập nhật nhãn ảnh.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingTagImageIds.remove(image.imageId);
        });
      }
    }
  }

  // ===========================================================================
  // Form Validation & Submit (Create / Update + Amenities + Rules + R2 Upload)
  // ===========================================================================

  HostListingUpsertDto? _buildValidatedDto(
      {HostListingStatus? overrideStatus}) {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) {
      setState(
          () => _errorMessage = 'Vui lòng nhập tọa độ vĩ độ/kinh độ hợp lệ.');
      return null;
    }

    final maxGuests = int.tryParse(_maxGuestsController.text.trim());
    final bedrooms = int.tryParse(_bedroomsController.text.trim());
    final beds = int.tryParse(_bedsController.text.trim());
    final bathrooms = double.tryParse(_bathroomsController.text.trim());
    final basePrice = double.tryParse(_basePriceController.text.trim());
    final weekendText = _weekendPriceController.text.trim();
    final weekendPrice =
        weekendText.isEmpty ? basePrice : double.tryParse(weekendText);
    final cleaningFee =
        double.tryParse(_cleaningFeeController.text.trim()) ?? 0;
    final surchargeAmount =
        double.tryParse(_surchargeController.text.trim()) ?? 0;
    final minNights = int.tryParse(_minNightsController.text.trim());
    final maxNightsText = _maxNightsController.text.trim();
    final maxNights =
        maxNightsText.isEmpty ? null : int.tryParse(maxNightsText);

    if (maxGuests == null ||
        bedrooms == null ||
        beds == null ||
        bathrooms == null ||
        basePrice == null ||
        weekendPrice == null ||
        minNights == null) {
      setState(() {
        _errorMessage =
            'Vui lòng kiểm tra lại các trường số (Sức chứa, Phòng, Giá, Số đêm).';
      });
      return null;
    }

    final dto = HostListingUpsertDto(
      title: _titleController.text,
      description: _descriptionController.text,
      addressLine: _addressController.text,
      ward: _selectedWard,
      district: kVungTauCity,
      city: kVungTauCity,
      country: 'VN',
      latitude: lat,
      longitude: lng,
      propertyType: _propertyType,
      roomType: _roomType,
      maxGuests: maxGuests,
      bedrooms: bedrooms,
      beds: beds,
      bathrooms: bathrooms,
      basePrice: basePrice,
      weekendPrice: weekendPrice,
      cleaningFee: cleaningFee,
      surchargeAmount: surchargeAmount,
      currency: 'VND',
      minNights: minNights,
      maxNights: maxNights,
      checkInFrom: _checkInFrom,
      checkOutBefore: _checkOutBefore,
      cancellationPolicy: _cancellationPolicy,
      instantBookEnabled: _instantBookEnabled,
      amenityIds: _selectedAmenityIds.toList(),
      status: overrideStatus ?? _initialCreateStatus,
    );

    final validationError = dto.validate();
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return null;
    }

    return dto;
  }

  Future<void> _submitForm({HostListingStatus? targetStatus}) async {
    if (_saving) return;
    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _uploadStatusMessage = null;
    });

    final currentRole = ref.read(hostCurrentUserRoleProvider);
    if (!isApprovedHostRole(currentRole)) {
      setState(() {
        _errorMessage =
            'Tài khoản chưa được cấp quyền Chủ nhà (Host) để tạo hoặc cập nhật chỗ nghỉ (403).';
      });
      return;
    }

    final dto = _buildValidatedDto(overrideStatus: targetStatus);
    if (dto == null) return;

    setState(() => _saving = true);
    final repo = ref.read(hostRepositoryProvider);

    final pendingUploads = _queuedImages
        .where(
          (item) =>
              item.status != QueuedImageUploadStatus.success &&
              item.status != QueuedImageUploadStatus.tagged &&
              item.status != QueuedImageUploadStatus.analysisFailed,
        )
        .toList();

    final wasAlreadyEditMode = _isEditMode;

    try {
      String listingId;
      if (wasAlreadyEditMode) {
        listingId = _activeListingId!;
        await repo.updateHostListing(
          listingId,
          dto.toUpdateJson(nextStatus: targetStatus),
                  );
      } else {
        final created = await repo.createHostListing(
          dto.toCreateJson(),
                  );
        listingId =
            (created['listingId'] ?? created['id'] ?? '').toString().trim();
        if (listingId.isEmpty) {
          throw Exception('Máy chủ không trả về mã chỗ nghỉ sau khi tạo.');
        }
        _activeListingId = listingId;
      }

      // Sync amenities (`PUT /api/host/listings/:id/amenities`) - NEVER swallow errors!
      if (_selectedAmenityIds.isNotEmpty || wasAlreadyEditMode) {
        try {
          await repo.updateListingAmenities(
            listingId,
            _selectedAmenityIds.toList(),
          );
        } catch (amenityErr) {
          final msg = repo.extractErrorMessage(
            amenityErr,
            'Cập nhật tiện nghi thất bại.',
          );
          throw StateError(
            'Đã lưu thông tin cơ bản (#$listingId) nhưng cập nhật tiện nghi thất bại: $msg',
          );
        }
      }

      // Sync rules (`PATCH /api/host/listings/:id/rules`) - NEVER swallow errors!
      try {
        await repo.updateListingRules(listingId, {
          'checkInFrom': _checkInFrom,
          'checkOutBefore': _checkOutBefore,
          'smokingAllowed': _smokingAllowed,
          'petsAllowed': _petsAllowed,
          'partyAllowed': _partyAllowed,
          'quietHours': _quietHoursController.text.trim(),
        });
      } catch (rulesErr) {
        final msg = repo.extractErrorMessage(
          rulesErr,
          'Cập nhật nội quy thất bại.',
        );
        throw StateError(
          'Đã lưu thông tin cơ bản (#$listingId) nhưng cập nhật nội quy thất bại: $msg',
        );
      }

      // Upload queued images to R2 & run AI analysis
      final uploadResult = pendingUploads.isNotEmpty
          ? await _uploadQueuedImagesForListing(listingId, pendingUploads)
          : (
              successCount: 0,
              failures: <String>[],
              analysisFailures: <String>[],
            );

      if (!mounted) return;

      if (uploadResult.failures.isNotEmpty) {
        setState(() {
          _saving = false;
          _errorMessage =
              'Đã lưu thông tin chỗ nghỉ nhưng một số ảnh tải lên R2 thất bại: ${uploadResult.failures.join("; ")}';
        });
        return;
      }

      // Remove completed queued images
      setState(() {
        _queuedImages = [];
        _saving = false;
        _successMessage = uploadResult.analysisFailures.isNotEmpty
            ? 'Đã lưu chỗ nghỉ. Một số ảnh phân tích AI lỗi: ${uploadResult.analysisFailures.join("; ")}'
            : (wasAlreadyEditMode
                ? 'Đã cập nhật chỗ nghỉ thành công.'
                : 'Đã tạo chỗ nghỉ thành công.');
      });

      widget.onSaved?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = repo.extractErrorMessage(
          e,
          'Không thể lưu chỗ nghỉ.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRole = ref.watch(hostCurrentUserRoleProvider);
    if (!isApprovedHostRole(currentRole)) {
      final unauthorizedView = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              key: const Key('listing_form_unauthorized_guard'),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.shieldAlert,
                    size: 36,
                    color: AppColors.iconStrong,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Yêu cầu quyền Chủ nhà (Host)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textStrong,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tài khoản hiện tại (${currentRole ?? 'guest'}) chưa được phê duyệt làm Chủ nhà nên không thể đăng hoặc sửa chỗ nghỉ.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(180, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: () => context.go('/tro-thanh-host/trang-thai'),
                    child: const Text('Kiểm tra hồ sơ Host'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (widget.embedded) return unauthorizedView;
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(child: unauthorizedView),
      );
    }

    final content = _loadingInitial
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(color: AppColors.iconStrong),
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _buildStatusBanner(
                        key: const Key('listing_form_error_banner'),
                        text: _errorMessage!,
                        bg: const Color(0xFFFFF1F2),
                        border: const Color(0xFFFECDD3),
                        fg: const Color(0xFFBE123C),
                        icon: LucideIcons.circleAlert,
                      ),
                    ],
                    if (_successMessage != null) ...[
                      const SizedBox(height: 16),
                      _buildStatusBanner(
                        key: const Key('listing_form_success_banner'),
                        text: _successMessage!,
                        bg: const Color(0xFFECFDF5),
                        border: const Color(0xFFA7F3D0),
                        fg: const Color(0xFF047857),
                        icon: LucideIcons.circleCheck,
                      ),
                    ],
                    if (_uploadStatusMessage != null) ...[
                      const SizedBox(height: 12),
                      _buildStatusBanner(
                        text: _uploadStatusMessage!,
                        bg: AppColors.surfaceWarmSand,
                        border: AppColors.border,
                        fg: AppColors.textStrong,
                        icon: LucideIcons.cloudUpload,
                      ),
                    ],
                    if (_aiStatusMessage != null) ...[
                      const SizedBox(height: 12),
                      _buildStatusBanner(
                        key: const Key('listing_form_ai_banner'),
                        text: _aiStatusMessage!,
                        bg: AppColors.surfaceWarmSand,
                        border: AppColors.border,
                        fg: AppColors.textStrong,
                        icon: LucideIcons.sparkles,
                      ),
                    ],
                    _buildHostCoPilotCard(),
                    const SizedBox(height: 16),
                    _buildBasicInfoCard(),
                    const SizedBox(height: 16),
                    _buildLocationCard(),
                    const SizedBox(height: 16),
                    _buildCapacityAndPricingCard(),
                    const SizedBox(height: 16),
                    _buildPoliciesAndRulesCard(),
                    const SizedBox(height: 16),
                    _buildAmenitiesCard(),
                    const SizedBox(height: 16),
                    _buildImagesAndAiCard(),
                    const SizedBox(height: 24),
                    _buildFooterActions(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBase,
        elevation: 0,
        leading: IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () {
            if (widget.onCancel != null) {
              widget.onCancel!();
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go('/host');
            }
          },
          tooltip: 'Quay lại',
        ),
        title: Text(
          _isEditMode ? 'Sửa chỗ nghỉ' : 'Thêm chỗ nghỉ mới',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _buildDropdownField<T>({
    Key? dropdownKey,
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
    String? hint,
  }) {
    return InputDecorator(
      decoration: _fieldDecoration(label, hint: hint),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          key: dropdownKey,
          isExpanded: true,
          isDense: true,
          value: value,
          hint: hint != null
              ? Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditMode
                  ? 'Sửa chỗ nghỉ #$_activeListingId'
                  : 'Thêm chỗ nghỉ mới',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Kê khai đầy đủ thông tin, tải ảnh lên R2 và gắn nhãn AI để tăng hiệu quả tìm kiếm.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        if (widget.onCancel != null)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(140, 48),
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: widget.onCancel,
            icon: const Icon(
              LucideIcons.arrowLeft,
              size: 16,
              color: AppColors.iconStrong,
            ),
            label: const Text('Quay lại danh sách'),
          ),
      ],
    );
  }

  int _calculateCompletionScore() {
    int score = 0;
    if (_titleController.text.trim().isNotEmpty) score += 15;
    if (_descriptionController.text.trim().length >= 20) score += 15;
    if (_addressController.text.trim().isNotEmpty) score += 15;
    final price = int.tryParse(
            _basePriceController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;
    if (price > 0) score += 15;
    final totalPhotos = _existingImages.length + _queuedImages.length;
    if (totalPhotos >= 5) {
      score += 20;
    } else if (totalPhotos >= 1) {
      score += 10;
    }
    if (_selectedAmenityIds.length >= 3) score += 10;
    if (_instantBookEnabled || _quietHoursController.text.isNotEmpty) {
      score += 10;
    }
    return score.clamp(0, 100);
  }

  Widget _buildHostCoPilotCard() {
    final score = _calculateCompletionScore();
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  LucideIcons.sparkles,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Host Studio • The Palm Villa Vũng Tàu',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      score >= 90
                          ? 'Tuyệt vời! Chỗ nghỉ của bạn đã đầy đủ thông tin chuẩn 5 sao.'
                          : 'Độ hoàn thiện % • Hoàn thiện đầy đủ để nhận huy hiệu Nổi bật.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: score >= 80
                      ? const Color(0xFFECFDF5)
                      : (score >= 50
                          ? const Color(0xFFFFFBEB)
                          : const Color(0xFFFFF1F2)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: score >= 80
                        ? const Color(0xFF047857)
                        : (score >= 50
                            ? const Color(0xFFB45309)
                            : const Color(0xFFBE123C)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: score / 100.0,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                score >= 80
                    ? const Color(0xFF10B981)
                    : (score >= 50
                        ? const Color(0xFFF59E0B)
                        : AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyTypeVisualSelector() {
    final types = [
      (value: HostPropertyType.villa, label: 'Villa biển', icon: LucideIcons.house),
      (value: HostPropertyType.apartment, label: 'Căn hộ', icon: LucideIcons.building2),
      (value: HostPropertyType.homestay, label: 'Homestay', icon: LucideIcons.flower2),
      (value: HostPropertyType.hotel, label: 'Khách sạn', icon: LucideIcons.hotel),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chọn loại hình chỗ nghỉ:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((item) {
            final isSelected = _propertyType == item.value;
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _propertyType = item.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.brandSoft : AppColors.surfaceBase,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 18,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRoomTypeVisualSelector() {
    final roomTypes = [
      (value: HostRoomType.entirePlace, label: 'Nguyên căn', icon: LucideIcons.keyRound),
      (value: HostRoomType.privateRoom, label: 'Phòng riêng', icon: LucideIcons.doorClosed),
      (value: HostRoomType.sharedRoom, label: 'Phòng chia sẻ', icon: LucideIcons.users),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Không gian dành cho khách:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: roomTypes.map((item) {
            final isSelected = _roomType == item.value;
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _roomType = item.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.brandSoft : AppColors.surfaceBase,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 18,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

    Widget _buildVungTauTitleSuggestions() {
    final suggestions = [
      '🏖️ View Biển',
      '🏊 Hồ Bơi Riêng',
      '🌊 Gần Bãi Sau',
      '🌅 Hoàng Hôn Bãi Dâu',
      '🍖 Sân Vườn BBQ',
      '✨ Seaview Luxury',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        const Text(
          'Gợi ý từ khóa hút khách Vũng Tàu (chạm để chèn vào tên):',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: suggestions.map((tag) {
            return ActionChip(
              backgroundColor: const Color(0xFFF8FAFC),
              side: const BorderSide(color: AppColors.border),
              label: Text(tag, style: const TextStyle(fontSize: 11)),
              onPressed: () {
                final clean = tag.replaceAll(RegExp(r'^[^\w\s]+\s*'), '');
                final current = _titleController.text.trim();
                if (!current.contains(clean)) {
                  setState(() {
                    if (current.isEmpty) {
                      _titleController.text = clean;
                    } else {
                      _titleController.text = ' - ';
                    }
                  });
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBasicInfoCard() {
    return _SectionCard(
      title: '1. Thông tin cơ bản & Phân loại',
      stepBadge: 'BƯỚC 1',
      icon: LucideIcons.home,
      subtitle:
          'Tên gọi ấn tượng và loại hình lưu trú giúp định vị thương hiệu của bạn tại Vũng Tàu.',
      children: [
        _buildPropertyTypeVisualSelector(),
        const SizedBox(height: 14),
        _buildRoomTypeVisualSelector(),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 540;
            final propDropdown = _buildDropdownField<HostPropertyType>(
              dropdownKey: const Key('listing_property_type_dropdown'),
              label: 'Loại chỗ nghỉ (Danh mục) *',
              value: _propertyType,
              items: HostPropertyType.values
                  .map(
                    (e) => DropdownMenuItem<HostPropertyType>(
                      value: e,
                      child: Text(e.labelVi, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _propertyType = v);
              },
            );
            final roomDropdown = _buildDropdownField<HostRoomType>(
              dropdownKey: const Key('listing_room_type_dropdown'),
              label: 'Loại phòng (Room Type) *',
              value: _roomType,
              items: HostRoomType.values
                  .map(
                    (e) => DropdownMenuItem<HostRoomType>(
                      value: e,
                      child: Text(e.labelVi, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _roomType = v);
              },
            );
            if (isWide) {
              return Row(
                children: [
                  Expanded(child: propDropdown),
                  const SizedBox(width: 14),
                  Expanded(child: roomDropdown),
                ],
              );
            }
            return Column(
              children: [
                propDropdown,
                const SizedBox(height: 14),
                roomDropdown,
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const Key('listing_title_input'),
          controller: _titleController,
          decoration: _fieldDecoration(
            'Tiêu đề chỗ nghỉ *',
            hint: 'Ví dụ: The Palm Villa Bãi Sau - Hồ Bơi Riêng & Sân Vườn BBQ',
          ),
        ),
        _buildVungTauTitleSuggestions(),
        const SizedBox(height: 14),
        TextFormField(
          key: const Key('listing_description_input'),
          controller: _descriptionController,
          maxLines: 4,
          decoration: _fieldDecoration(
            'Mô tả chi tiết chỗ nghỉ *',
            hint: 'Giới thiệu nét đặc sắc, không gian, vị trí gần biển và các tiện ích độc quyền...',
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard() {
    final wardNames = kVungTauWards.map((w) => w.name).toList();
    if (_selectedWard.isNotEmpty && !wardNames.contains(_selectedWard)) {
      wardNames.insert(0, _selectedWard);
    }

    final topVungTauWards = [
      'Phường Thắng Tam (Bãi Sau)',
      'Phường 1 (Bãi Trước)',
      'Phường 2 (Bãi Dứa - Bãi Dâu)',
      'Phường 8',
    ];

    return _SectionCard(
      title: '2. Địa chỉ & Vị trí tại Vũng Tàu',
      stepBadge: 'BƯỚC 2',
      icon: LucideIcons.mapPin,
      subtitle:
          'Định vị chính xác chỗ nghỉ tại thành phố biển Vũng Tàu giúp khách dễ dàng tìm đường và đặt phòng.',
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gợi ý khu vực trọng điểm Vũng Tàu:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: topVungTauWards.map((w) {
                final match = kVungTauWards.firstWhere(
                  (element) => w.startsWith(element.name),
                  orElse: () => kVungTauWards.first,
                );
                final isSelected = _selectedWard == match.name;
                return ChoiceChip(
                  label: Text(w, style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  selectedColor: AppColors.brandSoft,
                  onSelected: (_) => _handleWardChanged(match.name),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          key: const Key('listing_address_input'),
          controller: _addressController,
          decoration: _fieldDecoration(
            'Địa chỉ cụ thể (Số nhà, tên đường) *',
            hint: 'Ví dụ: 164B Phan Chu Trinh, Phường 2, Vũng Tàu',
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 540;
            final wardField = _buildDropdownField<String>(
              dropdownKey: const Key('listing_ward_dropdown'),
              label: 'Phường / Xã *',
              value: _selectedWard,
              items: wardNames
                  .map(
                    (name) => DropdownMenuItem<String>(
                      value: name,
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: _handleWardChanged,
            );
            final cityField = TextFormField(
              initialValue: ' (Quốc gia: VN • Tiền tệ: VND)',
              readOnly: true,
              decoration: _fieldDecoration('Thành phố / Quốc gia / Tiền tệ'),
            );
            if (isWide) {
              return Row(
                children: [
                  Expanded(child: wardField),
                  const SizedBox(width: 14),
                  Expanded(child: cityField),
                ],
              );
            }
            return Column(
              children: [
                wardField,
                const SizedBox(height: 14),
                cityField,
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 540;
            final latField = TextFormField(
              key: const Key('listing_lat_input'),
              controller: _latController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _fieldDecoration('Vĩ độ (Latitude: 10.30 – 10.48) *'),
            );
            final lngField = TextFormField(
              key: const Key('listing_lng_input'),
              controller: _lngController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  _fieldDecoration('Kinh độ (Longitude: 106.98 – 107.20) *'),
            );
            if (isWide) {
              return Row(
                children: [
                  Expanded(child: latField),
                  const SizedBox(width: 14),
                  Expanded(child: lngField),
                ],
              );
            }
            return Column(
              children: [
                latField,
                const SizedBox(height: 14),
                lngField,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildAirbnbCounterRow({
    required String label,
    required String subtitle,
    required IconData icon,
    required TextEditingController controller,
    required Key textKey,
    required int min,
    required int max,
  }) {
    final currentVal = int.tryParse(controller.text.trim()) ?? min;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            icon: const Icon(LucideIcons.minusCircle, size: 22),
            color: currentVal > min ? AppColors.textPrimary : Colors.grey.shade400,
            onPressed: currentVal > min
                ? () {
                    final next = currentVal - 1;
                    setState(() {
                      controller.text = '';
                    });
                  }
                : null,
          ),
          SizedBox(
            width: 38,
            child: TextFormField(
              key: textKey,
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            icon: const Icon(LucideIcons.plusCircle, size: 22),
            color: currentVal < max ? AppColors.primary : Colors.grey.shade400,
            onPressed: currentVal < max
                ? () {
                    final next = currentVal + 1;
                    setState(() {
                      controller.text = '';
                    });
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityAndPricingCard() {
    return _SectionCard(
      title: '3. Sức chứa, Phòng & Định giá chuẩn Airbnb',
      stepBadge: 'BƯỚC 3',
      icon: LucideIcons.users,
      subtitle:
          'Khách tìm kiếm chỗ nghỉ dựa trên số lượng khách và phòng ngủ. Hãy thiết lập giá linh hoạt để tối ưu doanh thu cuối tuần.',
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 640;
            final guestStepper = _buildAirbnbCounterRow(
              label: 'Khách tối đa',
              subtitle: 'Sức chứa lớn nhất',
              icon: LucideIcons.users,
              controller: _maxGuestsController,
              textKey: const Key('listing_max_guests_input'),
              min: 1,
              max: 50,
            );
            final bedroomStepper = _buildAirbnbCounterRow(
              label: 'Phòng ngủ',
              subtitle: 'Không gian riêng tư',
              icon: LucideIcons.bedDouble,
              controller: _bedroomsController,
              textKey: const Key('listing_bedrooms_input'),
              min: 0,
              max: 20,
            );
            final bedStepper = _buildAirbnbCounterRow(
              label: 'Số giường',
              subtitle: 'Giường đôi/đơn',
              icon: LucideIcons.bed,
              controller: _bedsController,
              textKey: const Key('listing_beds_input'),
              min: 1,
              max: 30,
            );
            final bathStepper = _buildAirbnbCounterRow(
              label: 'Phòng tắm (WC)',
              subtitle: 'Số phòng vệ sinh',
              icon: LucideIcons.bath,
              controller: _bathroomsController,
              textKey: const Key('listing_bathrooms_input'),
              min: 1,
              max: 20,
            );

            if (isWide) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: guestStepper),
                      const SizedBox(width: 12),
                      Expanded(child: bedroomStepper),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: bedStepper),
                      const SizedBox(width: 12),
                      Expanded(child: bathStepper),
                    ],
                  ),
                ],
              );
            }
            return Column(
              children: [
                guestStepper,
                const SizedBox(height: 10),
                bedroomStepper,
                const SizedBox(height: 10),
                bedStepper,
                const SizedBox(height: 10),
                bathStepper,
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.coins, size: 18, color: Color(0xFF15803D)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chiến lược giá Vũng Tàu (Đêm thường vs Cuối tuần):',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF86EFAC)),
                    label: const Text('+20% Thứ 6 & Thứ 7',
                        style: TextStyle(fontSize: 11, color: Color(0xFF166534))),
                    onPressed: () {
                      final base = int.tryParse(
                              _basePriceController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
                          0;
                      if (base > 0) {
                        final weekend = (base * 1.2).round();
                        setState(() {
                          _weekendPriceController.text = '';
                          _handleWeekendPriceChanged('');
                        });
                      }
                    },
                  ),
                  ActionChip(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF86EFAC)),
                    label: const Text('+30% Mùa cao điểm',
                        style: TextStyle(fontSize: 11, color: Color(0xFF166534))),
                    onPressed: () {
                      final base = int.tryParse(
                              _basePriceController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
                          0;
                      if (base > 0) {
                        final weekend = (base * 1.3).round();
                        setState(() {
                          _weekendPriceController.text = '';
                          _handleWeekendPriceChanged('');
                        });
                      }
                    },
                  ),
                  ActionChip(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF86EFAC)),
                    label: const Text('Bằng giá ngày thường',
                        style: TextStyle(fontSize: 11, color: Color(0xFF166534))),
                    onPressed: () {
                      final base = _basePriceController.text.trim();
                      setState(() {
                        _weekendPriceController.text = base;
                        _handleWeekendPriceChanged(base);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 640;
            final fields = [
              TextFormField(
                key: const Key('listing_base_price_input'),
                controller: _basePriceController,
                keyboardType: TextInputType.number,
                onChanged: _handleBasePriceChanged,
                decoration: _fieldDecoration('Giá ngày thường / đêm (VND) *'),
              ),
              TextFormField(
                key: const Key('listing_weekend_price_input'),
                controller: _weekendPriceController,
                keyboardType: TextInputType.number,
                onChanged: _handleWeekendPriceChanged,
                decoration: _fieldDecoration('Giá cuối tuần (VND) *'),
              ),
              TextFormField(
                key: const Key('listing_cleaning_fee_input'),
                controller: _cleaningFeeController,
                keyboardType: TextInputType.number,
                decoration: _fieldDecoration('Phí dọn dẹp (VND)'),
              ),
              TextFormField(
                key: const Key('listing_surcharge_input'),
                controller: _surchargeController,
                keyboardType: TextInputType.number,
                decoration: _fieldDecoration('Phụ thu thêm khách (VND)'),
              ),
            ];
            if (isWide) {
              return Row(
                children: [
                  for (var i = 0; i < fields.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: fields[i]),
                  ],
                ],
              );
            }
            return Column(
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  fields[i],
                ],
              ],
            );
          },
        ),
      ],
    );
  }

    Widget _buildPoliciesAndRulesCard() {
    return _SectionCard(
      title: '4. Chính sách lưu trú & Nội quy chỗ nghỉ',
      stepBadge: 'BƯỚC 4',
      icon: LucideIcons.shieldCheck,
      subtitle:
          'Chính sách đặt phòng rõ ràng giúp giảm thiểu tỷ lệ hủy phòng và bảo vệ quyền lợi của chủ nhà.',
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 640;
            final fields = [
              TextFormField(
                key: const Key('listing_min_nights_input'),
                controller: _minNightsController,
                keyboardType: TextInputType.number,
                decoration: _fieldDecoration('Số đêm tối thiểu *'),
              ),
              TextFormField(
                key: const Key('listing_max_nights_input'),
                controller: _maxNightsController,
                keyboardType: TextInputType.number,
                decoration: _fieldDecoration('Số đêm tối đa'),
              ),
              _buildDropdownField<String>(
                dropdownKey: const Key('listing_checkin_dropdown'),
                label: 'Nhận phòng từ *',
                value: _checkInFrom,
                items: kHalfHourTimeOptions
                    .map(
                      (t) => DropdownMenuItem<String>(value: t, child: Text(t)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _checkInFrom = v);
                },
              ),
              _buildDropdownField<String>(
                dropdownKey: const Key('listing_checkout_dropdown'),
                label: 'Trả phòng trước *',
                value: _checkOutBefore,
                items: kHalfHourTimeOptions
                    .map(
                      (t) => DropdownMenuItem<String>(value: t, child: Text(t)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _checkOutBefore = v);
                },
              ),
            ];
            if (isWide) {
              return Row(
                children: [
                  for (var i = 0; i < fields.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: fields[i]),
                  ],
                ],
              );
            }
            return Column(
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  fields[i],
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 540;
            final cancelField = _buildDropdownField<HostCancellationPolicy>(
              dropdownKey: const Key('listing_cancellation_dropdown'),
              label: 'Chính sách hủy phòng *',
              value: _cancellationPolicy,
              items: HostCancellationPolicy.values
                  .map(
                    (e) => DropdownMenuItem<HostCancellationPolicy>(
                      value: e,
                      child: Text(e.labelVi, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _cancellationPolicy = v);
              },
            );
            final statusField = !_isEditMode
                ? _buildDropdownField<HostListingStatus>(
                    dropdownKey: const Key('listing_status_dropdown'),
                    label: 'Trạng thái khi lưu *',
                    value: _initialCreateStatus ==
                            HostListingStatus.pendingApproval
                        ? HostListingStatus.pendingApproval
                        : HostListingStatus.draft,
                    items: const [
                      DropdownMenuItem<HostListingStatus>(
                        value: HostListingStatus.draft,
                        child: Text('Lưu nháp (draft)'),
                      ),
                      DropdownMenuItem<HostListingStatus>(
                        value: HostListingStatus.pendingApproval,
                        child: Text('Gửi admin duyệt (pending_approval)'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _initialCreateStatus = v);
                    },
                  )
                : TextFormField(
                    controller: _quietHoursController,
                    decoration: _fieldDecoration('Khung giờ yên lặng'),
                  );

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: cancelField),
                  const SizedBox(width: 14),
                  Expanded(child: statusField),
                ],
              );
            }
            return Column(
              children: [
                cancelField,
                const SizedBox(height: 14),
                statusField,
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _instantBookEnabled
                ? const Color(0xFFFEF9C3)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _instantBookEnabled
                  ? const Color(0xFFFACC15)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _instantBookEnabled
                      ? const Color(0xFFCA8A04)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  LucideIcons.zap,
                  size: 18,
                  color: _instantBookEnabled ? Colors.white : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đặt phòng nhanh (Instant Book)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Khách được xác nhận tức thì mà không cần chủ nhà duyệt thủ công.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Checkbox(
                key: const Key('listing_instant_book_checkbox'),
                value: _instantBookEnabled,
                activeColor: const Color(0xFFCA8A04),
                onChanged: (v) => setState(() => _instantBookEnabled = v == true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Nội quy cơ bản:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilterChip(
              avatar: const Icon(LucideIcons.cigarette, size: 14),
              shape: const StadiumBorder(),
              label: const Text('Cho phép hút thuốc'),
              selected: _smokingAllowed,
              onSelected: (v) => setState(() => _smokingAllowed = v),
            ),
            FilterChip(
              avatar: const Icon(LucideIcons.dog, size: 14),
              shape: const StadiumBorder(),
              label: const Text('Cho phép thú cưng'),
              selected: _petsAllowed,
              onSelected: (v) => setState(() => _petsAllowed = v),
            ),
            FilterChip(
              avatar: const Icon(LucideIcons.partyPopper, size: 14),
              shape: const StadiumBorder(),
              label: const Text('Cho phép tiệc / BBQ'),
              selected: _partyAllowed,
              onSelected: (v) => setState(() => _partyAllowed = v),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmenitiesCard() {
    IconData getAmenityIcon(String name) {
      final lower = name.toLowerCase();
      if (lower.contains('wifi') || lower.contains('mạng')) return LucideIcons.wifi;
      if (lower.contains('bơi') || lower.contains('pool') || lower.contains('hồ')) return LucideIcons.waves;
      if (lower.contains('lạnh') || lower.contains('điều hòa') || lower.contains('ac')) return LucideIcons.snowflake;
      if (lower.contains('bbq') || lower.contains('nướng') || lower.contains('bếp')) return LucideIcons.flame;
      if (lower.contains('xe') || lower.contains('đỗ') || lower.contains('parking')) return LucideIcons.car;
      if (lower.contains('tivi') || lower.contains('tv')) return LucideIcons.tv;
      if (lower.contains('giặt') || lower.contains('sấy')) return LucideIcons.shirt;
      return LucideIcons.check;
    }

    return _SectionCard(
      title: '5. Tiện nghi chỗ nghỉ (Amenities)',
      stepBadge: 'BƯỚC 5',
      icon: LucideIcons.sparkles,
      subtitle:
          'Khách lọc chỗ nghỉ nhiều nhất theo Tiện nghi (Hồ bơi riêng, Wifi, BBQ, Chỗ đỗ xe). Hãy chọn đầy đủ tiện ích thực tế.',
      children: [
        if (_availableAmenities.isEmpty)
          const Text(
            'Danh sách tiện nghi sẽ được đồng bộ từ máy chủ khi trực tuyến.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableAmenities.map((amenity) {
              final rawId = amenity['amenityId'] ?? amenity['id'];
              final id = rawId is num
                  ? rawId.toInt()
                  : (int.tryParse('') ?? 0);
              final name =
                  (amenity['name'] ?? amenity['label'] ?? 'Tiện nghi #')
                      .toString();
              final selected = _selectedAmenityIds.contains(id);
              final icon = getAmenityIcon(name);

              return FilterChip(
                key: Key('listing_amenity_chip_'),
                avatar: Icon(icon, size: 14, color: selected ? AppColors.primary : AppColors.textSecondary),
                shape: const StadiumBorder(),
                label: Text(name),
                selected: selected,
                selectedColor: AppColors.brandSoft,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedAmenityIds.add(id);
                    } else {
                      _selectedAmenityIds.remove(id);
                    }
                  });
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildImagesAndAiCard() {
    return _SectionCard(
      title: '6. Ảnh chỗ nghỉ (R2 Cloud Storage) & AI Vision 22 Nhãn',
      stepBadge: 'BƯỚC 6',
      icon: LucideIcons.camera,
      subtitle:
          'Ảnh thật góc rộng, chụp ban ngày. Cloudflare R2 lưu trữ phân tán và AI Vision tự động nhận diện 22 không gian.',
      children: [
        InkWell(
          key: const Key('listing_pick_images_btn'),
          borderRadius: BorderRadius.circular(18),
          onTap: _saving ? null : _pickImagesFromDevice,
          child: Container(
            constraints: const BoxConstraints(minHeight: 110),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFD),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.brandSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.camera,
                    size: 22,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chọn ảnh thật từ thiết bị của bạn',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Hỗ trợ JPG, PNG, WebP hoặc GIF. Tối đa 30 ảnh, mỗi ảnh 5MB.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.imagePlus,
                          size: 14, color: Colors.white),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Tải ảnh lên ngay',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_existingImages.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Text(
                'ẢNH ĐÃ LƯU ()',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              if (_isEditMode)
                OutlinedButton.icon(
                  key: const Key('listing_analyze_all_ai_btn'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(180, 48),
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed:
                      _analyzingAllAi ? null : _handleAnalyzeAllImagesWithAi,
                  icon: const Icon(
                    LucideIcons.sparkles,
                    size: 16,
                    color: AppColors.iconStrong,
                  ),
                  label: Text(
                    _analyzingAllAi
                        ? 'Đang phân tích ảnh...'
                        : 'Phân tích ảnh bằng AI',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth >= 760
                  ? 3
                  : (constraints.maxWidth >= 480 ? 2 : 1);
              const spacing = 12.0;
              final itemWidth =
                  (constraints.maxWidth - (spacing * (crossCount - 1))) /
                      crossCount;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (var idx = 0; idx < _existingImages.length; idx++)
                    SizedBox(
                      width: itemWidth,
                      child: _buildExistingImageCard(_existingImages[idx], idx),
                    ),
                ],
              );
            },
          ),
        ],
        if (_queuedImages.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                'ẢNH MỚI CHỜ UPLOAD ()',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(140, 48),
                  foregroundColor: AppColors.textPrimary,
                ),
                onPressed: _saving ? null : _clearAllQueuedImages,
                icon: const Icon(
                  LucideIcons.trash2,
                  size: 16,
                  color: AppColors.iconStrong,
                ),
                label: const Text('Xóa toàn bộ ảnh mới đã chọn'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth >= 760
                  ? 3
                  : (constraints.maxWidth >= 480 ? 2 : 1);
              const spacing = 12.0;
              final itemWidth =
                  (constraints.maxWidth - (spacing * (crossCount - 1))) /
                      crossCount;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (var idx = 0; idx < _queuedImages.length; idx++)
                    SizedBox(
                      width: itemWidth,
                      child: _buildQueuedImageCard(_queuedImages[idx], idx),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

    Widget _buildExistingImageCard(ExistingListingImage image, int index) {
    final isAnalyzing = _analyzingImageIds.contains(image.imageId);
    final isSavingTags = _savingTagImageIds.contains(image.imageId);
    final currentTagCodes = image.tags.map((t) => t.tag).toSet();
    final availableTaxonomies =
        _tagTaxonomies.where((t) => !currentTagCodes.contains(t.code)).toList();

    String statusLabel = 'Chưa phân tích';
    Color statusColor = AppColors.textSecondary;
    if (isAnalyzing || image.aiAnalysisStatus == 'analyzing') {
      statusLabel = 'Đang phân tích ảnh bằng AI...';
      statusColor = AppColors.textStrong;
    } else if (image.aiAnalysisStatus == 'failed' ||
        image.aiAnalysisStatus == 'analysis_failed') {
      statusLabel = 'Phân tích lỗi, thử lại';
      statusColor = const Color(0xFFBE123C);
    } else if (image.tags.isNotEmpty || image.aiAnalysisStatus == 'analyzed') {
      statusLabel = 'Đã gắn tag (${image.tags.length})';
      statusColor = const Color(0xFF047857);
    }

    return Container(
      key: Key('existing_image_card_${image.imageId}'),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: image.isCover ? AppColors.primary : AppColors.border,
          width: image.isCover ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
            child: Image.network(
              image.url,
              height: 140,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 140,
                color: AppColors.surfaceMuted,
                alignment: Alignment.center,
                child: const Icon(
                  LucideIcons.image,
                  color: AppColors.iconMuted,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        image.displayTitle?.isNotEmpty == true
                            ? image.displayTitle!
                            : 'Ảnh chỗ nghỉ ${index + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (image.isCover)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Ảnh bìa',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                if (image.roomType != null &&
                    image.roomType!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Không gian: ${image.roomType}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (image.aiConfidence != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Độ tin cậy AI: ${(image.aiConfidence! <= 1 ? image.aiConfidence! * 100 : image.aiConfidence!).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (image.aiWarnings.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Cảnh báo: ${image.aiWarnings.join(", ")}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ],
                if (image.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: image.tags.map((tag) {
                      return InputChip(
                        key: Key('image_${image.imageId}_tag_${tag.tag}'),
                        shape: const StadiumBorder(),
                        label: Text(
                          tag.labelVi,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onDeleted: isSavingTags
                            ? null
                            : () {
                                final next = image.tags
                                    .map((t) => t.tag)
                                    .where((code) => code != tag.tag)
                                    .toList();
                                _handleUpdateImageTags(image, next);
                              },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: Key('image_${image.imageId}_add_tag_dropdown'),
                      isExpanded: true,
                      isDense: true,
                      value: null,
                      hint: Text(
                        'Thêm tag thiếu (${availableTaxonomies.length})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      items: availableTaxonomies
                          .map(
                            (tax) => DropdownMenuItem<String>(
                              value: tax.code,
                              child: Text(
                                tax.labelVi,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: isSavingTags || availableTaxonomies.isEmpty
                          ? null
                          : (code) {
                              if (code == null || code.isEmpty) return;
                              final next = [
                                ...image.tags.map((t) => t.tag),
                                code,
                              ];
                              _handleUpdateImageTags(image, next);
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    TextButton(
                      key: Key('image_${image.imageId}_analyze_btn'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(72, 48),
                      ),
                      onPressed: isAnalyzing
                          ? null
                          : () => _handleAnalyzeSingleImage(image.imageId),
                      child: Text(
                        statusLabel.contains('lỗi')
                            ? 'Thử lại'
                            : 'Phân tích AI',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (!image.isCover)
                      TextButton(
                        key: Key('image_${image.imageId}_cover_btn'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(72, 48),
                        ),
                        onPressed: () => _handleSetCoverImage(image.imageId),
                        child: const Text(
                          'Đặt bìa',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    if (index > 0)
                      IconButton(
                        key: Key('image_${image.imageId}_move_left_btn'),
                        constraints:
                            const BoxConstraints(minWidth: 48, minHeight: 48),
                        tooltip: 'Chuyển lên trước',
                        onPressed: () => _moveExistingImage(index, -1),
                        icon: const Icon(
                          LucideIcons.arrowLeft,
                          size: 16,
                          color: AppColors.iconStrong,
                        ),
                      ),
                    if (index < _existingImages.length - 1)
                      IconButton(
                        key: Key('image_${image.imageId}_move_right_btn'),
                        constraints:
                            const BoxConstraints(minWidth: 48, minHeight: 48),
                        tooltip: 'Chuyển ra sau',
                        onPressed: () => _moveExistingImage(index, 1),
                        icon: const Icon(
                          LucideIcons.arrowRight,
                          size: 16,
                          color: AppColors.iconStrong,
                        ),
                      ),
                    TextButton(
                      key: Key('image_${image.imageId}_delete_btn'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(64, 48),
                        foregroundColor: const Color(0xFFBE123C),
                      ),
                      onPressed: () => _handleDeleteExistingImage(image),
                      child: const Text(
                        'Xóa',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueuedImageCard(QueuedListingImage item, int index) {
    final isFutureCover = _existingImages.isEmpty && index == 0;
    return Container(
      key: Key('queued_image_card_${item.id}'),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isFutureCover ? AppColors.primary : AppColors.border,
          width: isFutureCover ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
            child: Image.memory(
              item.file.bytes,
              height: 130,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 130,
                color: AppColors.surfaceMuted,
                alignment: Alignment.center,
                child: const Icon(
                  LucideIcons.image,
                  color: AppColors.iconMuted,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.file.name} (${item.file.formattedSize})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isFutureCover)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Ảnh bìa',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.status.labelVi,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: item.status == QueuedImageUploadStatus.failed ||
                            item.status ==
                                QueuedImageUploadStatus.analysisFailed
                        ? const Color(0xFFBE123C)
                        : AppColors.primary,
                  ),
                ),
                if (item.status == QueuedImageUploadStatus.uploading) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: item.progress, minHeight: 4),
                ],
                if (item.error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.error!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFBE123C),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (item.status == QueuedImageUploadStatus.failed &&
                        _isEditMode)
                      TextButton(
                        key: Key('queued_image_retry_${item.id}'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(72, 48),
                        ),
                        onPressed: () => _retryFailedQueuedImage(item),
                        child: const Text('Thử lại'),
                      ),
                    if (index > 0)
                      IconButton(
                        key: Key('queued_image_move_left_${item.id}'),
                        constraints:
                            const BoxConstraints(minWidth: 48, minHeight: 48),
                        tooltip: 'Chuyển lên trước',
                        onPressed: () => _moveQueuedImage(index, -1),
                        icon: const Icon(
                          LucideIcons.arrowLeft,
                          size: 16,
                          color: AppColors.iconStrong,
                        ),
                      ),
                    if (index < _queuedImages.length - 1)
                      IconButton(
                        key: Key('queued_image_move_right_${item.id}'),
                        constraints:
                            const BoxConstraints(minWidth: 48, minHeight: 48),
                        tooltip: 'Chuyển ra sau',
                        onPressed: () => _moveQueuedImage(index, 1),
                        icon: const Icon(
                          LucideIcons.arrowRight,
                          size: 16,
                          color: AppColors.iconStrong,
                        ),
                      ),
                    if (item.status != QueuedImageUploadStatus.uploading &&
                        item.status != QueuedImageUploadStatus.analyzing)
                      TextButton(
                        key: Key('queued_image_remove_${item.id}'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(64, 48),
                          foregroundColor: const Color(0xFFBE123C),
                        ),
                        onPressed: () => _removeQueuedImage(item.id),
                        child: const Text('Xóa'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterActions() {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 12,
      runSpacing: 12,
      children: [
        if (_isEditMode)
          OutlinedButton.icon(
            key: const Key('listing_submit_approval_btn'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(160, 48),
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: _saving
                ? null
                : () => _submitForm(
                      targetStatus: HostListingStatus.pendingApproval,
                    ),
            icon: const Icon(
              LucideIcons.send,
              size: 16,
              color: AppColors.iconStrong,
            ),
            label: const Text('Lưu & Gửi duyệt'),
          ),
        ElevatedButton.icon(
          key: const Key('listing_save_btn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(180, 48),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          onPressed: _saving ? null : () => _submitForm(),
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(LucideIcons.save, size: 18, color: Colors.white),
          label: Text(
            _saving
                ? 'Đang lưu...'
                : (_isEditMode ? 'Cập nhật chỗ nghỉ' : 'Lưu chỗ nghỉ'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.surfaceBase,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  Widget _buildStatusBanner({
    Key? key,
    required String text,
    required Color bg,
    required Color border,
    required Color fg,
    required IconData icon,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.iconStrong),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? stepBadge;
  final IconData? icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    this.subtitle,
    this.stepBadge,
    this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceBase,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.brandSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (stepBadge != null) ...[
                        Text(
                          stepBadge!.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}
