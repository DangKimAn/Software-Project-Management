const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { after, describe, it } = require("node:test");
const request = require("supertest");

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";
process.env.ALLOW_REFRESH_TOKEN_IN_BODY = "false";
process.env.ALLOW_REFRESH_TOKEN_IN_HEADER = "false";

const { createApp } = require("../src/app");
const tokenService = require("../src/modules/auth/token.service");
const authService = require("../src/modules/auth/auth.service");
const User = require("../src/models/user").default;
const sequelize = require("../src/config/database").default;

after(async () => {
    try {
        await sequelize.close();
    } catch {}
});

describe("identity vision schema and parsing", () => {
    it("validates and parses a full CCCD front response correctly", () => {
        const { identityVisionResponseSchema } = require("../src/modules/ai/identity-vision.service");

        const sampleResponse = {
            documentType: "cccd",
            side: "front",
            idNumber: "079090123456",
            fullName: "NGUYỄN VĂN AN",
            dateOfBirth: "15/08/1992",
            gender: "Nam",
            nationality: "Việt Nam",
            placeOfOrigin: "Vũng Tàu, Bà Rịa - Vũng Tàu",
            placeOfResidence: "123 Thùy Vân, Phường Thắng Tam, TP. Vũng Tàu",
            expiryDate: "15/08/2032",
            issueDate: null,
            issuePlace: null,
            mrz: null,
            isClear: true,
            isDocumentValid: true,
            confidence: 0.96,
            warnings: [],
            summaryVi: "CCCD mặt trước - NGUYỄN VĂN AN - Số: 079090123456",
        };

        const parsed = identityVisionResponseSchema.parse(sampleResponse);
        assert.equal(parsed.documentType, "cccd");
        assert.equal(parsed.side, "front");
        assert.equal(parsed.idNumber, "079090123456");
        assert.equal(parsed.fullName, "NGUYỄN VĂN AN");
        assert.equal(parsed.confidence, 0.96);
        assert.equal(parsed.isClear, true);
    });

    it("validates and parses a 9-digit CMND front response correctly", () => {
        const { identityVisionResponseSchema } = require("../src/modules/ai/identity-vision.service");

        const cmndSample = {
            documentType: "cmnd",
            side: "front",
            idNumber: "241234567",
            fullName: "NGUYỄN VĂN A",
            dateOfBirth: "15/05/1999",
            gender: null,
            nationality: null,
            placeOfOrigin: "Thọ Xuân, Thanh Hóa",
            placeOfResidence: "Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh",
            expiryDate: null,
            issueDate: null,
            issuePlace: null,
            mrz: null,
            isClear: true,
            isDocumentValid: true,
            confidence: 0.98,
            warnings: [],
            summaryVi: "CMND mặt trước - NGUYỄN VĂN A - Số: 241234567",
        };

        const parsed = identityVisionResponseSchema.parse(cmndSample);
        assert.equal(parsed.documentType, "cmnd");
        assert.equal(parsed.side, "front");
        assert.equal(parsed.idNumber, "241234567");
        assert.equal(parsed.fullName, "NGUYỄN VĂN A");
        assert.equal(parsed.placeOfOrigin, "Thọ Xuân, Thanh Hóa");
        assert.equal(parsed.placeOfResidence, "Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh");
        assert.equal(parsed.confidence, 0.98);
    });

    it("validates and parses a Passport response correctly", () => {
        const { identityVisionResponseSchema } = require("../src/modules/ai/identity-vision.service");

        const passportSample = {
            documentType: "passport",
            side: "front",
            idNumber: "P01234567",
            fullName: "NGUYỄN VĂN A",
            dateOfBirth: "15/05/1999",
            gender: "Nam",
            nationality: "VIỆT NAM",
            placeOfOrigin: "THỦ ĐÔ HÀ NỘI",
            placeOfResidence: null,
            expiryDate: "01/07/2034",
            issueDate: "01/07/2024",
            issuePlace: "CỤC QUẢN LÝ XUẤT NHẬP CẢNH",
            mrz: "P<VNMN GUYEN<<VAN<A<<<<<<<<<<<<<<<<<<<<<<<<<<",
            isClear: true,
            isDocumentValid: true,
            confidence: 0.98,
            warnings: [],
            summaryVi: "Hộ chiếu Việt Nam - NGUYỄN VĂN A - Số: P01234567",
        };

        const parsed = identityVisionResponseSchema.parse(passportSample);
        assert.equal(parsed.documentType, "passport");
        assert.equal(parsed.side, "front");
        assert.equal(parsed.idNumber, "P01234567");
        assert.equal(parsed.fullName, "NGUYỄN VĂN A");
        assert.equal(parsed.nationality, "VIỆT NAM");
        assert.equal(parsed.placeOfOrigin, "THỦ ĐÔ HÀ NỘI");
        assert.equal(parsed.confidence, 0.98);
    });

    it("validates and parses a Driver's License (GPLX) front response correctly", () => {
        const { identityVisionResponseSchema } = require("../src/modules/ai/identity-vision.service");

        const gplxSample = {
            documentType: "driver_license",
            side: "front",
            idNumber: "241234567890",
            fullName: "NGUYỄN VĂN A",
            dateOfBirth: "15/05/1999",
            gender: null,
            nationality: "VIỆT NAM",
            placeOfOrigin: null,
            placeOfResidence: "Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh",
            expiryDate: "15/05/2034",
            issueDate: "23/03/2024",
            issuePlace: "TRƯỞNG PHÒNG QLPT&NL",
            mrz: null,
            isClear: true,
            isDocumentValid: true,
            confidence: 0.98,
            warnings: [],
            summaryVi: "Giấy phép lái xe mặt trước - NGUYỄN VĂN A - Số: 241234567890",
        };

        const parsed = identityVisionResponseSchema.parse(gplxSample);
        assert.equal(parsed.documentType, "driver_license");
        assert.equal(parsed.side, "front");
        assert.equal(parsed.idNumber, "241234567890");
        assert.equal(parsed.fullName, "NGUYỄN VĂN A");
        assert.equal(parsed.expiryDate, "15/05/2034");
        assert.equal(parsed.issueDate, "23/03/2024");
        assert.equal(parsed.confidence, 0.98);
    });

    it("handles non-identity document (utility bill) with isDocumentValid: false", () => {
        const { identityVisionResponseSchema } = require("../src/modules/ai/identity-vision.service");

        const billSample = {
            documentType: "unknown",
            side: "unknown",
            idNumber: null,
            fullName: null,
            dateOfBirth: null,
            gender: null,
            nationality: null,
            placeOfOrigin: null,
            placeOfResidence: null,
            expiryDate: null,
            issueDate: null,
            issuePlace: null,
            mrz: null,
            isClear: true,
            isDocumentValid: false,
            confidence: 0.95,
            warnings: ["Không phải giấy tờ tùy thân, đây là hóa đơn tiền điện"],
            summaryVi: "Không phải giấy tờ tùy thân, là hóa đơn tiền điện",
        };

        const parsed = identityVisionResponseSchema.parse(billSample);
        assert.equal(parsed.documentType, "unknown");
        assert.equal(parsed.side, "unknown");
        assert.equal(parsed.isDocumentValid, false);
        assert.equal(parsed.idNumber, null);
        assert.ok(parsed.warnings.some((w: string) => w.includes("hóa đơn tiền điện")));
    });

    it("validates and parses CCCD with 'Không thời hạn' (elderly citizen)", () => {
        const { identityVisionResponseSchema } = require("../src/modules/ai/identity-vision.service");

        const elderlySample = {
            documentType: "cccd",
            side: "front",
            idNumber: "012345678901",
            fullName: "NGUYỄN VĂN A",
            dateOfBirth: "01/01/1950",
            gender: "Nam",
            nationality: "Việt Nam",
            placeOfOrigin: "Hà Nội",
            placeOfResidence: "Hà Nội",
            expiryDate: "Không thời hạn",
            issueDate: null,
            issuePlace: null,
            mrz: null,
            isClear: true,
            isDocumentValid: true,
            confidence: 0.98,
            warnings: [],
            summaryVi: "CCCD mặt trước - NGUYỄN VĂN A - Số: 012345678901",
        };

        const parsed = identityVisionResponseSchema.parse(elderlySample);
        assert.equal(parsed.documentType, "cccd");
        assert.equal(parsed.idNumber, "012345678901");
        assert.equal(parsed.expiryDate, "Không thời hạn");
        assert.equal(parsed.isDocumentValid, true);
    });

    it("validates and parses expired CCCD with expiration warning", () => {
        const { identityVisionResponseSchema } = require("../src/modules/ai/identity-vision.service");

        const expiredSample = {
            documentType: "cccd",
            side: "front",
            idNumber: "012345678901",
            fullName: "NGUYỄN VĂN A",
            dateOfBirth: "15/05/1999",
            gender: "Nam",
            nationality: "Việt Nam",
            placeOfOrigin: "Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh",
            placeOfResidence: "123 Đường Nguyễn Huệ, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh",
            expiryDate: "15/05/2021",
            issueDate: null,
            issuePlace: null,
            mrz: null,
            isClear: true,
            isDocumentValid: true,
            confidence: 0.99,
            warnings: ["Giấy tờ đã hết hạn sử dụng"],
            summaryVi: "CCCD mặt trước - NGUYỄN VĂN A - Số: 012345678901",
        };

        const parsed = identityVisionResponseSchema.parse(expiredSample);
        assert.equal(parsed.documentType, "cccd");
        assert.equal(parsed.expiryDate, "15/05/2021");
        assert.ok(parsed.warnings.some((w: string) => w.includes("hết hạn")));
    });

    it("validates and parses CCCD with glare warning and reduced clarity", () => {
        const { identityVisionResponseSchema } = require("../src/modules/ai/identity-vision.service");

        const glareSample = {
            documentType: "cccd",
            side: "front",
            idNumber: "012345678901",
            fullName: "NGUYỄN VĂN A",
            dateOfBirth: "15/05/1999",
            gender: "Nam",
            nationality: "Việt Nam",
            placeOfOrigin: "Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh",
            placeOfResidence: "123 Đường Nguyễn Huệ, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh",
            expiryDate: "15/05/2039",
            issueDate: null,
            issuePlace: null,
            mrz: null,
            isClear: false,
            isDocumentValid: true,
            confidence: 0.85,
            warnings: ["Ảnh bị lóa sáng che khuất một phần vùng họ tên"],
            summaryVi: "CCCD mặt trước - NGUYỄN VĂN A - Số: 012345678901",
        };

        const parsed = identityVisionResponseSchema.parse(glareSample);
        assert.equal(parsed.documentType, "cccd");
        assert.equal(parsed.isClear, false);
        assert.ok(parsed.warnings.some((w: string) => w.includes("lóa sáng")));
    });

    it("handles back side of CCCD with null front-only fields", () => {
        const { identityVisionResponseSchema } = require("../src/modules/ai/identity-vision.service");

        const backSideSample = {
            documentType: "cccd",
            side: "back",
            idNumber: null,
            fullName: null,
            dateOfBirth: null,
            gender: null,
            nationality: null,
            placeOfOrigin: null,
            placeOfResidence: null,
            expiryDate: null,
            issueDate: "10/10/2021",
            issuePlace: "CỤC TRƯỞNG CỤC CẢNH SÁT QUẢN LÝ HÀNH CHÍNH VỀ TRẬT TỰ XÃ HỘI",
            mrz: "IDVNM079090123456<<<<<<<<<<<<<<",
            isClear: true,
            isDocumentValid: true,
            confidence: 0.92,
            warnings: ["Mặt sau CCCD không chứa Họ tên mặt trước"],
            summaryVi: "CCCD mặt sau - Cấp ngày: 10/10/2021",
        };

        const parsed = identityVisionResponseSchema.parse(backSideSample);
        assert.equal(parsed.side, "back");
        assert.equal(parsed.issueDate, "10/10/2021");
        assert.equal(parsed.fullName, null);
    });

    it("throws when required schema fields are missing", () => {
        const { identityVisionResponseSchema } = require("../src/modules/ai/identity-vision.service");

        assert.throws(() => {
            identityVisionResponseSchema.parse({
                documentType: "cccd",
                // missing side, idNumber, fullName, etc.
            });
        });
    });
});

