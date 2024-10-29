/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onCall} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

admin.initializeApp();

// Example function to generate a custom token
exports.getCustomToken = onCall((data, context) => {
  const uid = context.auth.uid;
  logger.info(`Generating custom token for ${uid}`);
  return admin.auth().createCustomToken(uid);
});

