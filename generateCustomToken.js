const admin = require('firebase-admin');

// Update this path to point to your new service account key JSON file
const serviceAccount = require('/Users/brianromero/Desktop/Desktop/MF_inder/Seas_3/smart-abacus-425519-r7-584a1ad42c13.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://smart-abacus-425519-r7-default-rtdb.firebaseio.com'
});

const userId = 'unique-user-id';

admin.auth().createCustomToken(userId)
  .then((customToken) => console.log(customToken))
  .catch((error) => console.error('Error generating custom token:', error));
