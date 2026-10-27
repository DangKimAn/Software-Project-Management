export type MutableMock = Record<string, unknown>;

export type PatchEntry = [MutableMock, string, unknown];

export type AsyncOrSync<T = unknown> = T | Promise<T>;

export type TransactionCallback<T = unknown> = (transaction: unknown) => AsyncOrSync<T>;

export type Rejectable = () => Promise<unknown>;

export type AuthenticatedTestUser = {
    id: string;
    userId?: string;
    email: string;
    phone: string;
    name: string;
    username: string;
    status: string;
    roles: string[];
};

export type AuditLogRecord = Record<string, unknown> & {
    action?: string;
    targetId?: number;
};
