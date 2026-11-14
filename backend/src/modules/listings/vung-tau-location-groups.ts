/**
 * Danh mục nhóm khu vực địa lý và giải thuật kiểm tra tọa độ thuộc địa giới Vũng Tàu cho phân hệ `listings`.
 */
// CONFLICT-RESOLVED: Chuyển dữ liệu địa giới và nhóm vị trí Vũng Tàu từ `src/common/vung-tau-location-groups.ts` về `src/modules/listings/`.
export const VUNG_TAU_LOCATION_GROUPS = {
    "Bãi Sau": [
        "Back Beach",
        "Hoàng Hoa Thám",
        "Phan Chu Trinh",
        "Lê Hồng Phong",
        "Nguyễn An Ninh",
        "Phan Văn Trị",
        "La Văn Cầu",
        "Phó Đức Chính",
        "Võ Thị Sáu",
        "Nguyễn Hiền",
        "Trần Quý Cáp",
        "Hồ Quý Ly",
        "Bàu Sen",
        "Thi Sách",
        "Mạc Thanh Đạm",
        "Phan Huy Chú",
        "Phan Huy Ích",
        "Lạc Long Quân",
        "Bình Giã",
        "Bãi Sau Vũng Tàu",
        "Bãi tắm bãi sau",
        "Tào Mạt",
        "Hoàng Trung Thông",
        "Đồi Ngọc Tước",
        "Trần Văn Thời",
        "Dương Minh Châu",
        "Nguyễn Thị Minh Khai",
        "Hồ Quý Ly",
        "Nguyễn Hữu Tiến",
        "Trần Bình Trọng",
        "Trần Quý Cáp",
    ],
    "Bãi Trước": [
        "Front Beach",
        "Tầm Dương",
        "Hạ Long",
        "Quang Trung",
        "Ba Cu",
        "Lê Lợi",
        "Lê Ngọc Hân",
        "Vi Ba",
        "Hải Đăng",
        "Lê Quý Đôn",
        "Trần Hưng Đạo",
        "Đồ Chiểu",
        "Trưng Trắc",
        "Trưng Nhị",
        "Lý Thường Kiệt",
        "Lê Lai",
    ],
    "Long Cung": [
        "Long Cung",
        "Bãi Long Cung",
        "Hà Huy Tập",
        "Nguyễn Đình Tứ",
        "3 Tháng 2",
        "Ba Vì",
        "Hoành Sơn",
        "Tản Viên",
        "An Hải",
        "Thùy Dương",
    ],
    "Chí Linh": [
        "Chí Linh",
        "Khu Chí Linh",
        "Bãi Chí Linh",
        "Nguyễn Hữu Cảnh",
        "Nguyễn An Ninh nối dài",
        "Đường 3/2 Chí Linh",
    ],
    "Thủy Tiên": [
        "Thủy Tiên",
        "Bãi Thủy Tiên",
        "Khu du lịch Thủy Tiên",
        "D5",
        "D7",
        "Nguyễn Hữu Cảnh",
    ],
    "Trung tâm": [
        "Trung tâm",
        "Phường 1",
        "Phường 2",
        "Phường 3",
        "Nam Kỳ Khởi Nghĩa",
        "Trương Công Định",
        "Lê Lai",
        "Lý Thường Kiệt",
        "Nguyễn Văn Trỗi",
        "Bacu",
        "Ba Cu",
        "Đồ Chiểu",
        "Back Beach",
        "Hoàng Hoa Thám",
        "Phan Chu Trinh",
        "Lê Hồng Phong",
        "Nguyễn An Ninh",
        "Phan Văn Trị",
        "La Văn Cầu",
        "Phó Đức Chính",
        "Võ Thị Sáu",
        "Nguyễn Hiền",
        "Trần Quý Cáp",
        "Hồ Quý Ly",
        "Bàu Sen",
        "Thi Sách",
        "Mạc Thanh Đạm",
        "Phan Huy Chú",
        "Phan Huy Ích",
        "Lạc Long Quân",
        "Bình Giã",
        "Bãi Sau Vũng Tàu",
        "Bãi tắm bãi sau",
        "Tào Mạt",
        "Hoàng Trung Thông",
        "Đồi Ngọc Tước",
        "Trần Văn Thời",
        "Dương Minh Châu",
        "Nguyễn Thị Minh Khai",
        "Hồ Quý Ly",
        "Nguyễn Hữu Tiến",
        "Trần Bình Trọng",
        "Trần Quý Cáp",
    ],
    "Trần Phú": [
        "Trần Phú",
        "Tran Phu",
        "Bãi Dâu",
        "Dâu",
        "Bến Đình",
        "Sao Mai",
    ],
    "Thùy Vân": [
        "Thùy Vân",
        "Thuy Van",
        "Biển Thùy Vân",
        "Đường Thùy Vân",
        "Hoàng Hoa Thám",
        "La Văn Cầu",
        "Phó Đức Chính",
    ],
} as const;

