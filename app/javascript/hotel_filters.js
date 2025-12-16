// Hotel Filters Component
class HotelFilters {
  constructor() {
    this.toggleButton = document.getElementById('filter-toggle');
    this.panel = document.getElementById('filter-panel');
    this.countText = document.getElementById('filter-count-text');
    this.clearButton = document.getElementById('clear-filters');
    this.hotelItems = document.querySelectorAll('.hotel-item');
    this.checkboxes = document.querySelectorAll('.filter-checkbox');

    if (!this.toggleButton || !this.panel) {
      console.log('HotelFilters: Toggle button or panel not found.');
      return;
    }

    this.init();
  }

  init() {
    console.log('HotelFilters: Initializing...');
    this.attachEventListeners();
    // Initialize state
    this.filterHotels(); 
  }

  attachEventListeners() {
    // Toggle Filter Panel
    this.toggleButton.addEventListener('click', (e) => {
      e.preventDefault();
      console.log('HotelFilters: Toggle clicked');
      this.panel.classList.toggle('hidden');
    });

    // Filter Logic on Change
    this.checkboxes.forEach(checkbox => {
      checkbox.addEventListener('change', () => this.filterHotels());
    });

    // Clear All
    if (this.clearButton) {
      this.clearButton.addEventListener('click', (e) => {
        e.preventDefault();
        this.checkboxes.forEach(cb => cb.checked = false);
        this.filterHotels();
      });
    }
  }

  filterHotels() {
    const selectedPrices = Array.from(document.querySelectorAll('input[name="price[]"]:checked')).map(cb => cb.value);
    const selectedRatings = Array.from(document.querySelectorAll('input[name="rating[]"]:checked')).map(cb => parseFloat(cb.value));
    const selectedHoods = Array.from(document.querySelectorAll('input[name="neighborhood[]"]:checked')).map(cb => cb.value);

    // Update Filter Count Text and Clear Button visibility
    const totalFilters = selectedPrices.length + selectedRatings.length + selectedHoods.length;
    
    if (this.countText) {
      this.countText.textContent = totalFilters > 0 ? `${totalFilters} Filters` : 'Filters';
    }
    
    if (this.clearButton) {
      if (totalFilters > 0) {
        this.clearButton.classList.remove('invisible');
      } else {
        this.clearButton.classList.add('invisible');
      }
    }

    this.hotelItems.forEach(item => {
      const price = item.dataset.price;
      const rating = parseFloat(item.dataset.rating);
      const hoodId = String(item.dataset.neighborhoodId || '');

      const priceMatch = selectedPrices.length === 0 || selectedPrices.includes(price);
      const ratingMatch = selectedRatings.length === 0 || selectedRatings.some(minRating => rating >= minRating);
      const hoodMatch = selectedHoods.length === 0 || selectedHoods.includes(hoodId);

      if (priceMatch && ratingMatch && hoodMatch) {
        item.style.display = '';
      } else {
        item.style.display = 'none';
      }
    });
  }
}

// Initialize on page load
function initHotelFilters() {
  const toggle = document.getElementById('filter-toggle');
  if (toggle) {
    // Check if we've already attached a listener to avoid duplicates if Turbo caches the page? 
    // Actually, creating a new class instance adds new listeners. 
    // Ideally we should disconnect old ones, but for now let's just run it.
    // A simple guard to prevent double initialization on the same element could be adding a data attribute.
    if (toggle.dataset.filtersInitialized === "true") return;
    toggle.dataset.filtersInitialized = "true";
    
    new HotelFilters();
  }
}

document.addEventListener('turbo:load', initHotelFilters);
document.addEventListener('DOMContentLoaded', initHotelFilters);