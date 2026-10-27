import { randomUUID } from "node:crypto";

import mongoose from "mongoose";

import { connectDatabase, disconnectDatabase } from "../../config/database";
import { ensureDefaultAmenities } from "../../models/amenity";

const databaseName = `booking_web_test_${Date.now()}_${randomUUID().slice(0, 8)}`;
export const testMongoUri = `mongodb://127.0.0.1:27017/${databaseName}`;

export const setupTestDatabase = async () => {
    process.env.NODE_ENV = "test";
    process.env.JWT_SECRET_KEY ??= "test-secret-key";
    process.env.CONNECT_STRING = testMongoUri;
    process.env.GOOGLE_CLIENT_ID ??= "test-google-client-id";

    await connectDatabase(testMongoUri);
    await ensureDefaultAmenities();
};

export const resetTestDatabase = async () => {
    if (!mongoose.connection.db) {
        return;
    }

    const collections = await mongoose.connection.db.collections();

    for (const collection of collections) {
        await collection.deleteMany({});
    }

    await ensureDefaultAmenities();
};

export const teardownTestDatabase = async () => {
    if (mongoose.connection.db) {
        await mongoose.connection.dropDatabase();
    }

    await disconnectDatabase();
};