import mapboxgl from "mapbox-gl";
import { escapeHtml } from "./helpers";

async function initCityMap() {
  try {
    const el = document.getElementById("city-map");
    if (!el) {
      console.log('City map element not found');
      return;
    }

    const token = el.dataset.mapboxToken;
    if (!token) {
      console.error('Mapbox token is missing!');
      return;
    }

    const placesData = JSON.parse(el.dataset.places || '[]');
    const poisData = JSON.parse(el.dataset.pois || '[]');

    console.log('Initializing city map with', placesData.length, 'places and', poisData.length, 'POIs');

    // Track active filters (all active by default)
    const activeFilters = {
      luxury: true,
      boutique: true,
      cheap: true,
      bnb: true,
      hotel: true,
      airport: true,
      university: true,
      landmark: true,
      convention_center: true
    };

    if (placesData.length === 0 && poisData.length === 0) {
      el.innerHTML = `
        <div style="display: flex; justify-content: center; align-items: center; height: 100%; color: #666;">
          <p>No places data available to display on map</p>
        </div>
      `;
      return;
    }

    mapboxgl.accessToken = token;

    // Calculate center point from all places and POIs
    const allPoints = [...placesData, ...poisData];
    const avgLat = allPoints.reduce((sum, p) => sum + parseFloat(p.latitude), 0) / allPoints.length;
    const avgLon = allPoints.reduce((sum, p) => sum + parseFloat(p.longitude), 0) / allPoints.length;

    const map = new mapboxgl.Map({
      container: el,
      style: "mapbox://styles/mapbox/streets-v11",
      center: [avgLon, avgLat],
      zoom: 12
    });

    map.on("load", () => {
      console.log('Map loaded, adding markers...');

      // Marker colors by category
      const markerColors = {
        luxury: '#A855F7',           // Purple
        boutique: '#EC4899',         // Pink
        cheap: '#10B981',            // Green
        bnb: '#F59E0B',              // Orange
        hotel: '#3B82F6',            // Blue
        airport: '#6366F1',          // Indigo
        university: '#14B8A6',       // Teal
        landmark: '#EF4444',         // Red
        convention_center: '#EAB308' // Yellow
      };

      // Store markers by category for filtering
      const markersByCategory = {
        luxury: [],
        boutique: [],
        cheap: [],
        bnb: [],
        hotel: [],
        airport: [],
        university: [],
        landmark: [],
        convention_center: []
      };

      // Track currently open popup
      let currentPopup = null;

      // Track coordinates to detect duplicates and offset them
      const coordinateMap = {};

      // Add markers for places
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
          const offsetCount = coordinateMap[coordKey];
          const offsetDistance = 0.00005; // roughly 5 meters

          // Offset in a circular pattern around the original point
          const angle = (offsetCount * 60) * (Math.PI / 180);
          lon += offsetDistance * Math.cos(angle);
          lat += offsetDistance * Math.sin(angle);

          coordinateMap[coordKey]++;
        } else {
          coordinateMap[coordKey] = 1;
        }

        const markerColor = markerColors[place.category] || '#888';

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

        const categoryLabel = {
          luxury: 'Luxury Hotel',
          boutique: 'Boutique Hotel',
          cheap: 'Budget Hotel',
          bnb: 'Bed & Breakfast',
          hotel: 'Hotel'
        }[place.category] || 'Hotel';

        let popupHTML = `
          <div style="font-size:14px; max-width: 250px;">
            <b style="font-size:15px;">${escapeHtml(place.name)}</b><br/>
            <div style="margin: 6px 0; color: #666;">
              <span style="display: inline-block; padding: 2px 8px; border-radius: 4px; background: ${markerColor}; color: white; font-size: 12px;">
                ${categoryLabel}
              </span>
            </div>
            ${place.rating ? `<div style="font-size: 13px; color: #888; margin-bottom: 4px;">⭐ ${place.rating} (${place.review_count || 0} reviews)</div>` : ''}
            ${place.price_range ? `<div style="font-size: 13px; color: #888; margin-bottom: 8px;">${place.price_range}</div>` : ''}
          </div>
        `;

        const popup = new mapboxgl.Popup({
          offset: 15,
          closeButton: true,
          closeOnClick: true
        }).setHTML(popupHTML);

        const marker = new mapboxgl.Marker(markerEl)
          .setLngLat([lon, lat])
          .setPopup(popup)
          .addTo(map);

        if (markersByCategory[place.category]) {
          markersByCategory[place.category].push(marker);
        }

        popup.on('open', () => {
          if (currentPopup && currentPopup !== popup) {
            currentPopup.remove();
          }
          currentPopup = popup;
        });
      });

      // Add POI markers
      poisData.forEach(poi => {
        const lat = parseFloat(poi.latitude);
        const lon = parseFloat(poi.longitude);

        if (isNaN(lat) || isNaN(lon)) {
          console.warn('Invalid coordinates for POI:', poi.name);
          return;
        }

        const markerColor = markerColors[poi.type] || '#888';

        const markerEl = document.createElement('div');
        markerEl.style.cssText = `
          background-color: ${markerColor};
          width: 16px;
          height: 16px;
          border-radius: 4px;
          border: 2px solid white;
          box-shadow: 0 2px 4px rgba(0,0,0,0.3);
          cursor: pointer;
        `;

        const typeLabel = {
          airport: 'Airport',
          university: 'University',
          landmark: 'Landmark',
          convention_center: 'Convention Center'
        }[poi.type] || poi.type;

        let popupHTML = `
          <div style="font-size:14px; max-width: 250px;">
            <b style="font-size:15px;">${escapeHtml(poi.name)}</b><br/>
            <div style="margin: 6px 0; color: #666;">
              <span style="display: inline-block; padding: 2px 8px; border-radius: 4px; background: ${markerColor}; color: white; font-size: 12px;">
                ${typeLabel}
              </span>
            </div>
          </div>
        `;

        const popup = new mapboxgl.Popup({
          offset: 15,
          closeButton: true,
          closeOnClick: true
        }).setHTML(popupHTML);

        const marker = new mapboxgl.Marker(markerEl)
          .setLngLat([lon, lat])
          .setPopup(popup)
          .addTo(map);

        if (markersByCategory[poi.type]) {
          markersByCategory[poi.type].push(marker);
        }

        popup.on('open', () => {
          if (currentPopup && currentPopup !== popup) {
            currentPopup.remove();
          }
          currentPopup = popup;
        });
      });

      // Fit bounds to show all markers
      const bounds = new mapboxgl.LngLatBounds();
      [...placesData, ...poisData].forEach(point => {
        const lat = parseFloat(point.latitude);
        const lon = parseFloat(point.longitude);
        if (!isNaN(lat) && !isNaN(lon)) {
          bounds.extend([lon, lat]);
        }
      });
      map.fitBounds(bounds, { padding: 50, maxZoom: 14 });

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
        max-height: 400px;
        overflow-y: auto;
      `;

      let legendHTML = '<div style="font-weight: bold; margin-bottom: 8px; color: #333;">Legend</div>';

      // Hotels legend
      if (markersByCategory.luxury.length > 0) {
        legendHTML += `
          <div style="margin-bottom: 4px;">
            <span style="display:inline-block; width:12px; height:12px; background:${markerColors.luxury}; border-radius:50%; border: 2px solid white; margin-right:6px;"></span>
            Luxury Hotels
          </div>
        `;
      }
      if (markersByCategory.boutique.length > 0) {
        legendHTML += `
          <div style="margin-bottom: 4px;">
            <span style="display:inline-block; width:12px; height:12px; background:${markerColors.boutique}; border-radius:50%; border: 2px solid white; margin-right:6px;"></span>
            Boutique Hotels
          </div>
        `;
      }
      if (markersByCategory.cheap.length > 0) {
        legendHTML += `
          <div style="margin-bottom: 4px;">
            <span style="display:inline-block; width:12px; height:12px; background:${markerColors.cheap}; border-radius:50%; border: 2px solid white; margin-right:6px;"></span>
            Budget Hotels
          </div>
        `;
      }
      if (markersByCategory.bnb.length > 0) {
        legendHTML += `
          <div style="margin-bottom: 4px;">
            <span style="display:inline-block; width:12px; height:12px; background:${markerColors.bnb}; border-radius:50%; border: 2px solid white; margin-right:6px;"></span>
            Bed & Breakfast
          </div>
        `;
      }
      if (markersByCategory.hotel.length > 0) {
        legendHTML += `
          <div style="margin-bottom: 12px;">
            <span style="display:inline-block; width:12px; height:12px; background:${markerColors.hotel}; border-radius:50%; border: 2px solid white; margin-right:6px;"></span>
            All Hotels
          </div>
        `;
      }

      // POIs legend
      if (markersByCategory.airport.length > 0 || markersByCategory.university.length > 0 ||
          markersByCategory.landmark.length > 0 || markersByCategory.convention_center.length > 0) {
        legendHTML += '<div style="font-weight: bold; margin: 8px 0; padding-top: 8px; border-top: 1px solid #e5e7eb; color: #333;">Points of Interest</div>';
      }

      if (markersByCategory.airport.length > 0) {
        legendHTML += `
          <div style="margin-bottom: 4px;">
            <span style="display:inline-block; width:16px; height:16px; background:${markerColors.airport}; border-radius:4px; border: 2px solid white; margin-right:6px;"></span>
            Airports
          </div>
        `;
      }
      if (markersByCategory.university.length > 0) {
        legendHTML += `
          <div style="margin-bottom: 4px;">
            <span style="display:inline-block; width:16px; height:16px; background:${markerColors.university}; border-radius:4px; border: 2px solid white; margin-right:6px;"></span>
            Universities
          </div>
        `;
      }
      if (markersByCategory.landmark.length > 0) {
        legendHTML += `
          <div style="margin-bottom: 4px;">
            <span style="display:inline-block; width:16px; height:16px; background:${markerColors.landmark}; border-radius:4px; border: 2px solid white; margin-right:6px;"></span>
            Landmarks
          </div>
        `;
      }
      if (markersByCategory.convention_center.length > 0) {
        legendHTML += `
          <div>
            <span style="display:inline-block; width:16px; height:16px; background:${markerColors.convention_center}; border-radius:4px; border: 2px solid white; margin-right:6px;"></span>
            Convention Centers
          </div>
        `;
      }

      legend.innerHTML = legendHTML;
      el.appendChild(legend);

      console.log('City map fully initialized');

      // Add filter toggle functionality
      setupFilterToggles();

      function setupFilterToggles() {
        const filterButtons = document.querySelectorAll('.city-map-filter');

        filterButtons.forEach(button => {
          button.addEventListener('click', () => {
            const category = button.dataset.category;

            // Toggle the filter state
            activeFilters[category] = !activeFilters[category];

            // Update button styling
            updateButtonStyle(button, activeFilters[category]);

            // Show/hide markers on map
            toggleMarkers(category, activeFilters[category]);
          });
        });
      }

      function updateButtonStyle(button, isActive) {
        if (isActive) {
          button.style.opacity = '1';
          button.classList.remove('opacity-40');
        } else {
          button.style.opacity = '0.4';
          button.classList.add('opacity-40');
        }
      }

      function toggleMarkers(category, show) {
        const markers = markersByCategory[category];
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
    console.error('Error initializing city map:', error);
  }
}

document.addEventListener("turbo:load", initCityMap);
document.addEventListener("DOMContentLoaded", initCityMap);
