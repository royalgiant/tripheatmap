// app/javascript/application.js
//= require select2

import { Turbo } from "@hotwired/turbo-rails"
import "./mapbox_heatmap"
import "./places_map"
import "./neighborhood_detail_map"
import "./city_selector"

Turbo.start()