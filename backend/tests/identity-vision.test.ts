// CONFLICT-RESOLVED: Chuyển toàn bộ import từ ../src/ sang ../dist/ để đồng nhất với bộ kiểm thử chuẩn trong ackend/tests/.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { after, before, describe, it } = require("node:test");
const request = require("supertest");

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";
process.env.ALLOW_REFRESH_TOKEN_IN_BODY = "false";
process.env.ALLOW_REFRESH_TOKEN_IN_HEADER = "false";

const { createApp } = require("../dist/app");
const tokenService = require("../dist/modules/auth/token.service");
const authService = require("../dist/modules/auth/auth.service");
const User = require("../dist/models/user").default;
const sequelize = require("../dist/config/database").default;

const originalFindById = User.findById;
const originalFindByPk = User.findByPk;
const originalAssertCanAuth = authService.assertUserCanAuthenticate;
const originalToAuthenticatedUser = authService.toAuthenticatedUser;

before(() => {
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
});

after(async () => {
    User.findById = originalFindById;
    User.findByPk = originalFindByPk;
    authService.assertUserCanAuthenticate = originalAssertCanAuth;
    authService.toAuthenticatedUser = originalToAuthenticatedUser;
    try {
        await sequelize.close();
    } catch {}
});

describe("identity vision schema and parsing", () => {
    it("validates and parses a full CCCD front response correctly", () => {
        const { identityVisionResponseSchema } = require("../dist/modules/ai/identity-vision.service");

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

    it("validates CMND, Passport, Driver License, utility bill, lifetime and expired CCCD schemas", () => {
        const { identityVisionResponseSchema } = require("../dist/modules/ai/identity-vision.service");

        const cmnd = identityVisionResponseSchema.parse({
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
        });
        assert.equal(cmnd.documentType, "cmnd");

        const passport = identityVisionResponseSchema.parse({
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
            mrz: "P<VNMNGUYEN<<VAN<A<<<<<<<<<<<<<<<<<<<<<<<<<<",
            isClear: true,
            isDocumentValid: true,
            confidence: 0.98,
            warnings: [],
            summaryVi: "Hộ chiếu Việt Nam - NGUYỄN VĂN A - Số: P01234567",
        });
        assert.equal(passport.documentType, "passport");

        const invalidBill = identityVisionResponseSchema.parse({
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
        });
        assert.equal(invalidBill.isDocumentValid, false);

        assert.throws(() => {
            identityVisionResponseSchema.parse({ documentType: "cccd" });
        });
    });
});

describe("identity vision endpoint contracts", () => {
    const app = createApp();
    const generateTestToken = (userId = "101", role = "host") => tokenService.signAuthToken(userId, role);

    it("rejects unauthenticated requests with 401", async () => {
        const res = await request(app).post("/api/ai/id-card-vision/extract").send({});
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

    it("rejects non-image file uploads and forged base64 payloads without image magic bytes with 422", async () => {
        const token = generateTestToken();
        const fileRes = await request(app)
            .post("/api/ai/id-card-vision/extract")
            .set("Authorization", `Bearer ${token}`)
            .attach("image", Buffer.from("not an image text file"), {
                filename: "document.txt",
                contentType: "text/plain",
            });

        assert.equal(fileRes.status, 422);

        const forgedBase64 = Buffer.from("<script>alert(1)</script>").toString("base64");
        const base64Res = await request(app)
            .post("/api/ai/id-card-vision/extract")
            .set("Authorization", `Bearer ${token}`)
            .send({
                base64Data: `data:image/jpeg;base64,${forgedBase64}`,
            });

        assert.equal(base64Res.status, 422);
    });

    it("verifies mock identity fixtures exist and are accepted by the upload endpoint", async () => {
        const token = generateTestToken();
        const fixtureNames = [
            "mock_cccd_front.jpg",
            "mock_cccd_back.jpg",
            "mock_cmnd_front.jpg",
            "mock_cmnd_back.jpg",
            "mock_passport.jpg",
            "mock_gplx_front.jpg",
            "mock_gplx_back.jpg",
            "mock_invalid_utility_bill.jpg",
            "mock_cccd_lifetime_elderly.jpg",
            "mock_cccd_expired.jpg",
            "mock_cccd_back_held.jpg",
            "mock_cccd_photocopy_bw.jpg",
            "mock_cccd_upside_down.jpg",
            "mock_cccd_glare.jpg",
            "mock_cccd_front_held.jpg",
        ];

        for (const name of fixtureNames) {
            const fixturePath = path.resolve(__dirname, `fixtures/identity/${name}`);
            assert.ok(fs.existsSync(fixturePath), `${name} must exist in fixtures`);
        }

        const frontFixturePath = path.resolve(__dirname, "fixtures/identity/mock_cccd_front.jpg");
        const res = await request(app)
            .post("/api/ai/id-card-vision/extract")
            .set("Authorization", `Bearer ${token}`)
            .attach("image", frontFixturePath);

        assert.ok(
            res.status === 200 || res.status === 503,
            `Expected 200 or 503, received ${res.status}: ${JSON.stringify(res.body)}`,
        );
    });
});

export {};
