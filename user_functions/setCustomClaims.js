const admin = require('firebase-admin');

// Initialize the Firebase Admin SDK
const serviceAccount = require('/Users/brianromero/Desktop/Desktop/MF_inder/Seas_3/smart-abacus-425519-r7-firebase-adminsdk-410m4-41d7d6ad89.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: 'https://smart-abacus-425519-r7-default-rtdb.firebaseio.com/' // Use your actual Realtime Database URL
});

// Function to set custom claims
async function setCustomUserClaims(uid) {
    try {
        await admin.auth().setCustomUserClaims(uid, { verified: true });
        console.log(`Custom claims set for user: ${uid}`);
    } catch (error) {
        console.error(`Error setting custom claims for user: ${error.message}`);
    }
}

// Call the function with the user's UID
setCustomUserClaims('<user-uid>'); // Replace <user-uid> with the actual user's UID
