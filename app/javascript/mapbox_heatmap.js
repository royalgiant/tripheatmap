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
  const neighborhoods = await response.json();

  const geojson = {
    type: "FeatureCollection",
    features: neighborhoods.map(n => ({
      type: "Feature",
      geometry: { type: "Point", coordinates: [n.lon, n.lat] },
      properties: {
        city: n.city,
        neighborhood: n.neighborhood,
        risk_level: n.risk_level,
        risk_score: n.risk_score,
        post_count: n.post_count,
        summaries: n.summaries ? n.summaries.join(' • ') : ''
      }
    }))
  };

  map.on("load", () => {
    map.addSource("neighborhoods", { type: "geojson", data: geojson });

    // Add heatmap layer for density visualization
    map.addLayer({
      id: "neighborhood-heatmap",
      type: "heatmap",
      source: "neighborhoods",
      paint: {
        // Increase weight for higher risk scores
        "heatmap-weight": [
          "interpolate",
          ["linear"],
          ["get", "risk_score"],
          0, 0.2,
          5, 0.5,
          10, 1
        ],
        // Increase intensity as you zoom in
        "heatmap-intensity": [
          "interpolate",
          ["linear"],
          ["zoom"],
          0, 0.5,
          9, 1.5
        ],
        // Color ramp for heatmap - green to yellow to red
        "heatmap-color": [
          "interpolate",
          ["linear"],
          ["heatmap-density"],
          0, "rgba(0, 0, 0, 0)",
          0.2, "rgba(0, 255, 127, 0.3)",
          0.4, "rgba(173, 255, 47, 0.5)",
          0.6, "rgba(255, 215, 0, 0.6)",
          0.8, "rgba(255, 140, 0, 0.7)",
          1, "rgba(255, 69, 0, 0.8)"
        ],
        // Adjust radius by zoom level
        "heatmap-radius": [
          "interpolate",
          ["linear"],
          ["zoom"],
          0, 15,
          5, 30,
          9, 50
        ],
        // Fade out heatmap at higher zoom levels
        "heatmap-opacity": [
          "interpolate",
          ["linear"],
          ["zoom"],
          3, 0.9,
          9, 0.6,
          12, 0.3
        ]
      }
    });

    // Add large semi-transparent circles to represent neighborhood zones
    map.addLayer({
      id: "neighborhood-zones",
      type: "circle",
      source: "neighborhoods",
      paint: {
        // Size based on number of posts (indicates data density)
        "circle-radius": [
          "interpolate",
          ["linear"],
          ["zoom"],
          3, ["*", ["sqrt", ["get", "post_count"]], 3],
          9, ["*", ["sqrt", ["get", "post_count"]], 10],
          12, ["*", ["sqrt", ["get", "post_count"]], 20]
        ],
        "circle-color": [
          "match",
          ["get", "risk_level"],
          "safe", "#00FF7F",
          "caution", "#FFD700",
          "dangerous", "#FF4500",
          "#888888"
        ],
        "circle-opacity": 0.3,
        "circle-blur": 0.8,
        "circle-stroke-width": 2,
        "circle-stroke-color": [
          "match",
          ["get", "risk_level"],
          "safe", "#00FF7F",
          "caution", "#FFD700",
          "dangerous", "#FF4500",
          "#888888"
        ],
        "circle-stroke-opacity": 0.6
      }
    });

    // Add smaller markers on top for precise locations
    map.addLayer({
      id: "neighborhood-markers",
      type: "circle",
      source: "neighborhoods",
      minzoom: 8,
      paint: {
        "circle-radius": [
          "interpolate",
          ["linear"],
          ["zoom"],
          8, 4,
          12, 8
        ],
        "circle-color": [
          "match",
          ["get", "risk_level"],
          "safe", "#00FF7F",
          "caution", "#FFD700",
          "dangerous", "#FF4500",
          "#888888"
        ],
        "circle-opacity": 0.95,
        "circle-stroke-width": 2,
        "circle-stroke-color": "#ffffff"
      }
    });

    const popup = new mapboxgl.Popup({ closeButton: false, closeOnClick: false });

    // Popup interactions for zones
    map.on("mouseenter", "neighborhood-zones", e => {
      map.getCanvas().style.cursor = "pointer";
      const f = e.features[0];
      const { city, neighborhood, risk_level, risk_score, post_count, summaries } = f.properties;
      popup
        .setLngLat(f.geometry.coordinates)
        .setHTML(`
          <div style="font-size:14px; max-width: 300px;">
            <b style="font-size:16px;">${city}${neighborhood ? " – " + neighborhood : ""}</b><br/>
            <div style="margin: 8px 0;">
              Risk Level: <b style="text-transform:capitalize; color: ${
                risk_level === 'dangerous' ? '#FF4500' : 
                risk_level === 'caution' ? '#FFD700' : '#00FF7F'
              }">${risk_level}</b> (Score: ${risk_score})
            </div>
            <small style="color: #aaa;">${post_count} incident${post_count > 1 ? 's' : ''} reported</small>
            ${summaries ? `<div style="margin-top: 8px; padding-top: 8px; border-top: 1px solid #444;"><small>${summaries}</small></div>` : ''}
          </div>
        `)
        .addTo(map);
    });

    map.on("mouseleave", "neighborhood-zones", () => {
      map.getCanvas().style.cursor = "";
      popup.remove();
    });

    // Also add popup for markers
    map.on("mouseenter", "neighborhood-markers", e => {
      map.getCanvas().style.cursor = "pointer";
      const f = e.features[0];
      const { city, neighborhood, risk_level, risk_score, post_count } = f.properties;
      popup
        .setLngLat(f.geometry.coordinates)
        .setHTML(`
          <div style="font-size:14px;">
            <b>${city}${neighborhood ? " – " + neighborhood : ""}</b><br/>
            Risk: <b style="text-transform:capitalize">${risk_level}</b> (${risk_score})<br/>
            <small>${post_count} incident${post_count > 1 ? 's' : ''}</small>
          </div>
        `)
        .addTo(map);
    });

    map.on("mouseleave", "neighborhood-markers", () => {
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
