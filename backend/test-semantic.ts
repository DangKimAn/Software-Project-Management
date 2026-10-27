import { semanticSearchListings } from "./src/modules/semantic-search/semantic-search.service";
import sequelize from "./src/config/database";

async function run() {
    try {
        const result = await semanticSearchListings({
            query: "hello/abc/test",
            limit: 12,
        });
        console.log(JSON.stringify(result, null, 2));
    } catch (e) {
        console.error(e);
    } finally {
        await sequelize.close();
    }
}

run();
