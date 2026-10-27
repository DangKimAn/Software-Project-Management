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

export const VUNG_TAU_MAP_BOUNDS = {
    south: 10.295,
    west: 107.03,
    north: 10.455,
    east: 107.18,
} as const;

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

export const isValidLocationGroup = (value: unknown): value is LocationGroupName =>
    typeof value === "string" &&
    VUNG_TAU_LOCATION_GROUP_NAMES.includes(value as LocationGroupName);

export const getLocationGroupAreaKey = (groupName: LocationGroupName) =>
    LOCATION_GROUP_AREA_KEYS[groupName];

export const getLocationGroupNameFromAreaKey = (areaKey: string) =>
    AREA_KEY_TO_LOCATION_GROUP.get(areaKey) ?? null;

export const getLocationGroupNamesFromAreaKeys = (areaKeys: string[]) =>
    Array.from(
        new Set(
            areaKeys
                .map(getLocationGroupNameFromAreaKey)
                .filter((groupName): groupName is LocationGroupName => Boolean(groupName)),
        ),
    );

const getLocationGroupMatchTerms = (groupName: LocationGroupName) => [
    groupName,
    ...LOCATION_GROUP_QUERY_ALIASES[groupName],
    ...VUNG_TAU_LOCATION_GROUPS[groupName],
];

export const isAddressInLocationGroup = (address: string, groupName: LocationGroupName) => {
    const normalizedAddress = normalizeVietnameseText(address);

    if (!normalizedAddress) {
        return false;
    }

    return getLocationGroupMatchTerms(groupName)
        .map(normalizeVietnameseText)
        .some((term) => term && normalizedAddress.includes(term));
};

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

export const detectLocationGroupFromQuery = (query: string): LocationGroupName | null =>
    detectLocationGroupsFromQuery(query)[0] ?? null;

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

export const isValidLatitude = (value: number) =>
    Number.isFinite(value) && value >= -90 && value <= 90;

export const isValidLongitude = (value: number) =>
    Number.isFinite(value) && value >= -180 && value <= 180;

export const isCoordinateInVungTauBounds = (latitude: number, longitude: number) =>
    Number.isFinite(latitude) &&
    Number.isFinite(longitude) &&
    latitude >= VUNG_TAU_MAP_BOUNDS.south &&
    latitude <= VUNG_TAU_MAP_BOUNDS.north &&
    longitude >= VUNG_TAU_MAP_BOUNDS.west &&
    longitude <= VUNG_TAU_MAP_BOUNDS.east;
