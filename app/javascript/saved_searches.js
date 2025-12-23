// Saved Searches - jQuery Cookie Handling for Guest Users

(function($) {
  'use strict';

  const SavedSearches = {
    COOKIE_NAME: 'pending_saved_search',
    COOKIE_EXPIRY_HOURS: 24,

    init: function() {
      this.checkPendingSearch();
      this.attachEventListeners();
    },

    // Set a cookie with JSON data
    setCookie: function(name, value, hours) {
      const date = new Date();
      date.setTime(date.getTime() + (hours * 60 * 60 * 1000));
      const expires = "expires=" + date.toUTCString();
      document.cookie = name + "=" + JSON.stringify(value) + ";" + expires + ";path=/";
    },

    // Get cookie value
    getCookie: function(name) {
      const nameEQ = name + "=";
      const cookies = document.cookie.split(';');

      for(let i = 0; i < cookies.length; i++) {
        let cookie = cookies[i];
        while (cookie.charAt(0) === ' ') {
          cookie = cookie.substring(1);
        }
        if (cookie.indexOf(nameEQ) === 0) {
          try {
            return JSON.parse(cookie.substring(nameEQ.length));
          } catch(e) {
            return null;
          }
        }
      }
      return null;
    },

    // Delete cookie
    deleteCookie: function(name) {
      document.cookie = name + "=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;";
    },

    // Check if there's a pending search after login
    checkPendingSearch: function() {
      const pendingSearch = this.getCookie(this.COOKIE_NAME);

      if (pendingSearch) {
        console.log('Pending saved search found:', pendingSearch);

        // Check if we're on a matching page
        if (this.isMatchingPage(pendingSearch)) {
          console.log('On matching page, triggering modal...');

          // Wait a bit for page to fully load, then trigger modal
          setTimeout(() => {
            this.triggerSaveModal(pendingSearch);
            this.deleteCookie(this.COOKIE_NAME);
          }, 500);
        } else {
          // Different page, clear cookie
          console.log('Different page, clearing cookie');
          this.deleteCookie(this.COOKIE_NAME);
        }
      }
    },

    // Check if current page matches the pending search location
    isMatchingPage: function(pendingSearch) {
      const currentPath = window.location.pathname;
      const currentParams = new URLSearchParams(window.location.search);

      // Check if location matches (case-insensitive)
      if (pendingSearch.location) {
        const locationInPath = currentPath.toLowerCase().includes(pendingSearch.location.toLowerCase().replace(/\s+/g, '-'));
        return locationInPath;
      }

      return true; // If no location specified, consider it a match
    },

    // Trigger the save search modal
    triggerSaveModal: function(searchData) {
      const $saveBtn = $('#save-search-btn');

      if ($saveBtn.length) {
        console.log('Clicking save search button');
        $saveBtn[0].click();
      } else {
        console.warn('Save search button not found');
      }
    },

    // Attach event listeners
    attachEventListeners: function() {
      const self = this;

      // When save search button is clicked, store filters if user not logged in
      $(document).on('click', '[data-save-search-trigger]', function(e) {
        const $this = $(this);

        // Check if user is logged in by looking for user-specific elements
        // This is a simple check - adjust based on your app's auth indicators
        const isLoggedIn = $('body').data('user-logged-in') ||
                          $('.user-menu').length > 0 ||
                          $('[data-user-email]').length > 0;

        if (!isLoggedIn) {
          e.preventDefault(); // Prevent the default turbo frame navigation
          console.log('Guest user - storing filters in cookie and redirecting to login');

          // Extract search data from URL and button attributes
          const searchData = {
            location: $this.data('location') || self.extractLocationFromUrl(),
            max_price: new URLSearchParams(window.location.search).get('max_price'),
            rating: new URLSearchParams(window.location.search).get('rating'),
            price: new URLSearchParams(window.location.search).get('price'),
            neighborhood: new URLSearchParams(window.location.search).getAll('neighborhood')
          };

          // Store in cookie
          self.setCookie(self.COOKIE_NAME, searchData, self.COOKIE_EXPIRY_HOURS);
          console.log('Stored search data in cookie:', searchData);

          // Redirect to login page with return_to parameter
          const currentUrl = window.location.href;
          window.location.href = '/login?return_to=' + encodeURIComponent(currentUrl);
        }
      });
    },

    // Extract location from current URL
    extractLocationFromUrl: function() {
      const path = window.location.pathname;
      const parts = path.split('/').filter(p => p);

      // Both URL patterns have city at index 2
      // /best/{hotel-type}/{city} -> parts[2]
      // /hotels-near/{category}/{city}/{landmark} -> parts[2]
      if ((parts[0] === 'best' || parts[0] === 'hotels-near') && parts.length >= 3) {
        return parts[2];
      }

      return null;
    }
  };

  // Initialize on document ready and turbo:load
  $(document).ready(function() {
    SavedSearches.init();
  });

  $(document).on('turbo:load', function() {
    SavedSearches.init();
  });

  // Expose to window for debugging
  window.SavedSearches = SavedSearches;

})(jQuery);
