import mapboxgl from "mapbox-gl";

async function initPlacesMap() {
  try {
    const el = document.getElementById("places-map");
    if (!el) {
      console.log('Places map element not found');
      return;
    }

    const token = el.dataset.mapboxToken;
    const city = el.dataset.city || 'new york';
    const cityDisplay = el.dataset.cityDisplay || 'New York';

    console.log('Initializing places map for city:', cityDisplay);
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
        <div style="font-size: 18px; font-weight: bold;">Loading ${cityDisplay} neighborhoods...</div>
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

    // City coordinates mapping [longitude, latitude]
    const cityCoordinates = {
      // US Cities
      'new york': [-74.00, 40.71],
      'los angeles': [-118.24, 34.05],
      'chicago': [-87.65, 41.85],
      'houston': [-95.37, 29.76],
      'phoenix': [-112.07, 33.45],
      'philadelphia': [-75.16, 39.95],
      'san antonio': [-98.49, 29.42],
      'san diego': [-117.16, 32.72],
      'dallas': [-96.80, 32.78],
      'san jose': [-121.89, 37.34],
      'austin': [-97.74, 30.27],
      'jacksonville': [-81.66, 30.33],
      'fort worth': [-97.32, 32.75],
      'columbus': [-82.99, 39.96],
      'charlotte': [-80.84, 35.23],
      'san francisco': [-122.42, 37.77],
      'indianapolis': [-86.16, 39.77],
      'seattle': [-122.33, 47.61],
      'denver': [-104.99, 39.74],
      'washington': [-77.04, 38.91],
      'boston': [-71.06, 42.36],
      'nashville': [-86.78, 36.16],
      'detroit': [-83.05, 42.33],
      'oklahoma city': [-97.52, 35.47],
      'portland': [-122.68, 45.52],
      'las vegas': [-115.14, 36.17],
      'memphis': [-90.05, 35.15],
      'louisville': [-85.76, 38.25],
      'baltimore': [-76.61, 39.29],
      'milwaukee': [-87.91, 43.04],
      'albuquerque': [-106.65, 35.08],
      'tucson': [-110.93, 32.22],
      'fresno': [-119.77, 36.74],
      'sacramento': [-121.49, 38.58],
      'mesa': [-111.83, 33.42],
      'kansas city': [-94.58, 39.10],
      'atlanta': [-84.39, 33.75],
      'miami': [-80.19, 25.76],
      'colorado springs': [-104.82, 38.83],
      'raleigh': [-78.64, 35.77],
      'omaha': [-95.94, 41.26],
      'long beach': [-118.19, 33.77],
      'virginia beach': [-75.98, 36.85],
      'oakland': [-122.27, 37.80],
      'minneapolis': [-93.26, 44.98],
      'tulsa': [-95.99, 36.15],
      'tampa': [-82.46, 27.95],
      'arlington': [-97.11, 32.74],
      'new orleans': [-90.07, 29.95],
      'wichita': [-97.34, 37.69],
      'cleveland': [-81.69, 41.50],
      'bakersfield': [-119.02, 35.37],
      'aurora': [-104.83, 39.73],
      'anaheim': [-117.91, 33.84],
      'honolulu': [-157.86, 21.31],
      'henderson': [-115.04, 36.04],
      'stockton': [-121.29, 37.96],
      'lexington': [-84.50, 38.04],
      'corpus christi': [-97.40, 27.80],
      'riverside': [-117.40, 33.95],
      'santa ana': [-117.87, 33.75],
      'irvine': [-117.82, 33.68],
      'cincinnati': [-84.51, 39.10],
      'newark': [-74.17, 40.74],
      'st paul': [-93.09, 44.95],
      'pittsburgh': [-79.99, 40.44],
      'greensboro': [-79.79, 36.07],
      'lincoln': [-96.68, 40.81],
      'orlando': [-81.38, 28.54],
      'plano': [-96.70, 33.02],
      'jersey city': [-74.08, 40.72],
      'durham': [-78.90, 35.99],
      'gilbert': [-111.79, 33.35],
      'north las vegas': [-115.12, 36.20],
      'el paso': [-106.49, 31.76],
      // New US Cities
      'charleston': [-79.93, 32.78],
      'savannah': [-81.10, 32.08],
      'sedona': [-111.76, 34.87],
      'aspen': [-106.82, 39.19],
      'scottsdale': [-111.93, 33.49],
      'salt lake city': [-111.89, 40.76],
      'santa fe': [-105.94, 35.69],
      'st louis': [-90.20, 38.63],
      'anchorage': [-149.90, 61.22],
      'boulder': [-105.27, 40.01],
      'napa': [-122.29, 38.30],
      'calistoga': [-122.58, 38.58],
      // International Cities
      'buenos aires': [-58.38, -34.60],
      'marciaga': [10.73, 45.59],
      'costermano sul garda': [10.72, 45.60],
      'verona': [10.99, 45.44]
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
                <div style="margin-bottom: 4px; font-size: 13px;">
                  Airbnb: <b>${props.airbnb_count || 0}</b>
                </div>
                <div style="margin-bottom: 4px; font-size: 13px;">
                  VRBO: <b>${props.vrbo_count || 0}</b>
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
        const slug = e.features[0].properties.slug;
        if (slug) {
          window.open(`/neighborhoods/${slug}`, '_blank');
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
