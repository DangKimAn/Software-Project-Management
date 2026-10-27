import { UserDocument } from "../../models/user";
import { signAuthToken } from "../../modules/auth/auth.service";

export const buildAuthHeader = (
    user:
        | (Pick<UserDocument, "id"> & { role?: "guest" | "host" | "admin" })
        | { id: string; role?: "guest" | "host" | "admin"; roles?: Array<"guest" | "host" | "admin"> },
) => {
    const role = user.role ?? ("roles" in user ? user.roles?.[0] : undefined) ?? "guest";
    return `Bearer ${signAuthToken(user.id, role)}`;
};
