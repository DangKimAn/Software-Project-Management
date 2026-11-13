const assert = require("node:assert/strict");
const { before, describe, it } = require("node:test");
const request = require("supertest");
import type { AuthenticatedTestUser } from "./helpers/types";

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";
process.env.REFRESH_TOKEN_COOKIE_NAME = "refreshToken";
process.env.REFRESH_TOKEN_COOKIE_PATH = "/api/auth";

const authService = require("../dist/modules/auth/auth.service");
const User = require("../dist/models/user").default;
const hostApplicationService = require("../dist/modules/host-applications/host-application.service");

type TestUserRecord = {
    _id: number;
    id: number;
    email: string;
    phone: string;
    username: string;
    fullName: string;
    status: string;
    roles: string[];
    isHostVerified: boolean;
    hostApplicationStatus: string | null;
};

const users = new Map<string, TestUserRecord>([
    [
        "101",
        {
            _id: 101,
            id: 101,
            email: "applicant@example.com",
            phone: "0901234567",
            username: "applicant",
            fullName: "Applicant User",
            status: "active",
            roles: ["guest"],
            isHostVerified: false,
            hostApplicationStatus: null,
        },
    ],
]);

const userToAuthUser = (user: TestUserRecord): AuthenticatedTestUser => ({
    id: String(user._id),
    email: user.email,
    phone: user.phone,
    name: user.fullName,
    username: user.username,
    status: user.status,
    roles: user.roles,
});

before(() => {
    authService.verifyAuthToken = (token: string) => {
        if (token === "applicant-token") {
            return { userId: "101", role: "guest" };
        }
        throw new Error("Unauthorized");
    };
    authService.toAuthenticatedUser = async (user: TestUserRecord) => userToAuthUser(user);
    authService.assertUserCanAuthenticate = () => undefined;
    User.findById = async (id: string | number) => users.get(String(id)) ?? null;
});

const app = require("../dist/app").default;
const applicantAuth = { Authorization: "Bearer applicant-token" };

describe("Host Application Cancellation API", () => {
    it("returns 404 when user has no application to cancel", async () => {
        // Mock service cancelHostApplication throwing 404
        const originalCancel = hostApplicationService.cancelHostApplication;
        hostApplicationService.cancelHostApplication = async () => {
            const { ApiError } = require("../dist/common/api-error");
            throw new ApiError(404, "Không tìm thấy hồ sơ đăng ký Host để hủy");
        };

        const res = await request(app)
            .post("/api/host/applications/cancel")
            .set(applicantAuth);

        assert.equal(res.status, 404);
        assert.ok(res.body.message.includes("Không tìm thấy"));
        hostApplicationService.cancelHostApplication = originalCancel;
    });

    it("returns 400 when user attempts to cancel an already approved application", async () => {
        const originalCancel = hostApplicationService.cancelHostApplication;
        hostApplicationService.cancelHostApplication = async () => {
            const { ApiError } = require("../dist/common/api-error");
            throw new ApiError(400, "Không thể hủy hồ sơ đã được phê duyệt");
        };

        const res = await request(app)
            .post("/api/host/applications/cancel")
            .set(applicantAuth);

        assert.equal(res.status, 400);
        assert.ok(res.body.message.includes("đã được phê duyệt"));
        hostApplicationService.cancelHostApplication = originalCancel;
    });

    it("successfully cancels a pending application via POST /cancel", async () => {
        let cancelCalled = false;
        const originalCancel = hostApplicationService.cancelHostApplication;
        hostApplicationService.cancelHostApplication = async (user: AuthenticatedTestUser) => {
            cancelCalled = true;
            assert.equal(user.id, "101");
            return {
                message: "Đã hủy đơn đăng ký Host thành công.",
                status: null,
            };
        };

        const res = await request(app)
            .post("/api/host/applications/cancel")
            .set(applicantAuth);

        assert.equal(res.status, 200);
        assert.equal(cancelCalled, true);
        assert.equal(res.body.data.status, null);
        assert.ok(res.body.message.includes("thành công"));
        hostApplicationService.cancelHostApplication = originalCancel;
    });

    it("successfully cancels a pending application via DELETE /me", async () => {
        let cancelCalled = false;
        const originalCancel = hostApplicationService.cancelHostApplication;
        hostApplicationService.cancelHostApplication = async (user: AuthenticatedTestUser) => {
            cancelCalled = true;
            assert.equal(user.id, "101");
            return {
                message: "Đã hủy đơn đăng ký Host thành công.",
                status: null,
            };
        };

        const res = await request(app)
            .delete("/api/host/applications/me")
            .set(applicantAuth);

        assert.equal(res.status, 200);
        assert.equal(cancelCalled, true);
        assert.equal(res.body.data.status, null);
        hostApplicationService.cancelHostApplication = originalCancel;
    });
});
