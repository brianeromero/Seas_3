const { onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

// Updated service account path
const serviceAccount = require("./smart-abacus-425519-r7-firebase-adminsdk-410m4-41d7d6ad89.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://smart-abacus-425519-r7-default-rtdb.firebaseio.com",
});

// Example function to generate a custom token
exports.getCustomToken = onCall((data, context) => {
  const uid = context.auth.uid;
  logger.info(`Generating custom token for ${uid}`);
});