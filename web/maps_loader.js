// Google Maps is only needed on the Map tab, so it is loaded on demand
// instead of on every page load. The app calls lifesaverLoadGoogleMaps()
// before showing the map; repeated calls share one load.
(function () {
  var pending = null;

  window.lifesaverLoadGoogleMaps = function () {
    if (pending) return pending;

    pending = new Promise(function (resolve, reject) {
      // MEDIMAP_* is the pre-rename name, still used by older maps_config.js
      // files on the server.
      var key =
        window.LIFESAVER_GOOGLE_MAPS_API_KEY ||
        window.MEDIMAP_GOOGLE_MAPS_API_KEY;
      if (!key) {
        reject(new Error('Missing LIFESAVER_GOOGLE_MAPS_API_KEY in web/maps_config.js'));
        return;
      }

      window.__lifesaverGoogleMapsReady = function () {
        resolve();
      };

      var script = document.createElement('script');
      script.src =
        'https://maps.googleapis.com/maps/api/js?key=' +
        encodeURIComponent(key) +
        '&loading=async&callback=__lifesaverGoogleMapsReady';
      script.async = true;
      script.onerror = function () {
        script.remove();
        reject(new Error('Google Maps failed to load'));
      };
      document.head.appendChild(script);
    });

    // Allow a retry after a failure (e.g. the user was offline).
    pending.catch(function () {
      pending = null;
    });
    return pending;
  };
})();
