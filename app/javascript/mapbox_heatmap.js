import mapboxgl from "mapbox-gl";

async function initMap() {
  const el = document.getElementById("map");
  if (!el) return;

  const token = el.dataset.mapboxToken;
  const sourceUrl = el.dataset.sourceUrl || "/api/v1/reddit_posts";

  mapboxgl.accessToken = token;

  const map = new mapboxgl.Map({
    container: el,
    style: "mapbox://styles/mapbox/dark-v11",
    center: [-74, 20], // roughly Latin America
    zoom: 3
  });

  const response = await fetch(sourceUrl);
  const geojson = await response.json();

  map.on("load", () => {
    // Add source with clustering
    map.addSource("incidents", {
      type: "geojson",
      data: geojson,
      cluster: true,
      clusterRadius: 60,
      clusterMaxZoom: 14
    });

    // Clusters
    map.addLayer({
      id: "clusters",
      type: "circle",
      source: "incidents",
      filter: ["has", "point_count"],
      paint: {
        "circle-color": "#FFD700",
        "circle-radius": [
          "step",
          ["get", "point_count"],
          15, 5, 20, 10, 25
        ],
        "circle-opacity": 0.7,
        "circle-stroke-width": 2,
        "circle-stroke-color": "#fff"
      }
    });

    // Cluster count
    map.addLayer({
      id: "cluster-count",
      type: "symbol",
      source: "incidents",
      filter: ["has", "point_count"],
      layout: {
        "text-field": ["get", "point_count_abbreviated"],
        "text-font": ["DIN Offc Pro Medium", "Arial Unicode MS Bold"],
        "text-size": 12
      },
      paint: {
        "text-color": "#ffffff"
      }
    });

    // Individual points
    map.addLayer({
      id: "unclustered-point",
      type: "circle",
      source: "incidents",
      filter: ["!", ["has", "point_count"]],
      paint: {
        "circle-color": [
          "match",
          ["get", "risk_level"],
          "safe", "#00FF7F",
          "caution", "#FFD700",
          "dangerous", "#FF4500",
          "#888888"
        ],
        "circle-radius": 8,
        "circle-opacity": 0.8,
        "circle-stroke-width": 2,
        "circle-stroke-color": "#fff"
      }
    });

    const popup = new mapboxgl.Popup({ closeButton: false, closeOnClick: false });

    // Click clusters to zoom
    map.on("click", "clusters", e => {
      const features = map.queryRenderedFeatures(e.point, { layers: ["clusters"] });
      const clusterId = features[0].properties.cluster_id;
      map.getSource("incidents").getClusterExpansionZoom(clusterId, (err, zoom) => {
        if (err) return;
        map.easeTo({
          center: features[0].geometry.coordinates,
          zoom: zoom
        });
      });
    });

    // Hover clusters
    map.on("mouseenter", "clusters", e => {
      map.getCanvas().style.cursor = "pointer";
      const feature = e.features[0];
      popup
        .setLngLat(feature.geometry.coordinates)
        .setHTML(`
          <div style="font-size:14px;">
            <b>${feature.properties.point_count} incidents</b><br/>
            <small>Click to zoom in</small>
          </div>
        `)
        .addTo(map);
    });

    map.on("mouseleave", "clusters", () => {
      map.getCanvas().style.cursor = "";
      popup.remove();
    });

    // Click individual points to open city page
    map.on("click", "unclustered-point", e => {
      const { city } = e.features[0].properties;
      const cityUrl = `/maps/city/${encodeURIComponent(city)}`;
      window.open(cityUrl, '_blank');
    });

    // Hover individual points
    map.on("mouseenter", "unclustered-point", e => {
      map.getCanvas().style.cursor = "pointer";
      const { city, neighborhood, risk_level, risk_score, summary } = e.features[0].properties;
      popup
        .setLngLat(e.features[0].geometry.coordinates)
        .setHTML(`
          <div style="font-size:14px; max-width: 300px;">
            <b style="font-size:16px;">${city}${neighborhood && neighborhood !== city ? " – " + neighborhood : ""}</b><br/>
            <div style="margin: 8px 0;">
              Risk: <b style="text-transform:capitalize; color: ${
                risk_level === 'dangerous' ? '#FF4500' : 
                risk_level === 'caution' ? '#FFD700' : '#00FF7F'
              }">${risk_level}</b> (${risk_score})
            </div>
            ${summary ? `<div style="margin-top: 8px; padding-top: 8px; border-top: 1px solid #444;"><small>${summary}</small></div>` : ''}
            <div style="margin-top: 8px; padding-top: 8px; border-top: 1px solid #444;">
              <small style="color: #60A5FA;">Click to view all ${city} incidents →</small>
            </div>
          </div>
        `)
        .addTo(map);
    });

    map.on("mouseleave", "unclustered-point", () => {
      map.getCanvas().style.cursor = "";
      popup.remove();
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
      <div style="font-weight: bold; margin-bottom: 10px;">Risk Levels</div>
      <div style="margin-bottom: 5px;">
        <span style="display:inline-block; width:15px; height:15px; background:#00FF7F; border-radius:50%; margin-right:8px;"></span>
        Safe
      </div>
      <div style="margin-bottom: 5px;">
        <span style="display:inline-block; width:15px; height:15px; background:#FFD700; border-radius:50%; margin-right:8px;"></span>
        Caution
      </div>
      <div>
        <span style="display:inline-block; width:15px; height:15px; background:#FF4500; border-radius:50%; margin-right:8px;"></span>
        Dangerous
      </div>
    `;
    el.appendChild(legend);
  });
}

document.addEventListener("turbo:load", initMap);
document.addEventListener("DOMContentLoaded", initMap);