describe("identity vision endpoint contracts", () => {
    const app = createApp();

    const mockUser = {
        id: 101,
        _id: 101,
        userId: 101,
        email: "test@example.com",
        fullName: "Nguyễn Văn Test",
        username: "testuser",
        status: "active",
        roles: ["host"],
    };

    User.findById = async () => mockUser;
    User.findByPk = async () => mockUser;
    authService.assertUserCanAuthenticate = () => {};
    authService.toAuthenticatedUser = async () => ({
        id: "101",
        email: "test@example.com",
        roles: ["host"],
        status: "active",
    });

    const generateTestToken = (userId = "101", role = "host") => {
        return tokenService.signAuthToken(userId, role);
    };

    it("rejects unauthenticated requests with 401", async () => {
        const res = await request(app)
            .post("/api/ai/id-card-vision/extract")
            .send({});

        assert.equal(res.status, 401);
    });

    it("rejects requests with no image or parameters with 400", async () => {
        const token = generateTestToken();
        const res = await request(app)
            .post("/api/ai/id-card-vision/extract")
            .set("Authorization", `Bearer ${token}`)
            .send({});

        assert.equal(res.status, 400);
        assert.match(res.body.message, /Vui lòng đính kèm tệp ảnh/);
    });

    it("rejects non-image file uploads with 422", async () => {
        const token = generateTestToken();
        const res = await request(app)
            .post("/api/ai/id-card-vision/extract")
            .set("Authorization", `Bearer ${token}`)
            .attach("image", Buffer.from("not an image text file"), {
                filename: "document.txt",
                contentType: "text/plain",
            });

        assert.equal(res.status, 422);
        assert.equal(res.body.message, "Validation error");
        assert.match(res.body.errors[0].msg, /JPG, PNG hoặc WebP/);
    });

    it("verifies mock CCCD fixtures exist and are accepted by the upload endpoint", async () => {
        const token = generateTestToken();
        const frontFixturePath = path.resolve(__dirname, "fixtures/identity/mock_cccd_front.jpg");
        const backFixturePath = path.resolve(__dirname, "fixtures/identity/mock_cccd_back.jpg");

        assert.ok(fs.existsSync(frontFixturePath), "mock_cccd_front.jpg must exist in fixtures");
        assert.ok(fs.existsSync(backFixturePath), "mock_cccd_back.jpg must exist in fixtures");

        const res = await request(app)
            .post("/api/ai/id-card-vision/extract")
            .set("Authorization", `Bearer ${token}`)
            .attach("image", frontFixturePath);

        // Upload format is accepted (status 200 with live API key or 503 if API key unconfigured in CI)
        assert.ok(
            res.status === 200 || res.status === 503,
            `Expected 200 or 503, received ${res.status}: ${JSON.stringify(res.body)}`,
        );
    });

    it("verifies mock 9-digit CMND fixtures exist and are accepted by the upload endpoint", async () => {
        const token = generateTestToken();
        const cmndFrontPath = path.resolve(__dirname, "fixtures/identity/mock_cmnd_front.jpg");
        const cmndBackPath = path.resolve(__dirname, "fixtures/identity/mock_cmnd_back.jpg");

        assert.ok(fs.existsSync(cmndFrontPath), "mock_cmnd_front.jpg must exist in fixtures");
        assert.ok(fs.existsSync(cmndBackPath), "mock_cmnd_back.jpg must exist in fixtures");

        const res = await request(app)
            .post("/api/ai/id-card-vision/extract")
            .set("Authorization", `Bearer ${token}`)
            .attach("image", cmndFrontPath);

        assert.ok(
            res.status === 200 || res.status === 503,
            `Expected 200 or 503, received ${res.status}: ${JSON.stringify(res.body)}`,
        );
    });

    it("verifies mock Passport fixtures exist and are accepted by the upload endpoint", async () => {
        const token = generateTestToken();
        const passportPath = path.resolve(__dirname, "fixtures/identity/mock_passport.jpg");

        assert.ok(fs.existsSync(passportPath), "mock_passport.jpg must exist in fixtures");

        const res = await request(app)
            .post("/api/ai/id-card-vision/extract")
            .set("Authorization", `Bearer ${token}`)
            .attach("image", passportPath);

        assert.ok(
            res.status === 200 || res.status === 503,
            `Expected 200 or 503, received ${res.status}: ${JSON.stringify(res.body)}`,
        );
    });

    it("verifies mock Driver's License (GPLX) fixtures exist and are accepted by the upload endpoint", async () => {
        const token = generateTestToken();
        const gplxFrontPath = path.resolve(__dirname, "fixtures/identity/mock_gplx_front.jpg");
        const gplxBackPath = path.resolve(__dirname, "fixtures/identity/mock_gplx_back.jpg");

        assert.ok(fs.existsSync(gplxFrontPath), "mock_gplx_front.jpg must exist in fixtures");
        assert.ok(fs.existsSync(gplxBackPath), "mock_gplx_back.jpg must exist in fixtures");

        const res = await request(app)
            .post("/api/ai/id-card-vision/extract")
            .set("Authorization", `Bearer ${token}`)
            .attach("image", gplxFrontPath);

        assert.ok(
            res.status === 200 || res.status === 503,
            `Expected 200 or 503, received ${res.status}: ${JSON.stringify(res.body)}`,
        );
    });

    it("verifies mock invalid utility bill fixture exists and is handled by upload endpoint", async () => {
        const token = generateTestToken();
        const billPath = path.resolve(__dirname, "fixtures/identity/mock_invalid_utility_bill.jpg");

        assert.ok(fs.existsSync(billPath), "mock_invalid_utility_bill.jpg must exist in fixtures");

        const res = await request(app)
            .post("/api/ai/id-card-vision/extract")
            .set("Authorization", `Bearer ${token}`)
            .attach("image", billPath);

        assert.ok(
            res.status === 200 || res.status === 503,
            `Expected 200 or 503, received ${res.status}: ${JSON.stringify(res.body)}`,
        );
        if (res.status === 200) {
            assert.equal(res.body.data.documentType, "unknown");
            assert.equal(res.body.data.isDocumentValid, false);
        }
    });

    it("verifies mock elderly lifetime CCCD fixture exists and is handled by upload endpoint", async () => {
        const token = generateTestToken();
        const elderlyPath = path.resolve(__dirname, "fixtures/identity/mock_cccd_lifetime_elderly.jpg");

        assert.ok(fs.existsSync(elderlyPath), "mock_cccd_lifetime_elderly.jpg must exist in fixtures");

        const res = await request(app)
            .post("/api/ai/id-card-vision/extract")
            .set("Authorization", `Bearer ${token}`)
            .attach("image", elderlyPath);

        assert.ok(
            res.status === 200 || res.status === 503,
            `Expected 200 or 503, received ${res.status}: ${JSON.stringify(res.body)}`,
        );
        if (res.status === 200) {
            assert.equal(res.body.data.documentType, "cccd");
            assert.equal(res.body.data.expiryDate, "Không thời hạn");
        }
    });

    it("verifies mock expired CCCD fixture exists and is handled by upload endpoint", async () => {
        const token = generateTestToken();
        const expiredPath = path.resolve(__dirname, "fixtures/identity/mock_cccd_expired.jpg");

        assert.ok(fs.existsSync(expiredPath), "mock_cccd_expired.jpg must exist in fixtures");

        const res = await request(app)
            .post("/api/ai/id-card-vision/extract")
            .set("Authorization", `Bearer ${token}`)
            .attach("image", expiredPath);

        assert.ok(
            res.status === 200 || res.status === 503,
            `Expected 200 or 503, received ${res.status}: ${JSON.stringify(res.body)}`,
        );
        if (res.status === 200) {
            assert.equal(res.body.data.documentType, "cccd");
            assert.ok(res.body.data.warnings.some((w: string) => w.includes("hết hạn")));
        }
    });

    it("verifies mock held CCCD back & B/W photocopy fixtures exist for CI/CD", async () => {
        const backHeldPath = path.resolve(__dirname, "fixtures/identity/mock_cccd_back_held.jpg");
        const photocopyPath = path.resolve(__dirname, "fixtures/identity/mock_cccd_photocopy_bw.jpg");

        assert.ok(fs.existsSync(backHeldPath), "mock_cccd_back_held.jpg must exist in fixtures");
        assert.ok(fs.existsSync(photocopyPath), "mock_cccd_photocopy_bw.jpg must exist in fixtures");
    });

    it("verifies mock upside-down, glare, and front-held CCCD fixtures exist for CI/CD", async () => {
        const upsideDownPath = path.resolve(__dirname, "fixtures/identity/mock_cccd_upside_down.jpg");
        const glarePath = path.resolve(__dirname, "fixtures/identity/mock_cccd_glare.jpg");
        const frontHeldPath = path.resolve(__dirname, "fixtures/identity/mock_cccd_front_held.jpg");

        assert.ok(fs.existsSync(upsideDownPath), "mock_cccd_upside_down.jpg must exist in fixtures");
        assert.ok(fs.existsSync(glarePath), "mock_cccd_glare.jpg must exist in fixtures");
        assert.ok(fs.existsSync(frontHeldPath), "mock_cccd_front_held.jpg must exist in fixtures");
    });
});
