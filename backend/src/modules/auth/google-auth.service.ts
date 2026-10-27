import { OAuth2Client } from "google-auth-library";

import { ApiError } from "../../common/api-error";
import { getEnv } from "../../config/env";
import SocialAccount from "../../models/social-account";
import User from "../../models/user";
import type { UserDocument } from "../../models/user";
import {
    assertUserCanAuthenticate,
    createSocialUser,
    issueAuthSession,
    normalizeEmail,
    toAuthResponseUser,
} from "./auth.service";

const googleIssuers = new Set(["accounts.google.com", "https://accounts.google.com"]);

export type VerifiedGoogleProfile = {
    sub: string;
    email: string;
    emailVerified: boolean;
    name: string;
    picture?: string | null;
};

type GoogleIdTokenVerifier = (idToken: string) => Promise<VerifiedGoogleProfile>;

type GoogleAuthContext = {
    ipAddress?: string | null;
    userAgent?: string | null;
};

const defaultGoogleIdTokenVerifier: GoogleIdTokenVerifier = async (idToken) => {
    const clientId = getEnv().googleClientId;

    if (!clientId) {
        throw new ApiError(500, "Missing Google client id configuration");
    }

    const client = new OAuth2Client(clientId);

    try {
        const ticket = await client.verifyIdToken({
            idToken,
            audience: clientId,
        });
        const payload = ticket.getPayload();

        if (
            !payload ||
            typeof payload.sub !== "string" ||
            typeof payload.email !== "string" ||
            payload.email_verified !== true
        ) {
            throw new ApiError(401, "Invalid Google token");
        }

        if (payload.iss && !googleIssuers.has(payload.iss)) {
            throw new ApiError(401, "Invalid Google token");
        }

        return {
            sub: payload.sub,
            email: payload.email,
            emailVerified: true,
            name: payload.name?.trim() || payload.email,
            picture: payload.picture ?? null,
        };
    } catch (error) {
        if (error instanceof ApiError) {
            throw error;
        }

        throw new ApiError(401, "Invalid Google token");
    }
};

let googleIdTokenVerifier: GoogleIdTokenVerifier = defaultGoogleIdTokenVerifier;

export const setGoogleIdTokenVerifierForTests = (verifier?: GoogleIdTokenVerifier) => {
    googleIdTokenVerifier = verifier ?? defaultGoogleIdTokenVerifier;
};

export const verifyGoogleIdToken = async (idToken: string) => {
    try {
        return await googleIdTokenVerifier(idToken);
    } catch (error) {
        if (error instanceof ApiError) {
            throw error;
        }

        throw new ApiError(401, "Invalid Google token");
    }
};

const applyVerifiedGoogleProfile = async (user: UserDocument, profile: VerifiedGoogleProfile) => {
    let shouldSave = false;

    if (profile.emailVerified && !user.isEmailVerified) {
        user.isEmailVerified = true;
        shouldSave = true;
    }

    if (!user.avatarUrl && profile.picture) {
        user.avatarUrl = profile.picture;
        shouldSave = true;
    }

    if (shouldSave) {
        await user.save();
    }
};

export const authenticateWithGoogleIdToken = async (
    idToken: string,
    context: GoogleAuthContext = {},
) => {
    const profile = await verifyGoogleIdToken(idToken);
    const normalizedEmail = normalizeEmail(profile.email);

    if (!profile.emailVerified || !normalizedEmail) {
        throw new ApiError(401, "Invalid Google token");
    }

    let socialAccount = await SocialAccount.findOne({
        provider: "google",
        providerUid: profile.sub,
    });
    let user = socialAccount ? await User.findById(socialAccount.userId) : null;

    if (socialAccount && !user) {
        await SocialAccount.deleteOne({ id: socialAccount.id });
        socialAccount = null;
    }

    if (user) {
        assertUserCanAuthenticate(user);
        await applyVerifiedGoogleProfile(user, profile);
    }

    if (!user) {
        user = await User.findOne({ email: normalizedEmail });

        if (user) {
            assertUserCanAuthenticate(user);

            const existingGoogleLink = await SocialAccount.findOne({
                provider: "google",
                userId: user._id,
            });

            if (existingGoogleLink && existingGoogleLink.providerUid !== profile.sub) {
                throw new ApiError(409, "Google account is already linked to this user");
            }

            if (!existingGoogleLink) {
                socialAccount = await new SocialAccount({
                    userId: user._id,
                    provider: "google",
                    providerUid: profile.sub,
                }).save();
            } else {
                socialAccount = existingGoogleLink;
            }

            await applyVerifiedGoogleProfile(user, profile);
        } else {
            user = await createSocialUser({
                email: normalizedEmail,
                name: profile.name,
                role: "guest",
                emailVerified: true,
                avatarUrl: profile.picture,
            });

            socialAccount = await new SocialAccount({
                userId: user._id,
                provider: "google",
                providerUid: profile.sub,
            }).save();
        }
    }

    if (!socialAccount) {
        throw new ApiError(500, "Unable to complete Google login");
    }

    if (!user) {
        throw new ApiError(500, "Unable to complete Google login");
    }

    const { accessToken, refreshToken, roles } = await issueAuthSession(user, context);

    return {
        accessToken,
        refreshToken,
        user: await toAuthResponseUser(user, roles),
    };
};
