export {};

process.env.TZ = "UTC";
process.env.NODE_ENV = "test";
process.env.JWT_SECRET_KEY = "test-secret-at-least-32-chars-long!!";
process.env.JWT_SECRET = "test-secret-at-least-32-chars-long!!";
process.env.DISBURSEMENT_MODE = "mock";

const assert = require("node:assert/strict");
const { describe, it } = require("node:test");

const { executeDisbursement } = require("../dist/modules/disbursement/disbursement.service");
const { disburseHostPayout, requestHostPayout, cancelHostPayout } = require("../dist/modules/payouts/payouts.service");
const { approveAndDisburseRefund, rejectRefund } = require("../dist/modules/refunds/refunds.service");
const HostPayoutBatch = require("../dist/models/host-payout-batch").default;
const HostPayoutBookingItem = require("../dist/models/host-payout-booking-item").default;
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
        const origBookingItemFindAll = HostPayoutBookingItem.findAll;
        const origTransaction = sequelize.transaction;

        HostPayoutBatch.findByPk = async (id: number) => (id === 101 ? mockPayout : null);
        PayoutAccount.findOne = async () => mockAccount;
        HostPayoutBookingItem.findAll = async () => [];
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
            HostPayoutBookingItem.findAll = origBookingItemFindAll;
            sequelize.transaction = origTransaction;
        }
    });

    it("disburseHostPayout fails safe if booking items amount does not match payout amount", async () => {
        const mockPayout = {
            payoutId: 102,
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

        const mockItems = [
            { payoutId: 102, bookingDetailId: 888, hostAmount: 3000000 },
        ];

        const origFindByPk = HostPayoutBatch.findByPk;
        const origFindOne = PayoutAccount.findOne;
        const origBookingItemFindAll = HostPayoutBookingItem.findAll;
        const origTransaction = sequelize.transaction;

        HostPayoutBatch.findByPk = async (id: number) => (id === 102 ? mockPayout : null);
        PayoutAccount.findOne = async () => mockAccount;
        HostPayoutBookingItem.findAll = async () => mockItems;
        sequelize.transaction = async (cb: any) => cb({});

        try {
            await assert.rejects(
                async () => {
                    await disburseHostPayout({
                        payoutId: 102,
                        actorUserId: 2,
                    });
                },
                (err: any) => {
                    assert.equal(err.statusCode, 422);
                    assert.ok(err.message.includes("không khớp"));
                    return true;
                },
            );
        } finally {
            HostPayoutBatch.findByPk = origFindByPk;
            PayoutAccount.findOne = origFindOne;
            HostPayoutBookingItem.findAll = origBookingItemFindAll;
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

    it("cancelHostPayout enforces ownership and status rules before cancelling", async () => {
        const mockHost = {
            id: 202,
            email: "host@example.com",
            roles: ["host"],
        };

        const origFindByPk = HostPayoutBatch.findByPk;
        const origItemFindAll = HostPayoutBookingItem.findAll;
        const origItemDestroy = HostPayoutBookingItem.destroy;
        const origTransaction = sequelize.transaction;
        sequelize.transaction = async (cb: any) => cb({ LOCK: { UPDATE: "UPDATE" } });

        try {
            // 1. Not found -> 404
            HostPayoutBatch.findByPk = async () => null;
            await assert.rejects(
                async () => cancelHostPayout(mockHost, 999),
                { message: /Không tìm thấy yêu cầu rút tiền/ },
            );

            // 2. Different host -> 403
            HostPayoutBatch.findByPk = async () => ({
                payoutId: 999,
                hostId: 9999, // other host
                status: "pending",
            });
            await assert.rejects(
                async () => cancelHostPayout(mockHost, 999),
                { message: /Bạn không có quyền thao tác trên yêu cầu này/ },
            );

            // 3. Status not pending -> 400
            HostPayoutBatch.findByPk = async () => ({
                payoutId: 999,
                hostId: 202,
                status: "paid",
            });
            await assert.rejects(
                async () => cancelHostPayout(mockHost, 999),
                { message: /Chỉ có thể hủy yêu cầu rút tiền đang ở trạng thái Chờ duyệt/ },
            );

            // 4. Success -> status updated to cancelled and linked payout_items released
            let saved = false;
            let destroyedWhere: any = null;
            const mockRecord = {
                payoutId: 999,
                hostId: 202,
                status: "pending",
                amount: 1000000,
                currency: "VND",
                notes: "Can rut gap",
                save: async () => {
                    saved = true;
                },
            };
            HostPayoutBatch.findByPk = async () => mockRecord;
            HostPayoutBookingItem.findAll = async () => [
                { payoutId: 999, bookingOrderId: 17, bookingDetailId: 17 },
            ];
            HostPayoutBookingItem.destroy = async (opts: any) => {
                destroyedWhere = opts?.where ?? null;
                return 1;
            };

            const res = await cancelHostPayout(mockHost, 999);
            assert.equal(res.payoutId, 999);
            assert.equal(res.status, "cancelled");
            assert.equal(mockRecord.status, "cancelled");
            assert.ok(mockRecord.notes.includes("Đã hủy bởi chủ nhà"));
            assert.equal(saved, true);
            assert.deepEqual(destroyedWhere, { payoutId: 999 });
            assert.deepEqual(res.releasedBookingIds, [17]);
        } finally {
            HostPayoutBatch.findByPk = origFindByPk;
            HostPayoutBookingItem.findAll = origItemFindAll;
            HostPayoutBookingItem.destroy = origItemDestroy;
            sequelize.transaction = origTransaction;
        }
    });

    it("CHROME-05: pending payout -> cancelHostPayout -> re-requestHostPayout releases booking_detail_id unique lock without 409 Conflict", async () => {
        const { UniqueConstraintError } = require("sequelize");
        const mockHost = {
            id: 202,
            email: "host.thanh@minhthanhvilla.com",
            roles: ["host"],
        };

        const origFindOne = PayoutAccount.findOne;
        const origBatchCreate = HostPayoutBatch.create;
        const origBatchFindByPk = HostPayoutBatch.findByPk;
        const origItemBulkCreate = HostPayoutBookingItem.bulkCreate;
        const origItemFindAll = HostPayoutBookingItem.findAll;
        const origItemDestroy = HostPayoutBookingItem.destroy;
        const origQuery = sequelize.query;
        const origTransaction = sequelize.transaction;

        let nextPayoutId = 30007;
        const batches = new Map<number, any>();
        // Mô phỏng bảng host_payout_booking_item có UNIQUE(booking_detail_id)
        const lockedItemsByBookingDetail = new Map<number, { payoutId: number; bookingOrderId: number; bookingDetailId: number }>();

        PayoutAccount.findOne = async () => ({
            payoutAccountId: 303,
            userId: 202,
            bankName: "MBBank",
            accountName: "NGUYEN MINH THANH",
            accountNumber: "****5432",
            accountNumberLast4: "5432",
        });

        sequelize.transaction = async (cb: any) => cb({ LOCK: { UPDATE: "UPDATE" } });

        sequelize.query = async (sql: string) => {
            const text = String(sql);
            if (text.includes("DELETE FROM host_payout_booking_item")) {
                for (const [detailId, item] of Array.from(lockedItemsByBookingDetail.entries())) {
                    const parent = batches.get(item.payoutId);
                    if (parent && ["cancelled", "rejected", "failed"].includes(parent.status)) {
                        lockedItemsByBookingDetail.delete(detailId);
                    }
                }
                return [{ affectedRows: 1 }];
            }
            if (text.includes("FROM bookings b")) {
                const existingLock = lockedItemsByBookingDetail.get(17);
                const parentBatch = existingLock ? batches.get(existingLock.payoutId) : null;
                const isActivelyLocked =
                    parentBatch && ["pending", "approved", "processing", "paid"].includes(parentBatch.status);
                if (isActivelyLocked) {
                    return [];
                }
                return [
                    {
                        bookingId: 17,
                        bookingDetailId: 17,
                        listingId: 101,
                        hostId: 202,
                        bookingStatus: "completed",
                        paymentStatus: "paid",
                        listingTitle: "The Palm Luxury Sea View Villa",
                        totalAmount: "8300000.00",
                        currency: "VND",
                        serviceFeeAmount: "800000.00",
                        hostAmount: "7500000.00",
                    },
                ];
            }
            return [];
        };

        HostPayoutBatch.create = async (data: any) => {
            const id = nextPayoutId++;
            const record = {
                payoutId: id,
                ...data,
                createdAt: new Date(),
                save: async () => record,
            };
            batches.set(id, record);
            return record;
        };

        HostPayoutBatch.findByPk = async (id: number) => batches.get(Number(id)) ?? null;

        HostPayoutBookingItem.bulkCreate = async (rows: any[]) => {
            for (const row of rows) {
                if (lockedItemsByBookingDetail.has(Number(row.bookingDetailId))) {
                    throw new UniqueConstraintError({ message: "Duplicate entry for uniq_host_payout_booking_item_booking_detail" });
                }
                lockedItemsByBookingDetail.set(Number(row.bookingDetailId), {
                    payoutId: Number(row.payoutId),
                    bookingOrderId: Number(row.bookingOrderId),
                    bookingDetailId: Number(row.bookingDetailId),
                });
            }
            return rows;
        };

        HostPayoutBookingItem.findAll = async (opts: any) => {
            const targetPayoutId = Number(opts?.where?.payoutId);
            return Array.from(lockedItemsByBookingDetail.values()).filter(
                (item) => item.payoutId === targetPayoutId,
            );
        };

        HostPayoutBookingItem.destroy = async (opts: any) => {
            const targetPayoutId = Number(opts?.where?.payoutId);
            let removed = 0;
            for (const [detailId, item] of Array.from(lockedItemsByBookingDetail.entries())) {
                if (item.payoutId === targetPayoutId) {
                    lockedItemsByBookingDetail.delete(detailId);
                    removed++;
                }
            }
            return removed;
        };

        try {
            // Bước 1: Tạo lệnh rút tiền #30007 (pending) -> khóa booking #17
            const firstRequest = await requestHostPayout(mockHost, {
                amount: 1000000,
                notes: "Lan rut thu 1",
            });
            assert.equal(firstRequest.payoutId, 30007);
            assert.equal(firstRequest.status, "pending");
            assert.equal(lockedItemsByBookingDetail.has(17), true);

            // Bước 2: Hủy lệnh rút tiền #30007 -> giải phóng dòng khóa trong host_payout_booking_item
            const cancelled = await cancelHostPayout(mockHost, 30007);
            assert.equal(cancelled.payoutId, 30007);
            assert.equal(cancelled.status, "cancelled");
            assert.deepEqual(cancelled.releasedBookingIds, [17]);
            assert.equal(lockedItemsByBookingDetail.has(17), false);

            // Bước 3: Tạo lại lệnh rút tiền mới #30008 trên cùng booking #17 -> thành công 201, không gặp 409 Conflict
            const secondRequest = await requestHostPayout(mockHost, {
                amount: 1500000,
                notes: "Lan rut thu 2 sau khi huy",
            });
            assert.equal(secondRequest.payoutId, 30008);
            assert.equal(secondRequest.status, "pending");
            assert.equal(lockedItemsByBookingDetail.get(17)?.payoutId, 30008);
        } finally {
            PayoutAccount.findOne = origFindOne;
            HostPayoutBatch.create = origBatchCreate;
            HostPayoutBatch.findByPk = origBatchFindByPk;
            HostPayoutBookingItem.bulkCreate = origItemBulkCreate;
            HostPayoutBookingItem.findAll = origItemFindAll;
            HostPayoutBookingItem.destroy = origItemDestroy;
            sequelize.query = origQuery;
            sequelize.transaction = origTransaction;
        }
    });
});
