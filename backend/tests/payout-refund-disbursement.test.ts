export {};

process.env.TZ = "UTC";
process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret-at-least-32-chars-long!!";
process.env.JWT_SECRET = "test-secret-at-least-32-chars-long!!";
process.env.DISBURSEMENT_MODE = "mock";

const assert = require("node:assert/strict");
const { describe, it } = require("node:test");

const { executeDisbursement } = require("../dist/modules/disbursement/disbursement.service");
const { disburseHostPayout, requestHostPayout } = require("../dist/modules/payouts/payouts.service");
const { approveAndDisburseRefund, rejectRefund } = require("../dist/modules/refunds/refunds.service");
const HostPayoutBatch = require("../dist/models/host-payout-batch").default;
const PayoutAccount = require("../dist/models/payout-account").default;
const Refund = require("../dist/models/refund").default;
const sequelize = require("../dist/config/database").default || require("../dist/config/database").sequelize;

describe("Disbursement & Refund Mock Engine Unit Tests", () => {
    it("executeDisbursement generates FT_NAPAS reference in mock mode", async () => {
        const result = await executeDisbursement({
            targetType: "host_payout",
            targetId: 999,
            bankCode: "MBBANK",
            accountNumber: "0987654321",
            accountName: "NGUYEN VAN A",
            amount: 2500000,
            currency: "VND",
            description: "Chi tra thu nghiem",
        });

        assert.equal(result.success, true);
        assert.equal(result.provider, "mock");
        assert.match(result.transferReference, /^FT_NAPAS_\d+_\d+$/);
        assert.ok(result.transferredAt instanceof Date);
    });

    it("disburseHostPayout successfully transitions batch to paid with transferReference", async () => {
        // Mock Payout Batch
        const mockPayout = {
            payoutId: 101,
            hostId: 202,
            payoutAccountId: 303,
            amount: 5000000,
            currency: "VND",
            status: "approved",
            approvedByUserId: 1,
            approvedAt: new Date(),
            paidAt: null,
            paidByUserId: null,
            transferReference: null,
            save: async () => {},
        };

        const mockAccount = {
            payoutAccountId: 303,
            userId: 202,
            bankName: "Techcombank",
            bankCode: "TCB",
            accountNumber: "1903456789",
            accountName: "TRAN VAN B",
        };

        const origFindByPk = HostPayoutBatch.findByPk;
        const origFindOne = PayoutAccount.findOne;
        const origTransaction = sequelize.transaction;

        HostPayoutBatch.findByPk = async (id: number) => (id === 101 ? mockPayout : null);
        PayoutAccount.findOne = async () => mockAccount;
        sequelize.transaction = async (cb: any) => cb({});

        try {
            const result = await disburseHostPayout({
                payoutId: 101,
                actorUserId: 2,
            });

            assert.equal(result.payout.status, "paid");
            assert.match(result.payout.transferReference, /^FT_NAPAS_/);
            assert.equal(result.payout.paidByUserId, 2);
            assert.ok(result.payout.paidAt);
            assert.equal(result.disbursement.success, true);
        } finally {
            HostPayoutBatch.findByPk = origFindByPk;
            PayoutAccount.findOne = origFindOne;
            sequelize.transaction = origTransaction;
        }
    });

    it("approveAndDisburseRefund requires bank details and completes refund", async () => {
        const mockRefund = {
            refundId: 555,
            paymentId: 666,
            bookingId: 777,
            amount: 1200000,
            currency: "VND",
            status: "pending",
            bankName: "Vietcombank",
            accountNumber: "001100223344",
            accountName: "LE THI C",
            providerRef: null,
            processedByUserId: null,
            processedAt: null,
            save: async () => {},
        };

        const origFindByPk = Refund.findByPk;
        const origTransaction = sequelize.transaction;

        Refund.findByPk = async (id: number) => (id === 555 ? mockRefund : null);
        sequelize.transaction = async (cb: any) => cb({});

        try {
            const result = await approveAndDisburseRefund({
                refundId: 555,
                actorUserId: 1,
            });

            assert.equal(result.refund.status, "succeeded");
            assert.match(result.refund.providerRef, /^FT_NAPAS_/);
            assert.equal(result.refund.processedByUserId, 1);
            assert.ok(result.refund.processedAt);
            assert.equal(result.disbursement.success, true);
        } finally {
            Refund.findByPk = origFindByPk;
            sequelize.transaction = origTransaction;
        }
    });

    it("rejectRefund transitions refund to cancelled with admin reason", async () => {
        const mockRefund = {
            refundId: 556,
            paymentId: 666,
            bookingId: 778,
            amount: 500000,
            currency: "VND",
            status: "pending",
            reason: "Khách hủy phòng cận giờ",
            processedByUserId: null,
            processedAt: null,
            save: async () => {},
        };

        const origFindByPk = Refund.findByPk;
        const origTransaction = sequelize.transaction;

        Refund.findByPk = async (id: number) => (id === 556 ? mockRefund : null);
        sequelize.transaction = async (cb: any) => cb({});

        try {
            const result = await rejectRefund({
                refundId: 556,
                actorUserId: 1,
                reason: "Không đủ điều kiện hoàn tiền theo chính sách Strict",
            });

            assert.equal(result.status, "cancelled");
            assert.equal(result.processedByUserId, 1);
            assert.match(result.reason, /Không đủ điều kiện/);
        } finally {
            Refund.findByPk = origFindByPk;
            sequelize.transaction = origTransaction;
        }
    });

    it("requestHostPayout validates minimum amount and creates pending batch", async () => {
        const mockHost = { id: 202, roles: ["host"] };

        // Test minimum amount validation (< 200,000 VND)
        await assert.rejects(
            async () => {
                await requestHostPayout(mockHost, { amount: 150000 });
            },
            {
                message: /Số tiền rút tối thiểu là 200.000 VNĐ/,
            },
        );

        // Test successful payout creation with mocked account & batch
        const origFindOne = PayoutAccount.findOne;
        const origQuery = sequelize.query;
        const origBatchCreate = HostPayoutBatch.create;
        const origTransaction = sequelize.transaction;

        PayoutAccount.findOne = async () => ({
            payoutAccountId: 303,
            userId: 202,
            bankName: "MBBank",
            accountName: "DANG KIM AN",
            accountNumber: "0929399893",
        });
        sequelize.query = async () => [];
        HostPayoutBatch.create = async (data: any) => ({
            payoutId: 888,
            ...data,
            createdAt: new Date(),
        });
        sequelize.transaction = async (cb: any) => cb({});

        try {
            const result = await requestHostPayout(mockHost, {
                amount: 1000000,
                notes: "Host rut tien test",
            });

            assert.equal(result.payoutId, 888);
            assert.equal(result.amount, 1000000);
            assert.equal(result.status, "pending");
            assert.equal(result.payoutAccount.bankName, "MBBank");
        } finally {
            PayoutAccount.findOne = origFindOne;
            sequelize.query = origQuery;
            HostPayoutBatch.create = origBatchCreate;
            sequelize.transaction = origTransaction;
        }
    });
});
