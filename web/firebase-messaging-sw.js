importScripts('https://www.gstatic.com/firebasejs/9.6.10/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.6.10/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyCUKRLniu0ndndxYGyt8JtU2UtImH52FFE",
  authDomain: "frappe-dollars.firebaseapp.com",
  projectId: "frappe-dollars",
  storageBucket: "frappe-dollars.firebasestorage.app",
  messagingSenderId: "460271892368",
  appId: "1:460271892368:web:98f3b8aa9e19cc0962a515"
});

const messaging = firebase.messaging();