export type LocationGroupName = keyof typeof VUNG_TAU_LOCATION_GROUPS;

export const VUNG_TAU_LOCATION_GROUP_NAMES = Object.keys(
    VUNG_TAU_LOCATION_GROUPS,
) as LocationGroupName[];

export const LOCATION_GROUP_AREA_KEYS: Record<LocationGroupName, string> = {
    "Bãi Sau": "bai_sau",
    "Bãi Trước": "bai_truoc",
    "Long Cung": "long_cung",
    "Chí Linh": "chi_linh",
    "Thủy Tiên": "thuy_tien",
    "Trung tâm": "trung_tam",
    "Trần Phú": "tran_phu",
    "Thùy Vân": "thuy_van",
};

// Giải thuật chuẩn hóa khung bao địa lý (Bounding Box) thành phố Vũng Tàu bao phủ cả bán đảo trung tâm và xã đảo Long Sơn (TC-024, TC-075):
export const VUNG_TAU_MAP_BOUNDS = {
    south: 10.28,
    west: 107.0,
    north: 10.5,
    east: 107.26,
} as const;

/**
 * Bảng băm ánh xạ ngược O(1) từ khóa định danh khu vực (`areaKey`) về tên hiển thị phân khu địa lý chuẩn (`LocationGroupName`).
 */
const AREA_KEY_TO_LOCATION_GROUP = new Map(
    Object.entries(LOCATION_GROUP_AREA_KEYS).map(([groupName, areaKey]) => [
        areaKey,
        groupName as LocationGroupName,
    ]),
);

export const LOCATION_GROUP_QUERY_ALIASES: Record<LocationGroupName, string[]> = {
    "Bãi Sau": ["bãi sau", "bai sau", "back beach"],
    "Bãi Trước": [
        "bãi trước",
        "bai truoc",
        "front beach",
        "tầm dương",
        "tam duong",
        "công viên tầm dương",
    ],
    "Long Cung": ["long cung", "bãi long cung", "bai long cung"],
    "Chí Linh": ["chí linh", "chi linh", "khu chí linh", "khu chi linh", "bãi chí linh", "bai chi linh"],
    "Thủy Tiên": ["thủy tiên", "thuy tien", "bãi thủy tiên", "bai thuy tien", "khu du lịch thủy tiên"],
    "Trung tâm": ["trung tâm", "trung tam", "phường 1", "phuong 1", "phường 2", "phuong 2", "ba cu"],
    "Trần Phú": ["trần phú", "tran phu", "bãi dâu", "bai dau", "bến đình", "ben dinh"],
    "Thùy Vân": ["thùy vân", "thuy van", "biển thùy vân", "bien thuy van", "đường thùy vân"],
};

/**
 * Giải thuật chuẩn hóa văn bản tiếng Việt về dạng chuỗi ký tự chữ-số không dấu phục vụ đối sánh bất biến:
 * - Phân rã ký tự tổ hợp Unicode theo chuẩn NFD (`Normalization Form Canonical Decomposition`) và loại bỏ toàn bộ dấu thanh thuộc dải Combining Diacritical Marks (`[\u0300-\u036f]`).
 * - Ánh xạ tường minh ký tự `đ/Đ` (`U+0111`/`U+0110` không tự phân rã qua NFD) sang `d/D`, chuyển chữ thường, thay thế dãy ký tự phi chữ-số (`[^a-z0-9]+`) bằng khoảng trắng và nén khoảng trắng liên tiếp.
 * - Độ phức tạp thời gian và không gian: O(n) với n là độ dài chuỗi đầu vào.
 */
