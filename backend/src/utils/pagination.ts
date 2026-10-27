export type PaginationInput = {
    page?: number;
    limit?: number;
    maxLimit?: number;
};

export const normalizePagination = ({ page = 1, limit = 10, maxLimit = 100 }: PaginationInput = {}) => {
    const safePage = Number.isFinite(page) && page > 0 ? Math.floor(page) : 1;
    const safeLimit = Number.isFinite(limit) && limit > 0 ? Math.min(Math.floor(limit), maxLimit) : 10;

    return {
        page: safePage,
        limit: safeLimit,
        offset: (safePage - 1) * safeLimit,
    };
};

export const buildPaginationMeta = (page: number, limit: number, totalItems: number) => ({
    page,
    limit,
    total: totalItems,
    totalPages: Math.max(1, Math.ceil(totalItems / limit)),
});
