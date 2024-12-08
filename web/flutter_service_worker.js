'use strict';

const CACHE_NAME = 'flutter-app-cache';
const RESOURCES = {
  "version.json": "1",
  "index.html": "1",
  "main.dart.js": "1",
  "flutter.js": "1",
  "favicon.png": "1",
  "icons/Icon-192.png": "1",
  "icons/Icon-512.png": "1",
  "manifest.json": "1",
};

self.addEventListener('install', function (event) {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        return cache.addAll(Object.keys(RESOURCES));
      })
  );
});

self.addEventListener('fetch', function (event) {
  event.respondWith(
    caches.match(event.request)
      .then(function (response) {
        if (response) {
          return response;
        }
        return fetch(event.request);
      })
  );
}); 