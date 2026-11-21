const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { after, describe, it } = require("node:test");
const request = require("supertest");

process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret-for-security-remediation";
process.env.ACCESS_TOKEN_TTL_MINUTES = "15";

const hostKycPolicy = require("../dist/modules/host-kyc/host-kyc-policy");
const hostOnboardingService = require("../dist/modules/host-kyc/host-application.service");
const urlSecurity = require("../dist/common/url-security");
const aiGuardrails = require("../dist/modules/ai/ai-vision-guardrails");
const cryptoPii = require("../dist/common/crypto-pii");
const uploadsService = require("../dist/modules/uploads/uploads.service");
const HostApplication = require("../dist/models/host-application").default;
const HostIdentityDocument = require("../dist/models/host-identity-document").default;
const HostVerification = require("../dist/models/host-verification").default;
const User = require("../dist/models/user").default;
const sequelize = require("../dist/config/database").default;
const { createApp } = require("../dist/app");

after(async () => {
    try {
        await sequelize.close();
    } catch { }
});

describe("Security Remediation & Governance Audit", () => {
    it("enforces mandatory KYC documents before host application registration and admin approval", async () => {
        const emptyCheck = hostKycPolicy.validateHostKycDocumentCompleteness([]);
        assert.equal(emptyCheck.isComplete, false);

        assert.throws(
            () => hostKycPolicy.assertHostApplicationReadyForApproval(77, [], null),
            (err: { statusCode?: number }) => err.statusCode === 422,
        );

        assert.doesNotThrow(() =>
            hostKycPolicy.assertHostApplicationReadyForApproval(
                77,
                [
                    { side: "front", storageKey: "host-identity-docs/77/front.jpg", status: "uploaded" },
                    { side: "back", storageKey: "host-identity-docs/77/back.jpg", status: "uploaded" },
                ],
                null,
            ),
        );

        const origUserFindById = User.findById;
        const origAppFindAll = HostApplication.findAll;
        const origAppFindOne = HostApplication.findOne;
        const origDocFindAll = HostIdentityDocument.findAll;
        const origVerFindOne = HostVerification.findOne;

        try {
            User.findById = async () => ({
                id: 501,
                _id: 501,
                role: "guest",
                status: "active",
            });
            // CONFLICT-RESOLVED: Bổ sung mock `HostApplication.findOne` cho luồng hợp nhất `host-kyc` không cần kết nối MySQL thật.
            HostApplication.findAll = async () => [];
            HostApplication.findOne = async () => null;
            HostIdentityDocument.findAll = async () => [];
            HostVerification.findOne = async () => null;

            await assert.rejects(
                () =>
                    hostOnboardingService.registerHostApplication("501", {
                        phone: "0901234567",
                        propertyName: "Bypass Attempt Villa",
                        address: "12 Thuy Van, Vung Tau",
                        note: null,
                    }),
                (err: { statusCode?: number }) => err.statusCode === 422,
            );
        } finally {
            User.findById = origUserFindById;
            HostApplication.findAll = origAppFindAll;
            HostApplication.findOne = origAppFindOne;
            HostIdentityDocument.findAll = origDocFindAll;
            HostVerification.findOne = origVerFindOne;
        }
    });

    it("blocks IPv4-mapped IPv6, NAT64, cloud metadata, and DNS-rebinding SSRF payloads", async () => {
        const blockedUrls = [
            "https://[::ffff:127.0.0.1]/",
            "https://[::ffff:169.254.169.254]/latest/meta-data/",
            "https://[::ffff:7f00:1]/",
            "https://[0:0:0:0:0:ffff:a9fe:a9fe]/",
            "https://[64:ff9b::127.0.0.1]/",
            "http://169.254.169.254/latest/meta-data/",
            "https://user:pass@example.com/image.jpg",
        ];

        for (const candidate of blockedUrls) {
            assert.equal(
                urlSecurity.isSafeExternalHttpUrl(candidate),
                false,
                `Expected SSRF guard to reject ${candidate}`,
            );
        }

        assert.equal(urlSecurity.isSafeExternalHttpUrl("https://images.example.com/villa.jpg"), true);

        await assert.rejects(
            () =>
                urlSecurity.assertSafeExternalUrlResolved(
                    "https://rebind.attacker.example/pic.jpg",
                    "imageUrl",
                    {
                        dnsLookupFn: async () => [{ address: "::ffff:169.254.169.254", family: 6 }],
                    },
                ),
            (err: { statusCode?: number }) => err.statusCode === 422,
        );
    });

    it("enforces AI Vision prompt-injection guardrails, output sanitization, base64 magic-bytes, and batch limits", () => {
        assert.ok(aiGuardrails.VISUAL_PROMPT_INJECTION_SYSTEM_GUARDRAIL.length > 80);

        const dirty = aiGuardrails.sanitizeLlmOutputText(
            '<script>fetch("https://evil.tld")</script><b>Phòng ngủ view biển</b>\u0007',
        );
        assert.equal(dirty, "Phòng ngủ view biển");

        assert.throws(
            () =>
                aiGuardrails.decodeAndValidateVisionBase64Image(
                    `data:image/png;base64,${Buffer.from("not-an-image").toString("base64")}`,
                ),
            (err: { statusCode?: number }) => err.statusCode === 422,
        );

        const validJpegBytes = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46]);
        const decoded = aiGuardrails.decodeAndValidateVisionBase64Image(
            `data:image/jpeg;base64,${validJpegBytes.toString("base64")}`,
        );
        assert.equal(decoded.mimeType, "image/jpeg");
        assert.ok(decoded.dataUri.startsWith("data:image/jpeg;base64,"));

        assert.equal(aiGuardrails.resolveSafeVisionBatchLimit(30), 10);
        assert.equal(aiGuardrails.resolveSafeVisionBatchLimit(undefined), 5);
    });

    it("protects public R2 folders, requires upload size, encrypts/masks bank PII, and forbids query streamToken", async () => {
        assert.equal(uploadsService.allowedPublicUploadFolders.includes("verifications"), false);

        await assert.rejects(
            () =>
                uploadsService.createPresignedUploadUrl(
                    { userId: "101", isAdmin: false, isHost: true },
                    {
                        folder: "avatars",
                        filename: "avatar.jpg",
                        contentType: "image/jpeg",
                    },
                ),
            (err: { statusCode?: number }) => err.statusCode === 422,
        );

        const encrypted = cryptoPii.encryptBankAccountNumber("0123456789012");
        assert.ok(encrypted.startsWith("v1:"));
        assert.equal(cryptoPii.decryptBankAccountNumber(encrypted), "0123456789012");
        assert.throws(() => cryptoPii.decryptBankAccountNumber(`${encrypted}tamper`));
        assert.equal(cryptoPii.maskBankAccountNumber("0123456789012"), "*********9012");

        const app = createApp();
        const queryTokenRes = await request(app).get(
            "/api/admin/host-applications/documents/1/view?streamToken=secret-in-url",
        );
        assert.equal(queryTokenRes.status, 401);
    });

    it("includes 100% of migrations, 100% of tests, strict CI migration exit codes, Dockerfile cache dir, and JSDoc", () => {
        const backendRoot = path.resolve(__dirname, "..");
        const repoRoot = path.resolve(backendRoot, "..");
        const pkg = JSON.parse(fs.readFileSync(path.join(backendRoot, "package.json"), "utf8"));

        const migrationFiles = fs
            .readdirSync(path.join(backendRoot, "database/migrations"))
            .filter((name: string) => name.endsWith(".js"));
        assert.ok(migrationFiles.length >= 22);
        for (const migrationFile of migrationFiles) {
            assert.ok(
                pkg.scripts["db:migrate:safe"].includes(`database/migrations/${migrationFile}`),
                `db:migrate:safe is missing ${migrationFile}`,
            );
        }

        assert.equal(fs.existsSync(path.join(backendRoot, "src/tests")), false);

        const testFiles = fs
            .readdirSync(path.join(backendRoot, "tests"))
            .filter((name: string) => name.endsWith(".test.ts"));
        for (const testFile of testFiles) {
            assert.ok(
                pkg.scripts.test.includes(`tests/${testFile}`),
                `npm test script is missing tests/${testFile}`,
            );
        }

        for (const wfName of ["backend-ci.yml", "ci-test.yml"]) {
            const wfContent = fs.readFileSync(path.join(repoRoot, ".github/workflows", wfName), "utf8");
            assert.equal(
                /db:migrate[^\r\n]*\|\|\s*true/.test(wfContent),
                false,
                `${wfName} must not mask db:migrate errors with || true`,
            );
        }

        const dockerfile = fs.readFileSync(path.join(backendRoot, "Dockerfile"), "utf8");
        assert.match(dockerfile, /mkdir -p \/app\/data\/cache/);
        assert.match(dockerfile, /chown -R appuser:appgroup \/app/);

        const allBackendTsFiles: string[] = [];
        const walkTs = (dirPath: string) => {
            for (const entry of fs.readdirSync(dirPath, { withFileTypes: true })) {
                const fullPath = path.join(dirPath, entry.name);
                if (entry.isDirectory()) {
                    walkTs(fullPath);
                } else if (entry.name.endsWith(".ts")) {
                    allBackendTsFiles.push(fullPath);
                }
            }
        };
        walkTs(path.join(backendRoot, "src"));
        // CONFLICT-RESOLVED: Điều chỉnh ngưỡng số lượng tệp `.ts` tối thiểu sau khi hợp nhất các module KYC, ngân hàng và tiện ích trùng vai trò.
        assert.ok(allBackendTsFiles.length >= 240);

        for (const fullTsPath of allBackendTsFiles) {
            const relPath = path.relative(backendRoot, fullTsPath);
            const content = fs.readFileSync(fullTsPath, "utf8");
            assert.ok(content.includes("/**"), `${relPath} must contain JSDoc header comments`);
        }
    });
});

export { };
