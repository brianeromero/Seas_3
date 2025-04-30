const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

exports.deleteUserData = onRequest((req, res) => {
  logger.info("Delete user data logs!", {structuredData: true});
  res.send("Hello from Firebase!");
});
