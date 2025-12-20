import mapboxgl from "mapbox-gl";

async function initHotelDetailMap() {
  try {
    const el = document.getElementById("hotel-detail-map");
    if (!el) {
      console.log('Hotel detail map element not found');
      return;
    }

    const token = el.dataset.mapboxToken;
    if (!token) {
      console.error('Mapbox token is missing!');
      return;
    }

    const placesData = JSON.parse(el.dataset.places || '[]');

    console.log('Initializing hotel detail map with', placesData.length, 'places');

    // Track active filters (all active by default)
    const activeFilters = {
      restaurant: true,
      cafe: true,
      bar: true,
      hotel_under_100: true,
      hotel_100_200: true,
      hotel_200_plus: true
    };

    if (placesData.length === 0) {
      el.innerHTML = `
        <div style="display: flex; justify-content: center; align-items: center; height: 100%; color: #666;">
          <p>No places data available to display on map</p>
        </div>
      `;
      return;
    }

    mapboxgl.accessToken = token;

    // Calculate center point from all places
    const avgLat = placesData.reduce((sum, p) => sum + parseFloat(p.latitude), 0) / placesData.length;
    const avgLon = placesData.reduce((sum, p) => sum + parseFloat(p.longitude), 0) / placesData.length;

    const map = new mapboxgl.Map({
      container: el,
      style: "mapbox://styles/mapbox/streets-v11",
      center: [avgLon, avgLat],
      zoom: 13
    });

    map.on("load", () => {
      console.log('Map loaded, adding markers...');

      // Marker colors by type
      const markerColors = {
        restaurant: '#3B82F6',  // Blue
        cafe: '#10B981',        // Green
        bar: '#A855F7',         // Purple
        hotel: '#F59E0B'        // Orange (default, will be overridden by price)
      };

      const getHotelColor = (avgPrice) => {
        if (!avgPrice || isNaN(avgPrice)) return '#9CA3AF'; // Gray for no price data
        if (avgPrice < 100) return '#10B981';  // Green for under $100
        if (avgPrice < 200) return '#F59E0B';  // Orange for $100-$200
        return '#EF4444';  // Red for $200+
      };

      // Store markers by place ID for hotel list item clicks
      const markersByPlaceId = {};

      // Store markers by place type for filtering
      const markersByType = {
        restaurant: [],
        cafe: [],
        bar: [],
        hotel_under_100: [],
        hotel_100_200: [],
        hotel_200_plus: []
      };

      // Track currently open popup
      let currentPopup = null;

      // Track coordinates to detect duplicates and offset them
      const coordinateMap = {};

      // Add markers for each place
      placesData.forEach(place => {
        const originalLat = parseFloat(place.latitude);
        const originalLon = parseFloat(place.longitude);

        if (isNaN(originalLat) || isNaN(originalLon)) {
          console.warn('Invalid coordinates for place:', place.name);
          return;
        }

        // Start with original coordinates
        let lat = originalLat;
        let lon = originalLon;

        // Create a coordinate key to detect duplicates
        const coordKey = `${originalLat.toFixed(6)},${originalLon.toFixed(6)}`;

        // If this coordinate already exists, offset slightly
        if (coordinateMap[coordKey]) {
          // Offset by a small amount (about 5-10 meters)
          const offsetCount = coordinateMap[coordKey];
          const offsetDistance = 0.00005; // roughly 5 meters

          // Offset in a circular pattern around the original point
          const angle = (offsetCount * 60) * (Math.PI / 180); // 60 degrees apart
          lon += offsetDistance * Math.cos(angle);
          lat += offsetDistance * Math.sin(angle);

          coordinateMap[coordKey]++;
        } else {
          coordinateMap[coordKey] = 1;
        }

        let markerColor;
        if (place.place_type === 'hotel') {
          markerColor = getHotelColor(parseFloat(place.average_price));
        } else {
          markerColor = markerColors[place.place_type] || '#888';
        }

        const markerEl = document.createElement('div');
        markerEl.style.cssText = `
          background-color: ${markerColor};
          width: 12px;
          height: 12px;
          border-radius: 50%;
          border: 2px solid white;
          box-shadow: 0 2px 4px rgba(0,0,0,0.3);
          cursor: pointer;
        `;

        let popupHTML = `
          <div style="font-size:14px; max-width: 250px;">
            <b style="font-size:15px;">${place.name}</b><br/>
            <div style="margin: 6px 0; color: #666;">
              <span style="display: inline-block; padding: 2px 8px; border-radius: 4px; background: ${markerColor}; color: white; font-size: 12px;">
                ${place.place_type.charAt(0).toUpperCase() + place.place_type.slice(1)}
              </span>
            </div>
            ${place.address ? `<div style="font-size: 13px; color: #888; margin-bottom: 8px;">${place.address}</div>` : ''}
        `;

        // Only show booking link for hotels
        if (place.place_type === 'hotel' && place.trip_affiliate_url) {
          popupHTML += `
            <div style="margin-top: 8px; padding-top: 8px; border-top: 1px solid #e5e7eb;">
              <a href="${place.trip_affiliate_url}" target="_blank" rel="noopener" style="display: inline-flex; align-items: center; color: #059669; text-decoration: none; font-weight: 600; font-size: 13px; padding: 4px 8px; background: #d1fae5; border-radius: 4px;">
                <svg style="width: 14px; height: 14px; margin-right: 4px;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                </svg>
                Book Now
              </a>
            </div>
          `;
        }
        popupHTML += `</div>`;

        const popup = new mapboxgl.Popup({
          offset: 15,
          closeButton: true,
          closeOnClick: true
        }).setHTML(popupHTML);

        const marker = new mapboxgl.Marker(markerEl)
          .setLngLat([lon, lat])
          .setPopup(popup)
          .addTo(map);

        markersByPlaceId[place.id] = { marker, popup, lat, lon };

        let typeKey = place.place_type;
        if (place.place_type === 'hotel') {
          const price = parseFloat(place.average_price);
          if (!price || isNaN(price)) {
            typeKey = 'hotel_100_200'; // Default for hotels without price data
          } else if (price < 100) {
            typeKey = 'hotel_under_100';
          } else if (price < 200) {
            typeKey = 'hotel_100_200';
          } else {
            typeKey = 'hotel_200_plus';
          }
        }

        if (markersByType[typeKey]) {
          markersByType[typeKey].push(marker);
        }

        popup.on('open', () => {
          if (currentPopup && currentPopup !== popup) {
            currentPopup.remove();
          }
          currentPopup = popup;
        });

        // Only add click behavior for hotels to scroll to the list
        if (place.place_type === 'hotel') {
          markerEl.addEventListener('click', () => {
            scrollToHotelInList(place.id);
          });
        }
      });

      // Function to scroll to hotel in list, handling lazy-loaded hotels
      function scrollToHotelInList(hotelId) {
        const attemptScroll = (attempts = 0) => {
          const hotelElement = document.querySelector(`#hotel-list li[data-hotel-id="${hotelId}"]`);

          if (hotelElement) {
            // Found it! Scroll to it
            hotelElement.scrollIntoView({
              behavior: 'smooth',
              block: 'center'
            });

            // Highlight the hotel temporarily
            hotelElement.style.setProperty('background-color', '#fef3c7', 'important');
            setTimeout(() => {
              hotelElement.style.removeProperty('background-color');
            }, 5000);
          } else {
            // Not found yet. Try to load the next page if available
            // Look for a turbo-frame that hasn't loaded yet (still has src attribute)
            const unloadedFrames = Array.from(document.querySelectorAll('turbo-frame[src][loading="lazy"]'));
            const nextFrame = unloadedFrames[0];

            if (nextFrame && attempts < 100) {
              // Scroll the turbo frame into view to trigger loading
              nextFrame.scrollIntoView({ behavior: 'instant', block: 'end' });
              // Wait for it to start loading, then try again
              setTimeout(() => attemptScroll(attempts + 1), 300);
            } else if (attempts < 100) {
              // Keep trying in case loading is in progress
              setTimeout(() => attemptScroll(attempts + 1), 200);
            } else {
              // Give up after many attempts
              console.log(`Hotel ${hotelId} not found in list after attempting to load all pages`);
            }
          }
        };

        attemptScroll();
      }

      document.addEventListener('click', (e) => {
        const link = e.target.closest('.hotel-name-map-link');
        if (link) {
          e.preventDefault();
          const hotelId = parseInt(link.dataset.hotelId);
          const markerData = markersByPlaceId[hotelId];

          if (markerData) {
            const existingPopups = document.querySelectorAll('.mapboxgl-popup');
            existingPopups.forEach(popup => popup.remove());

            if (currentPopup) {
              currentPopup.remove();
              currentPopup = null;
            }

            map.flyTo({
              center: [markerData.lon, markerData.lat],
              zoom: 15,
              duration: 1000
            });

            // Show the popup after flying
            setTimeout(() => {
              const popupsBeforeOpen = document.querySelectorAll('.mapboxgl-popup');
              popupsBeforeOpen.forEach(popup => popup.remove());
              markerData.popup.addTo(map);
            }, 1000);
          }
        }
      });

      const bounds = new mapboxgl.LngLatBounds();
      placesData.forEach(place => {
        const lat = parseFloat(place.latitude);
        const lon = parseFloat(place.longitude);
        if (!isNaN(lat) && !isNaN(lon)) {
          bounds.extend([lon, lat]);
        }
      });
      map.fitBounds(bounds, { padding: 50, maxZoom: 15 });

      // Add legend
      const legend = document.createElement('div');
      legend.style.cssText = `
        position: absolute;
        bottom: 30px;
        right: 10px;
        background: white;
        padding: 12px;
        border-radius: 8px;
        font-family: Arial, sans-serif;
        font-size: 12px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.2);
      `;
      legend.innerHTML = `
        <div style="font-weight: bold; margin-bottom: 8px; color: #333;">Hotels (by price)</div>
        <div style="margin-bottom: 4px;">
          <span style="display:inline-block; width:12px; height:12px; background:#10B981; border-radius:50%; border: 2px solid white; margin-right:6px;"></span>
          Under $100
        </div>
        <div style="margin-bottom: 4px;">
          <span style="display:inline-block; width:12px; height:12px; background:#F59E0B; border-radius:50%; border: 2px solid white; margin-right:6px;"></span>
          $100 - $200
        </div>
        <div style="margin-bottom: 12px;">
          <span style="display:inline-block; width:12px; height:12px; background:#EF4444; border-radius:50%; border: 2px solid white; margin-right:6px;"></span>
          $200+
        </div>
        <div style="font-weight: bold; margin-bottom: 8px; color: #333; padding-top: 8px; border-top: 1px solid #e5e7eb;">Other Places</div>
        <div style="margin-bottom: 4px;">
          <span style="display:inline-block; width:12px; height:12px; background:#3B82F6; border-radius:50%; border: 2px solid white; margin-right:6px;"></span>
          Restaurants
        </div>
        <div style="margin-bottom: 4px;">
          <span style="display:inline-block; width:12px; height:12px; background:#10B981; border-radius:50%; border: 2px solid white; margin-right:6px;"></span>
          Cafes
        </div>
        <div>
          <span style="display:inline-block; width:12px; height:12px; background:#A855F7; border-radius:50%; border: 2px solid white; margin-right:6px;"></span>
          Bars
        </div>
      `;
      el.appendChild(legend);

      console.log('Hotel detail map fully initialized with', placesData.length, 'markers');

      // Add filter toggle functionality
      setupFilterToggles();

      function setupFilterToggles() {
        const filterButtons = document.querySelectorAll('.hotel-map-filter');

        filterButtons.forEach(button => {
          button.addEventListener('click', () => {
            const placeType = button.dataset.placeType;

            // Toggle the filter state
            activeFilters[placeType] = !activeFilters[placeType];

            // Update button styling
            updateButtonStyle(button, activeFilters[placeType]);

            // Show/hide markers on map
            toggleMarkers(placeType, activeFilters[placeType]);
          });
        });
      }

      function updateButtonStyle(button, isActive) {
        if (isActive) {
          // Active state - normal colors
          button.style.opacity = '1';
          button.classList.remove('opacity-40');
        } else {
          // Inactive state - grayed out
          button.style.opacity = '0.4';
          button.classList.add('opacity-40');
        }
      }

      function toggleMarkers(placeType, show) {
        const markers = markersByType[placeType];
        if (markers) {
          markers.forEach(marker => {
            const element = marker.getElement();
            if (element) {
              element.style.display = show ? 'block' : 'none';
            }
          });
        }
      }
    });

    map.on('error', (e) => {
      console.error('Mapbox error:', e);
    });

  } catch (error) {
    console.error('Error initializing hotel detail map:', error);
  }
}

document.addEventListener("turbo:load", initHotelDetailMap);
document.addEventListener("DOMContentLoaded", initHotelDetailMap);
