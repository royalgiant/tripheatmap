import mapboxgl from "mapbox-gl";

async function initNeighborhoodDetailMap() {
  try {
    const el = document.getElementById("neighborhood-detail-map");
    if (!el) {
      console.log('Neighborhood detail map element not found');
      return;
    }

    const token = el.dataset.mapboxToken;
    if (!token) {
      console.error('Mapbox token is missing!');
      return;
    }

    const placesData = JSON.parse(el.dataset.places || '[]');
    const neighborhoodData = JSON.parse(el.dataset.neighborhood || '{}');

    console.log('Initializing neighborhood detail map with', placesData.length, 'places');

    // Track active filters (all active by default)
    const activeFilters = {
      restaurant: true,
      cafe: true,
      bar: true
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
    const avgLat = placesData.reduce((sum, p) => sum + parseFloat(p.lat), 0) / placesData.length;
    const avgLon = placesData.reduce((sum, p) => sum + parseFloat(p.lon), 0) / placesData.length;

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
        bar: '#A855F7'          // Purple
      };

      // Store markers by place ID for list item clicks
      const markersByPlaceId = {};
      
      // Store markers by place type for filtering
      const markersByType = {
        restaurant: [],
        cafe: [],
        bar: []
      };

      // Track currently open popup
      let currentPopup = null;

      // Add markers for each place
      placesData.forEach(place => {
        const lat = parseFloat(place.lat);
        const lon = parseFloat(place.lon);

        if (isNaN(lat) || isNaN(lon)) {
          console.warn('Invalid coordinates for place:', place.name);
          return;
        }

        // Create custom marker
        const markerEl = document.createElement('div');
        markerEl.style.cssText = `
          background-color: ${markerColors[place.place_type] || '#888'};
          width: 12px;
          height: 12px;
          border-radius: 50%;
          border: 2px solid white;
          box-shadow: 0 2px 4px rgba(0,0,0,0.3);
          cursor: pointer;
        `;

        // Create popup
        const popup = new mapboxgl.Popup({ offset: 15 })
          .setHTML(`
            <div style="font-size:14px; max-width: 250px;">
              <b style="font-size:15px;">${place.name}</b><br/>
              <div style="margin: 6px 0; color: #666;">
                <span style="display: inline-block; padding: 2px 8px; border-radius: 4px; background: ${markerColors[place.place_type]}; color: white; font-size: 12px;">
                  ${place.place_type.charAt(0).toUpperCase() + place.place_type.slice(1)}
                </span>
              </div>
              ${place.address ? `<div style="font-size: 13px; color: #888;">${place.address}</div>` : ''}
            </div>
          `);

        // Create marker with popup
        const marker = new mapboxgl.Marker(markerEl)
          .setLngLat([lon, lat])
          .setPopup(popup)
          .addTo(map);

        // Store marker reference for list item clicks
        markersByPlaceId[place.id] = { marker, popup, lat, lon };
        
        // Store marker by type for filtering
        if (markersByType[place.place_type]) {
          markersByType[place.place_type].push(marker);
        }

        // Listen for popup open to track it and close others
        popup.on('open', () => {
          if (currentPopup && currentPopup !== popup) {
            currentPopup.remove();
          }
          currentPopup = popup;
        });

        // Add click handler to scroll to place in list
        markerEl.addEventListener('click', () => {
          const placeElement = document.getElementById(`place-${place.id}`);
          const placesList = document.getElementById('places-list');

          if (placeElement && placesList) {
            // Calculate the position relative to the scrollable container
            const containerTop = placesList.scrollTop;
            const containerHeight = placesList.clientHeight;
            const elementTop = placeElement.offsetTop;
            const elementHeight = placeElement.clientHeight;

            // Scroll so the element is centered in the container
            const scrollTo = elementTop - (containerHeight / 2) + (elementHeight / 2);

            placesList.scrollTo({
              top: scrollTo,
              behavior: 'smooth'
            });

            // Highlight the element briefly
            placeElement.style.backgroundColor = '#fef3c7';
            setTimeout(() => {
              placeElement.style.backgroundColor = '';
            }, 2000);
          }
        });
      });

      // Add click handlers to place name links in list
      document.querySelectorAll('.place-name-link').forEach(link => {
        link.addEventListener('click', (e) => {
          e.preventDefault();
          const placeId = parseInt(link.dataset.placeId);
          const markerData = markersByPlaceId[placeId];

          if (markerData) {
            // Close previously open popup
            if (currentPopup) {
              currentPopup.remove();
              currentPopup = null;
            }

            // Pan to marker location
            map.flyTo({
              center: [markerData.lon, markerData.lat],
              zoom: 15,
              duration: 1000
            });

            // Toggle popup after pan
            setTimeout(() => {
              markerData.marker.togglePopup();
            }, 500);
          }
        });
      });

      // Fit map to show all markers
      const bounds = new mapboxgl.LngLatBounds();
      placesData.forEach(place => {
        const lat = parseFloat(place.lat);
        const lon = parseFloat(place.lon);
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
        <div style="font-weight: bold; margin-bottom: 8px; color: #333;">Place Types</div>
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

      console.log('Neighborhood detail map fully initialized with', placesData.length, 'markers');
      
      // Add filter toggle functionality
      setupFilterToggles();
      
      function setupFilterToggles() {
        const filterButtons = document.querySelectorAll('.place-type-filter');
        
        filterButtons.forEach(button => {
          button.addEventListener('click', () => {
            const placeType = button.dataset.placeType;
            
            // Toggle the filter state
            activeFilters[placeType] = !activeFilters[placeType];
            
            // Update button styling
            updateButtonStyle(button, activeFilters[placeType]);
            
            // Show/hide places in list
            togglePlacesList(placeType, activeFilters[placeType]);
            
            // Show/hide markers on map
            toggleMarkers(placeType, activeFilters[placeType]);
          });
        });
      }
      
      function updateButtonStyle(button, isActive) {
        if (isActive) {
          // Active state - normal colors
          button.style.opacity = '1';
          button.style.borderColor = '';
          button.classList.remove('opacity-40');
        } else {
          // Inactive state - grayed out
          button.style.opacity = '0.4';
          button.classList.add('opacity-40');
        }
      }
      
      function togglePlacesList(placeType, show) {
        const section = document.querySelector(`.places-section[data-place-type="${placeType}"]`);
        if (section) {
          section.style.display = show ? 'block' : 'none';
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
    console.error('Error initializing neighborhood detail map:', error);
  }
}

document.addEventListener("turbo:load", initNeighborhoodDetailMap);
document.addEventListener("DOMContentLoaded", initNeighborhoodDetailMap);
