# config/importmap.rb

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "mapbox-gl", to: "https://ga.jspm.io/npm:mapbox-gl@3.16.0/dist/mapbox-gl.js"
pin "mapbox_heatmap", to: "mapbox_heatmap.js", preload: true
pin "places_map", to: "places_map.js", preload: true