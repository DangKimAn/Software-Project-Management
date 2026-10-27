import { randomUUID } from "node:crypto";

import bcrypt from "bcryptjs";

export const passwordHashCost = 12;

const fallbackPasswordHash = "$2b$12$eKZSwzTu05dcsxAduTUjKecXvctT38aP7TEH28xTZ4TDxiNyyVvHu";

export const hashPassword = (plainPassword: string) => bcrypt.hash(plainPassword, passwordHashCost);

export const hashRandomPassword = () => hashPassword(randomUUID());

export const comparePassword = async (plainPassword: string, hashedPassword?: string) =>
    bcrypt.compare(plainPassword, hashedPassword ?? fallbackPasswordHash);
