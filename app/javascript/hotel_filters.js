// Hotel Filters with client-side filtering + URL updates (no page reload)
class HotelFilters {
  constructor() {
    this.form = document.querySelector('form[data-hotel-filters-form]');
    this.toggleButton = document.getElementById('filter-toggle');
    this.panel = document.getElementById('filter-panel');
    this.priceSlider = document.getElementById('price-slider');
    this.priceSliderLabel = document.getElementById('price-slider-label');
    this.filterCountText = document.getElementById('filter-count-text');

    if (!this.form) {
      console.log('HotelFilters: Form not found.');
      return;
    }

    this.init();
  }

  init() {
    console.log('HotelFilters: Initializing client-side filters with URL updates...');
    this.attachEventListeners();
    this.updateFilterCount();
    this.updateSliderLabel();
    // Apply initial filters based on URL params
    this.filterHotels();
  }

  attachEventListeners() {
    // Toggle Filter Panel
    if (this.toggleButton && this.panel) {
      this.toggleButton.addEventListener('click', (e) => {
        e.preventDefault();
        this.panel.classList.toggle('hidden');
      });
    }

    // Prevent form submission (we'll handle filtering client-side)
    this.form.addEventListener('submit', (e) => {
      e.preventDefault();
    });

    // Apply filters on change (client-side, no page reload)
    const filterInputs = this.form.querySelectorAll('.filter-checkbox, #price-slider');
    filterInputs.forEach(input => {
      if (input.type === 'range') {
        // Debounce slider changes
        input.addEventListener('input', () => this.updateSliderLabel());
        input.addEventListener('change', () => {
          clearTimeout(this.sliderTimeout);
          this.sliderTimeout = setTimeout(() => {
            this.filterHotels();
            this.updateURL();
          }, 500);
        });
      } else {
        // Filter immediately for checkboxes
        input.addEventListener('change', () => {
          this.filterHotels();
          this.updateURL();
        });
      }
    });
  }

  filterHotels() {
    const selectedPriceRadio = this.form.querySelector('input[name="price"]:checked');
    const selectedPrice = selectedPriceRadio ? selectedPriceRadio.value : '';

    const selectedRatingRadio = this.form.querySelector('input[name="rating"]:checked');
    const selectedRating = selectedRatingRadio && selectedRatingRadio.value ? parseFloat(selectedRatingRadio.value) : null;

    const selectedNeighborhoods = Array.from(this.form.querySelectorAll('input[name="neighborhood[]"]:checked')).map(cb => cb.value);

    let maxAvgPrice = Infinity;
    let sliderActive = false;

    if (this.priceSlider) {
      const sliderVal = parseFloat(this.priceSlider.value);
      const sliderMax = parseFloat(this.priceSlider.max);

      if (sliderVal < sliderMax) {
        maxAvgPrice = sliderVal;
        sliderActive = true;
      }
    }

    this.updateFilterCount();

    // Query hotel items fresh each time to include lazy-loaded content
    const hotelItems = document.querySelectorAll('.hotel-item');

    hotelItems.forEach(item => {
      const price = item.dataset.price;
      const rating = parseFloat(item.dataset.rating);
      const neighborhoodSlug = String(item.dataset.neighborhoodSlug || '');
      const avgPrice = parseFloat(item.dataset.averagePrice);

      const priceMatch = !selectedPrice || selectedPrice === price;
      const ratingMatch = !selectedRating || rating >= selectedRating;
      const neighborhoodMatch = selectedNeighborhoods.length === 0 || selectedNeighborhoods.includes(neighborhoodSlug);

      let avgPriceMatch = true;
      if (sliderActive) {
        if (isNaN(avgPrice)) {
          avgPriceMatch = false;
        } else {
          avgPriceMatch = avgPrice <= maxAvgPrice;
        }
      }

      if (priceMatch && ratingMatch && neighborhoodMatch && avgPriceMatch) {
        item.style.display = '';
      } else {
        item.style.display = 'none';
      }
    });
  }

  updateURL() {
    // Build clean URL without page reload using History API
    const formData = new FormData(this.form);
    const queryParts = [];

    // Handle price filter (radio button)
    const price = formData.get('price');
    if (price) {
      queryParts.push(`price=${price}`);
    }

    // Handle rating filter (radio button)
    const rating = formData.get('rating');
    if (rating) {
      queryParts.push(`rating=${rating}`);
    }

    // Handle neighborhood filters (checkboxes)
    const neighborhoods = formData.getAll('neighborhood[]');
    neighborhoods.forEach(n => {
      queryParts.push(`neighborhood=${encodeURIComponent(n)}`);
    });

    // Handle max price slider
    const maxPrice = formData.get('max_price');
    const sliderMax = parseFloat(this.priceSlider?.max);
    if (maxPrice && parseFloat(maxPrice) < sliderMax) {
      queryParts.push(`max_price=${maxPrice}`);
    }

    // Build new URL with unencoded $ symbols
    const queryString = queryParts.join('&').replace(/%24/g, '$');
    const newURL = queryString ? `${window.location.pathname}?${queryString}` : window.location.pathname;

    // Update URL without reload
    window.history.pushState({}, '', newURL);
  }

  updateSliderLabel() {
    if (!this.priceSlider || !this.priceSliderLabel) return;

    const value = parseFloat(this.priceSlider.value);
    const max = parseFloat(this.priceSlider.dataset.max || this.priceSlider.max);

    if (value >= max) {
      this.priceSliderLabel.textContent = 'Any';
    } else {
      this.priceSliderLabel.textContent = `< $${Math.round(value)}`;
    }
  }

  updateFilterCount() {
    if (!this.filterCountText || !this.form) return;

    let count = 0;

    // Count price radio (if not "Any")
    const priceRadio = this.form.querySelector('input[name="price"]:checked');
    if (priceRadio && priceRadio.value) count++;

    // Count rating radio (if not "Any")
    const ratingRadio = this.form.querySelector('input[name="rating"]:checked');
    if (ratingRadio && ratingRadio.value) count++;

    // Count neighborhood checkboxes
    const checkedNeighborhoods = this.form.querySelectorAll('input[name="neighborhood[]"]:checked');
    count += checkedNeighborhoods.length;

    // Check if slider is active (not at max)
    if (this.priceSlider) {
      const value = parseFloat(this.priceSlider.value);
      const max = parseFloat(this.priceSlider.dataset.max || this.priceSlider.max);
      if (value < max) count++;
    }

    this.filterCountText.textContent = count > 0 ? `${count} Filters` : 'Filters';
  }
}

// Initialize on page load
function initHotelFilters() {
  const form = document.querySelector('form[data-hotel-filters-form]');
  if (form && !form.dataset.filtersInitialized) {
    form.dataset.filtersInitialized = "true";
    new HotelFilters();
  }
}

document.addEventListener('turbo:load', initHotelFilters);
document.addEventListener('DOMContentLoaded', initHotelFilters);