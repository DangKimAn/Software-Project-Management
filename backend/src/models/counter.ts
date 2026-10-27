import {
    DataTypes,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";

class CounterModel extends Model<InferAttributes<CounterModel>, InferCreationAttributes<CounterModel>> {
    declare key: string;
    declare value: number;
}

CounterModel.init(
    {
        key: {
            type: DataTypes.STRING(255),
            primaryKey: true,
        },
        value: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            defaultValue: 0,
        },
    },
    {
        sequelize,
        tableName: "counters",
        timestamps: false,
    },
);

export const getNextSequence = async (key: string, startAt = 1) => {
    const [counter, created] = await CounterModel.findOrCreate({
        where: { key },
        defaults: {
            key,
            value: startAt,
        },
    });

    if (created) {
        return counter.value;
    }

    counter.value += 1;
    await counter.save();
    return counter.value;
};

const Counter = CounterModel;

export default Counter;
