// Service worker de Firebase Cloud Messaging. Tiene que vivir en la raíz de
// /web para registrarse con scope '/'. La versión del SDK de gstatic
// (12.19.0) tiene que coincidir con `supportedFirebaseJsSdkVersion` del
// paquete `firebase_core_web` instalado: si se actualiza `firebase_core` o
// `firebase_messaging`, revisar ese valor en
// firebase_core_web/lib/src/firebase_sdk_version.dart y actualizar acá.
importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAk4dh39KnNpQ5dKi1jTr8rSYnFiRKYJRE',
  authDomain: 'grupo4-agendamedica.firebaseapp.com',
  projectId: 'grupo4-agendamedica',
  storageBucket: 'grupo4-agendamedica.firebasestorage.app',
  messagingSenderId: '405535204368',
  appId: '1:405535204368:web:a08b652f95af2fa5859695',
});

firebase.messaging();