export const normalizeVietnameseText = (text: string) =>
    text
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/đ/g, "d")
        .replace(/Đ/g, "D")
        .replace(/đ/g, "d")
        .replace(/Đ/g, "D")
        .toLowerCase()
        .trim()
        .replace(/[^a-z0-9]+/g, " ")
        .replace(/\s+/g, " ");

/**
 * Giải thuật kiểm tra kiểu bảo vệ (type guard) xác thực giá trị đầu vào có thuộc tập hữu hạn tên phân khu địa lý Vũng Tàu (`VUNG_TAU_LOCATION_GROUP_NAMES`) hay không.
 * Độ phức tạp: O(1) do số lượng nhóm phân khu cố định.
 */
export const isValidLocationGroup = (value: unknown): value is LocationGroupName =>
    typeof value === "string" &&
    VUNG_TAU_LOCATION_GROUP_NAMES.includes(value as LocationGroupName);

/**
 * Giải thuật ánh xạ trực tiếp O(1) từ tên hiển thị phân khu địa lý (`LocationGroupName`) sang khóa định danh chuẩn hóa snake_case (`areaKey`).
 */
export const getLocationGroupAreaKey = (groupName: LocationGroupName) =>
    LOCATION_GROUP_AREA_KEYS[groupName];

/**
 * Giải thuật tra cứu ngược O(1) qua bảng băm `AREA_KEY_TO_LOCATION_GROUP` để phân giải khóa `areaKey` về tên phân khu chuẩn; trả về `null` nếu không khớp.
 */
export const getLocationGroupNameFromAreaKey = (areaKey: string) =>
    AREA_KEY_TO_LOCATION_GROUP.get(areaKey) ?? null;

/**
 * Giải thuật phân giải hàng loạt và khử trùng lặp danh sách khóa khu vực (`areaKeys`) sang mảng tên phân khu hợp lệ bằng cấu trúc `Set`, bảo toàn thứ tự xuất hiện đầu tiên.
 * Độ phức tạp: O(k) với k là số lượng khóa đầu vào.
 */
export const getLocationGroupNamesFromAreaKeys = (areaKeys: string[]) =>
    Array.from(
        new Set(
            areaKeys
                .map(getLocationGroupNameFromAreaKey)
                .filter((groupName): groupName is LocationGroupName => Boolean(groupName)),
        ),
    );

/**
 * Giải thuật hợp nhất từ điển đối sánh của một phân khu địa lý, bao gồm tên gốc của nhóm, danh sách bí danh truy vấn (`LOCATION_GROUP_QUERY_ALIASES`) và danh sách tuyến đường/địa danh đặc trưng (`VUNG_TAU_LOCATION_GROUPS`).
 */
const getLocationGroupMatchTerms = (groupName: LocationGroupName) => [
    groupName,
    ...LOCATION_GROUP_QUERY_ALIASES[groupName],
    ...VUNG_TAU_LOCATION_GROUPS[groupName],
];

/**
 * Giải thuật xác định địa chỉ có thuộc một phân khu địa lý Vũng Tàu hay không:
 * - Chuẩn hóa không dấu cả chuỗi địa chỉ đầu vào và tập từ khóa đặc trưng của phân khu qua `normalizeVietnameseText`.
 * - Thực hiện đối sánh bao hàm chuỗi con (`includes`) có dừng sớm (short-circuit) ngay khi khớp ít nhất một tên đường, địa danh hoặc bí danh.
 * - Độ phức tạp: O(|address| + M * L) với M là số cụm từ của nhóm và L là độ dài trung bình mỗi cụm từ.
 */
export const isAddressInLocationGroup = (address: string, groupName: LocationGroupName) => {
    const normalizedAddress = normalizeVietnameseText(address);

    if (!normalizedAddress) {
        return false;
    }

    return getLocationGroupMatchTerms(groupName)
        .map(normalizeVietnameseText)
        .some((term) => term && normalizedAddress.includes(term));
};

