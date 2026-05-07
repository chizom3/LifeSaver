(function () {
  var key = window.MEDIMAP_GOOGLE_MAPS_API_KEY;
  if (!key) {
    console.error('Missing MEDIMAP_GOOGLE_MAPS_API_KEY in web/maps_config.js');
    return;
  }

  var script = document.createElement('script');
  script.src =
    'https://maps.googleapis.com/maps/api/js?key=' +
    encodeURIComponent(key) +
    '&loading=async';
  script.async = true;
  document.head.appendChild(script);
})();
