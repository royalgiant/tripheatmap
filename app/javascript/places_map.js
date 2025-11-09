import mapboxgl from "mapbox-gl";

async function initPlacesMap() {
  try {
    const el = document.getElementById("places-map");
    if (!el) {
      console.log('Places map element not found');
      return;
    }

    const token = el.dataset.mapboxToken;
    const city = el.dataset.city_display || 'New York';

    console.log('Initializing places map for city:', city);
    console.log('Mapbox token present:', !!token);

    if (!token) {
      console.error('Mapbox token is missing!');
      return;
    }

    // Add loading indicator
    const loadingDiv = document.createElement('div');
    loadingDiv.style.cssText = `
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background: rgba(0, 0, 0, 0.7);
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      z-index: 1000;
      color: white;
      font-family: Arial, sans-serif;
    `;
    loadingDiv.innerHTML = `
      <div style="text-align: center;">
        <div style="border: 4px solid rgba(255, 255, 255, 0.3); border-top: 4px solid white; border-radius: 50%; width: 50px; height: 50px; animation: spin 1s linear infinite; margin: 0 auto 20px;"></div>
        <div style="font-size: 18px; font-weight: bold;">Loading ${city} neighborhoods...</div>
        <div style="font-size: 14px; color: #aaa; margin-top: 8px;">Fetching vibrancy data</div>
      </div>
      <style>
        @keyframes spin {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
      </style>
    `;
    el.appendChild(loadingDiv);

    mapboxgl.accessToken = token;

    // City coordinates mapping
    const cityCoordinates = {
      'new york': [-74.00, 40.71],
      'dallas': [-96.8, 32.78],
      'chicago': [-87.65, 41.85],
      'miami': [-80.19, 25.76],
      'austin': [-97.74, 30.27],
      'sacramento': [-121.49, 38.58],
      'buenos aires': [-58.38, -34.60]
    };

    const defaultCenter = cityCoordinates[city.toLowerCase()] || [-74.00, 40.71];

    const map = new mapboxgl.Map({
      container: el,
      style: "mapbox://styles/mapbox/dark-v11",
      center: defaultCenter,
      zoom: 10
    });

    console.log('Map created, waiting for load event...');

    map.on("load", async () => {
      console.log('Map loaded, fetching neighborhoods...');

      // Fetch neighborhood boundaries with vibrancy stats
      const neighborhoodsResponse = await fetch(`/api/v1/neighborhoods?city=${city}&include_geometry=true`);

      if (!neighborhoodsResponse.ok) {
        console.error('Failed to fetch neighborhoods:', neighborhoodsResponse.status);
        return;
      }

      const neighborhoodsData = await neighborhoodsResponse.json();

      console.log('Fetched neighborhoods:', neighborhoodsData.features?.length || 0);
      console.log('Sample neighborhood:', neighborhoodsData.features?.[0]);
    // Add neighborhood boundaries layer
    map.addSource("neighborhoods", {
      type: "geojson",
      data: neighborhoodsData
    });

    // Auto-fit map to show all neighborhoods
    if (neighborhoodsData.features && neighborhoodsData.features.length > 0) {
      const bounds = new mapboxgl.LngLatBounds();
      neighborhoodsData.features.forEach(feature => {
        if (feature.geometry && feature.geometry.type === 'MultiPolygon') {
          feature.geometry.coordinates.forEach(polygon => {
            polygon[0].forEach(coord => bounds.extend(coord));
          });
        } else if (feature.geometry && feature.geometry.type === 'Polygon') {
          feature.geometry.coordinates[0].forEach(coord => bounds.extend(coord));
        }
      });
      map.fitBounds(bounds, { padding: 50, duration: 1000 });
    }

    // Choropleth layer - color neighborhoods by vibrancy index (0-10)
    // Higher index = more vibrant (more restaurants, cafes, bars per capita)
    map.addLayer({
      id: "neighborhood-fills",
      type: "fill",
      source: "neighborhoods",
      paint: {
        "fill-color": [
          "step",
          ["get", "vibrancy_index"],
          "#85144b",         // Dark red - very low vibrancy (0-2)
          2, "#FF4136",      // Red - low vibrancy (2-4)
          4, "#FF851B",      // Orange - moderate vibrancy (4-6)
          6, "#FFDC00",      // Yellow - vibrant (6-8)
          8, "#2ECC40"       // Green - very vibrant (8+) - default color
        ],
        "fill-opacity": 0.6
      }
    });

    console.log('Added neighborhood-fills layer');

    // Neighborhood borders
    map.addLayer({
      id: "neighborhood-borders",
      type: "line",
      source: "neighborhoods",
      paint: {
        "line-color": "#ffffff",
        "line-width": 0.5,
        "line-opacity": 0.5
      }
    });

    console.log('Added neighborhood-borders layer');

    const popup = new mapboxgl.Popup({
      closeButton: false,
      closeOnClick: false
    });

    // Hover effects
    map.on("mousemove", "neighborhood-fills", (e) => {
      map.getCanvas().style.cursor = "pointer";

      if (e.features.length > 0) {

        const props = e.features[0].properties;

        popup
          .setLngLat(e.lngLat)
          .setHTML(`
            <div style="font-size:14px; max-width: 300px;">
              <b style="font-size:16px;">${props.name}</b><br/>
              <div style="margin: 8px 0; color: #888;">
                ${props.city}, ${props.state}
                ${props.population ? ` · Pop: ${props.population.toLocaleString()}` : ''}
              </div>
              <div style="margin-top: 8px; padding-top: 8px; border-top: 1px solid #444;">
                <div style="margin-bottom: 4px;">
                  <b>Amenities:</b> ${props.total_amenities || 0} total
                </div>
                <div style="margin-bottom: 4px; font-size: 13px;">
                  Restaurants: <b>${props.restaurant_count || 0}</b>
                </div>
                <div style="margin-bottom: 4px; font-size: 13px;">
                  Cafes: <b>${props.cafe_count || 0}</b>
                </div>
                <div style="margin-bottom: 4px; font-size: 13px;">
                  Bars: <b>${props.bar_count || 0}</b>
                </div>
                ${props.vibrancy_index ? `
                  <div style="margin-top: 8px; padding-top: 8px; border-top: 1px solid #444;">
                    Vibrancy Index: <b style="color: ${
                      props.vibrancy_index > 7 ? '#44ff44' :
                      props.vibrancy_index > 4 ? '#ffaa00' : '#ff4444'
                    }">${Number(props.vibrancy_index).toFixed(1)}</b> / 10
                  </div>
                ` : ''}
              </div>
            </div>
          `)
          .addTo(map);
      }
    });

    map.on("mouseleave", "neighborhood-fills", () => {
      map.getCanvas().style.cursor = "";
      popup.remove();
    });

    // Click to open neighborhood detail page in new tab
    map.on("click", "neighborhood-fills", async (e) => {
      if (e.features.length > 0) {
        const neighborhoodId = e.features[0].properties.id;
        if (neighborhoodId) {
          window.open(`/neighborhoods/${neighborhoodId}`, '_blank');
        }
      }
    });

    // Add legend
    const legend = document.createElement('div');
    legend.style.cssText = `
      position: absolute;
      bottom: 30px;
      right: 10px;
      background: rgba(0, 0, 0, 0.8);
      padding: 15px;
      border-radius: 8px;
      font-family: Arial, sans-serif;
      color: white;
      font-size: 13px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.3);
    `;
    legend.innerHTML = `
      <div style="font-weight: bold; margin-bottom: 10px;">Neighborhood Vibrancy Index</div>
      <div style="margin-bottom: 5px;">
        <span style="display:inline-block; width:20px; height:15px; background:#2ECC40; margin-right:8px; border: 1px solid #fff;"></span>
        8+: Very Vibrant
      </div>
      <div style="margin-bottom: 5px;">
        <span style="display:inline-block; width:20px; height:15px; background:#FFDC00; margin-right:8px; border: 1px solid #fff;"></span>
        6-8: Vibrant
      </div>
      <div style="margin-bottom: 5px;">
        <span style="display:inline-block; width:20px; height:15px; background:#FF851B; margin-right:8px; border: 1px solid #fff;"></span>
        4-6: Moderate
      </div>
      <div style="margin-bottom: 5px;">
        <span style="display:inline-block; width:20px; height:15px; background:#FF4136; margin-right:8px; border: 1px solid #fff;"></span>
        2-4: Low Vibrancy
      </div>
      <div>
        <span style="display:inline-block; width:20px; height:15px; background:#85144b; margin-right:8px; border: 1px solid #fff;"></span>
        0-2: Very Low
      </div>
      <div style="margin-top: 15px; padding-top: 10px; border-top: 1px solid #444; font-size: 11px; color: #888;">
        Based on density, diversity & volume · Hover for details · Click to zoom
      </div>
    `;
    el.appendChild(legend);

    console.log('Places map fully initialized with', neighborhoodsData.features?.length, 'neighborhoods');

    // Remove loading indicator
    loadingDiv.remove();
  });

  map.on('error', (e) => {
    console.error('Mapbox error:', e);
    // Remove loading indicator on error too
    if (loadingDiv && loadingDiv.parentNode) {
      loadingDiv.remove();
    }
  });

  } catch (error) {
    console.error('Error initializing places map:', error);
    // Remove loading indicator on error
    const el = document.getElementById("places-map");
    if (el) {
      const loadingDiv = el.querySelector('div[style*="z-index: 1000"]');
      if (loadingDiv) loadingDiv.remove();
    }
  }
}

document.addEventListener("turbo:load", initPlacesMap);
document.addEventListener("DOMContentLoaded", initPlacesMap);
