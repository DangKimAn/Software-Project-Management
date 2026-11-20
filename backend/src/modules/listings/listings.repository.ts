/**
 * Tầng tái xuất (repository facade) tập hợp các mô hình dữ liệu miền chỗ nghỉ (`Amenity`, `Listing`, `Review`, `User`)
 * nhằm chuẩn hóa điểm truy cập thực thể cho phân hệ tìm kiếm và hiển thị công khai.
 */
export { default as Amenity } from "../../models/amenity";
export { default as Listing } from "../../models/listing";
export { default as Review } from "../../models/review";
export { default as User } from "../../models/user";