/**
 * Giải thuật nhận diện đa phân khu địa lý từ chuỗi truy vấn tìm kiếm tự do:
 * - Chuẩn hóa truy vấn một lần và duyệt qua toàn bộ danh mục phân khu Vũng Tàu, thu thập mọi phân khu có từ khóa/tên đường xuất hiện trong truy vấn.
 * - Hỗ trợ tuyến đường giáp ranh thuộc đồng thời nhiều phân khu. Độ phức tạp: O(|query| + T) với T là tổng kích thước từ điển địa danh.
 */
export const detectLocationGroupsFromQuery = (query: string): LocationGroupName[] => {
    const normalizedQuery = normalizeVietnameseText(query);

    if (!normalizedQuery) {
        return [];
    }

    return VUNG_TAU_LOCATION_GROUP_NAMES.filter((groupName) =>
        getLocationGroupMatchTerms(groupName)
            .map(normalizeVietnameseText)
            .some((term) => term && normalizedQuery.includes(term)),
    );
};

/**
 * Giải thuật trích xuất phân khu địa lý ưu tiên đầu tiên khớp với chuỗi truy vấn tìm kiếm tự do; trả về `null` nếu không phát hiện địa danh tương ứng.
 */
export const detectLocationGroupFromQuery = (query: string): LocationGroupName | null =>
    detectLocationGroupsFromQuery(query)[0] ?? null;

/**
 * Giải thuật tính khoảng cách đường chim bay (trắc địa đại cự / great-circle distance) theo mét giữa hai tọa độ địa lý bằng công thức hình cầu Haversine:
 * - Đổi độ sang radian: dLat = (lat2 - lat1) * pi / 180, dLng = (lng2 - lng1) * pi / 180.
 * - Đại lượng Haversine: a = sin^2(dLat / 2) + cos(lat1) * cos(lat2) * sin^2(dLng / 2).
 * - Khoảng cách góc tâm c = 2 * atan2(sqrt(a), sqrt(1 - a)), suy ra khoảng cách d = R * c trên bán kính trung bình Trái Đất R = 6.371.000m.
 * - Độ phức tạp thời gian và không gian: O(1).
 */
export const getDistanceMeters = (
    lat1: number,
    lng1: number,
    lat2: number,
    lng2: number,
) => {
    const earthRadiusMeters = 6371000;
    const toRad = (value: number) => (value * Math.PI) / 180;

    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);

    const a =
        Math.sin(dLat / 2) ** 2 +
        Math.cos(toRad(lat1)) *
        Math.cos(toRad(lat2)) *
        Math.sin(dLng / 2) ** 2;

    return 2 * earthRadiusMeters * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
};

/**
 * Giải thuật kiểm tra bất biến miền giá trị vĩ độ hệ quy chiếu WGS84: số thực hữu hạn nằm trong đoạn đóng [-90, 90]. Độ phức tạp: O(1).
 */
export const isValidLatitude = (value: number) =>
    Number.isFinite(value) && value >= -90 && value <= 90;

/**
 * Giải thuật kiểm tra bất biến miền giá trị kinh độ hệ quy chiếu WGS84: số thực hữu hạn nằm trong đoạn đóng [-180, 180]. Độ phức tạp: O(1).
 */
export const isValidLongitude = (value: number) =>
    Number.isFinite(value) && value >= -180 && value <= 180;

/**
 * Giải thuật kiểm tra tọa độ địa lý (latitude, longitude) có nằm trong khung hình chữ nhật bao (Axis-Aligned Bounding Box) của khu vực Vũng Tàu (`VUNG_TAU_MAP_BOUNDS`: vĩ độ [10.295, 10.455], kinh độ [107.03, 107.18]) hay không.
 * Dùng để chặn sớm các tọa độ ngoài phạm vi kinh doanh trước khi lưu trữ hoặc truy vấn bán kính bản đồ. Độ phức tạp: O(1).
 */
export const isCoordinateInVungTauBounds = (latitude: number, longitude: number) =>
    Number.isFinite(latitude) &&
    Number.isFinite(longitude) &&
    latitude >= VUNG_TAU_MAP_BOUNDS.south &&
    latitude <= VUNG_TAU_MAP_BOUNDS.north &&
    longitude >= VUNG_TAU_MAP_BOUNDS.west &&
    longitude <= VUNG_TAU_MAP_BOUNDS.east;
