// City Selector Component
class CitySelector {
  constructor() {
    this.input = document.getElementById('city-search-input');
    this.dropdown = document.getElementById('city-dropdown');
    this.resultsContainer = document.getElementById('city-results');
    this.loadingIndicator = document.getElementById('city-loading');
    this.noResultsMessage = document.getElementById('city-no-results');
    this.cities = [];
    this.isLoading = false;
    
    if (!this.input) return;
    
    this.init();
  }

  async init() {
    await this.fetchCities();
    this.attachEventListeners();
  }

  async fetchCities() {
    try {
      this.showLoading();
      const response = await fetch('/api/v1/cities');
      if (!response.ok) throw new Error('Failed to fetch cities');
      
      this.cities = await response.json();
      this.hideLoading();
    } catch (error) {
      console.error('Error fetching cities:', error);
      this.hideLoading();
    }
  }

  attachEventListeners() {
    // Show dropdown on focus
    this.input.addEventListener('focus', () => {
      if (this.cities.length > 0) {
        this.renderResults(this.cities);
        this.showDropdown();
      }
    });

    // Filter cities on input
    this.input.addEventListener('input', (e) => {
      const query = e.target.value.toLowerCase().trim();
      
      if (query === '') {
        this.renderResults(this.cities);
      } else {
        const filtered = this.cities.filter(city => 
          city.name.toLowerCase().includes(query) ||
          city.key.toLowerCase().includes(query)
        );
        this.renderResults(filtered);
      }
      
      this.showDropdown();
    });

    // Close dropdown when clicking outside
    document.addEventListener('click', (e) => {
      if (!this.input.contains(e.target) && !this.dropdown.contains(e.target)) {
        this.hideDropdown();
      }
    });

    // Handle keyboard navigation
    this.input.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        this.hideDropdown();
        this.input.blur();
      }
    });
  }

  renderResults(cities) {
    if (cities.length === 0) {
      this.resultsContainer.classList.add('hidden');
      this.noResultsMessage.classList.remove('hidden');
      return;
    }

    this.resultsContainer.classList.remove('hidden');
    this.noResultsMessage.classList.add('hidden');

    this.resultsContainer.innerHTML = cities.map(city => `
      <a 
        href="/maps/places/${city.slug}"
        class="city-option flex items-center justify-between px-4 py-3 hover:bg-gray-700 transition-colors cursor-pointer group"
        data-city-key="${city.key}"
      >
        <div>
          <div class="font-medium text-white group-hover:text-blue-400">${city.name}</div>
          <div class="text-sm text-gray-400">${city.neighborhood_count} neighborhoods</div>
        </div>
        <svg class="w-5 h-5 text-gray-600 group-hover:text-blue-400 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
        </svg>
      </a>
    `).join('');
  }

  showDropdown() {
    this.dropdown.classList.remove('hidden');
  }

  hideDropdown() {
    this.dropdown.classList.add('hidden');
  }

  showLoading() {
    this.isLoading = true;
    this.loadingIndicator.classList.remove('hidden');
    this.resultsContainer.classList.add('hidden');
    this.noResultsMessage.classList.add('hidden');
    this.showDropdown();
  }

  hideLoading() {
    this.isLoading = false;
    this.loadingIndicator.classList.add('hidden');
  }
}

// Initialize on page load
function initCitySelector() {
  if (document.getElementById('city-search-input')) {
    new CitySelector();
  }
}

document.addEventListener('turbo:load', initCitySelector);
document.addEventListener('DOMContentLoaded', initCitySelector);

