import {
    FindOptions,
    Model,
    Op,
    Order,
    WhereOptions,
} from "sequelize";

type Primitive = string | number | boolean | Date | null;

type ComparisonValue = Primitive | Primitive[];

type OperatorFilter = {
    $in?: Primitive[];
    $gte?: Primitive;
    $lte?: Primitive;
};

export type SimpleFilter<T> = {
    [K in keyof T]?: ComparisonValue | OperatorFilter;
} & {
    $or?: Array<SimpleFilter<T>>;
};

type SortSpec = Record<string, 1 | -1>;

const isDate = (value: unknown): value is Date => value instanceof Date;

const isOperatorFilter = (value: unknown): value is OperatorFilter =>
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value) &&
    !isDate(value) &&
    ["$in", "$gte", "$lte"].some((key) => key in value);

export const buildWhere = <T>(filter: SimpleFilter<T> = {} as SimpleFilter<T>): WhereOptions => {
    const where: Record<string | symbol, unknown> = {};

    if (filter.$or?.length) {
        where[Op.or] = filter.$or.map((entry) => buildWhere(entry));
    }

    for (const [key, value] of Object.entries(filter)) {
        if (key === "$or" || value === undefined) {
            continue;
        }

        if (value === null) {
            where[key] = {
                [Op.is]: null,
            };
            continue;
        }

        if (isOperatorFilter(value)) {
            const condition: Record<string | symbol, Primitive[] | Primitive> = {};

            if (value.$in) {
                condition[Op.in] = value.$in;
            }

            if (value.$gte !== undefined) {
                condition[Op.gte] = value.$gte;
            }

            if (value.$lte !== undefined) {
                condition[Op.lte] = value.$lte;
            }

            where[key] = condition;
            continue;
        }

        where[key] = value;
    }

    return where as never;
};

const buildOrder = (sort?: SortSpec): Order | undefined => {
    if (!sort) {
        return undefined;
    }

    return Object.entries(sort).map(([field, direction]) => [
        field,
        direction === -1 ? "DESC" : "ASC",
    ]);
};

const toPlain = <TModel extends Model>(row: TModel) => row.get({ plain: true });

export class MySqlQuery<TModel extends Model> implements PromiseLike<TModel[]> {
    private sortSpec?: SortSpec;
    private offsetValue?: number;
    private limitValue?: number;
    private leanEnabled = false;

    constructor(private readonly executeQuery: (options: FindOptions) => Promise<TModel[]>) {}

    sort(sort: SortSpec) {
        this.sortSpec = sort;
        return this;
    }

    skip(value: number) {
        this.offsetValue = value;
        return this;
    }

    limit(value: number) {
        this.limitValue = value;
        return this;
    }

    lean() {
        this.leanEnabled = true;
        return this as unknown as PromiseLike<Record<string, unknown>[]>;
    }

    async exec() {
        const rows = await this.executeQuery({
            order: buildOrder(this.sortSpec),
            offset: this.offsetValue,
            limit: this.limitValue,
        });

        if (this.leanEnabled) {
            return rows.map(toPlain);
        }

        return rows;
    }

    then<TResult1 = TModel[], TResult2 = never>(
        onfulfilled?: ((value: TModel[]) => TResult1 | PromiseLike<TResult1>) | null,
        onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null,
    ) {
        return this.exec().then(onfulfilled, onrejected);
    }

    catch<TResult = never>(
        onrejected?: ((reason: unknown) => TResult | PromiseLike<TResult>) | null,
    ) {
        return this.exec().catch(onrejected);
    }

    finally(onfinally?: (() => void) | null) {
        return this.exec().finally(onfinally);
    }
}

export const buildDocumentQuery = <TModel extends Model, TFilter>(
    model: {
        findAll(options: FindOptions): Promise<TModel[]>;
    },
    filter: SimpleFilter<TFilter> = {} as SimpleFilter<TFilter>,
) =>
    new MySqlQuery<TModel>((options) =>
        model.findAll({
            ...options,
            where: buildWhere(filter),
        }),
    );

export const findOneByFilter = async <TModel extends Model, TFilter>(
    model: {
        findOne(options: FindOptions): Promise<TModel | null>;
    },
    filter: SimpleFilter<TFilter>,
) =>
    model.findOne({
        where: buildWhere(filter),
    });

export const countDocumentsByFilter = async <TModel extends Model, TFilter>(
    model: {
        count(options: FindOptions): Promise<number>;
    },
    filter: SimpleFilter<TFilter> = {} as SimpleFilter<TFilter>,
) =>
    model.count({
        where: buildWhere(filter),
    });

export const deleteOneByFilter = async <TModel extends Model, TFilter>(
    model: {
        destroy(options: FindOptions & { limit?: number }): Promise<number>;
    },
    filter: SimpleFilter<TFilter>,
) =>
    model.destroy({
        where: buildWhere(filter),
        limit: 1,
    });

export const updateOneByFilter = async <TModel extends Model, TFilter>(
    model: {
        update(
            values: Record<string, unknown>,
            options: FindOptions & { limit?: number },
        ): Promise<[number]>;
    },
    filter: SimpleFilter<TFilter>,
    values: Record<string, unknown>,
) =>
    model.update(values, {
        where: buildWhere(filter),
        limit: 1,
    });

export const parseJsonValue = <T>(value: unknown, fallback: T): T => {
    if (value === null || value === undefined || value === "") {
        return fallback;
    }

    if (typeof value !== "string") {
        return value as T;
    }

    try {
        return JSON.parse(value) as T;
    } catch {
        return fallback;
    }
};

export const stringifyJsonValue = (value: unknown) => JSON.stringify(value);

export const isFindOptions = (value: unknown): value is FindOptions =>
    typeof value === "object" &&
    value !== null &&
    [
        "where",
        "attributes",
        "include",
        "order",
        "limit",
        "offset",
        "transaction",
        "logging",
    ].some((key) => key in value);
