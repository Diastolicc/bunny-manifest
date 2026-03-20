const express = require('express');
const admin = require('firebase-admin');
const path = require('path');

const app = express();
const PORT = 3000;

// Initialize Firebase Admin SDK
const serviceAccount = {
  // You'll need to download your service account key from Firebase Console
  // Project Settings > Service Accounts > Generate New Private Key
  type: "service_account",
  project_id: "bunny-59131",
  // ... other service account fields
};

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://bunny-59131-default-rtdb.firebaseio.com"
});

const db = admin.firestore();

app.use(express.static('public'));
app.use(express.json());

// Serve admin panel
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'admin.html'));
});

// API endpoints
app.get('/api/users', async (req, res) => {
  try {
    const snapshot = await db.collection('users').get();
    const users = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    res.json(users);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/clubs', async (req, res) => {
  try {
    const snapshot = await db.collection('clubs').get();
    const clubs = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    res.json(clubs);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/parties', async (req, res) => {
  try {
    const snapshot = await db.collection('parties').get();
    const parties = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    res.json(parties);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`Admin server running on http://localhost:${PORT}`);
});
