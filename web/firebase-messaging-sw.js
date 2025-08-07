importScripts('https://www.gstatic.com/firebasejs/10.3.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.3.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyDZCXsGF_rJcvZ3qDUG_s4K2LkhmZdD6mQ",
  authDomain: "wheeltrip-bb5f2.firebaseapp.com",
  projectId: "wheeltrip-bb5f2",
  storageBucket: "wheeltrip-bb5f2.appspot.com",
  messagingSenderId: "268126972165",
  appId: "1:268126972165:web:32e72fe551652f627e2f6c",
});

const messaging = firebase.messaging();
