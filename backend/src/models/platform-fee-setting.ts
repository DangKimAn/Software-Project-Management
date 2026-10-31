import {
    CreationOptional,
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

export type PlatformFeeStatus = "active" | "scheduled" | "superseded" | "cancelled";

export class PlatformFeeSetting extends Model<
    InferAttributes<PlatformFeeSetting>,
    InferCreationAttributes<PlatformFeeSetting>
> {
    declare id: CreationOptional<number>;
    declare feePct: number;
    declare status: PlatformFeeStatus;
    declare effectiveAt: Date;
    declare createdByAdminId: number;
    declare cancelledByAdminId: number | null;
    declare reason: string | null;
    declare notificationSentAt: Date | null;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;
}

PlatformFeeSetting.init(
    {
        id: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
            field: "id",
        },
        feePct: {
            type: DataTypes.DECIMAL(5, 2),
            allowNull: false,
            field: "fee_pct",
            get() {
                const raw = this.getDataValue("feePct");
                return raw !== null && raw !== undefined ? Number(raw) : 0;
            },
        },
        status: {
            type: DataTypes.ENUM("active", "scheduled", "superseded", "cancelled"),
            allowNull: false,
            defaultValue: "scheduled",
            field: "status",
        },
        effectiveAt: {
            type: DataTypes.DATE,
            allowNull: false,
            field: "effective_at",
        },
        createdByAdminId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "created_by_admin_id",
        },
        cancelledByAdminId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "cancelled_by_admin_id",
        },
        reason: {
            type: DataTypes.STRING(500),
            allowNull: true,
            field: "reason",
        },
        notificationSentAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "notification_sent_at",
        },
        createdAt: {
            type: DataTypes.DATE,
            allowNull: false,
            defaultValue: DataTypes.NOW,
            field: "created_at",
        },
        updatedAt: {
            type: DataTypes.DATE,
            allowNull: false,
            defaultValue: DataTypes.NOW,
            field: "updated_at",
        },
    },
    {
        sequelize,
        tableName: "platform_fee_settings",
        timestamps: true,
        underscored: true,
    },
);

export default PlatformFeeSetting;
