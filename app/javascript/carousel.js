// app/javascript/carousel.js
// Reusable image carousel component

export function initializeCarousels() {
  const carousels = {};

  // Initialize all carousels on the page
  document.querySelectorAll('[data-carousel-id]').forEach(carouselContainer => {
    const carouselId = carouselContainer.dataset.carouselId;

    // Skip if already initialized
    if (carousels[carouselId]) return;

    const images = carouselContainer.querySelectorAll('.carousel-image');
    const dots = carouselContainer.querySelectorAll('.carousel-dot');

    if (images.length === 0) return;

    carousels[carouselId] = {
      currentIndex: 0,
      totalImages: images.length,
      images: images,
      dots: dots,
      container: carouselContainer
    };
  });

  // Show specific image in a carousel
  function showImage(carouselId, index) {
    const carousel = carousels[carouselId];
    if (!carousel) return;

    // Wrap around
    if (index < 0) {
      index = carousel.totalImages - 1;
    } else if (index >= carousel.totalImages) {
      index = 0;
    }

    // Hide all images and show the selected one
    carousel.images.forEach((img, i) => {
      if (i === index) {
        img.classList.remove('hidden');
      } else {
        img.classList.add('hidden');
      }
    });

    // Update dots
    carousel.dots.forEach((dot, i) => {
      if (i === index) {
        dot.classList.remove('bg-white/50');
        dot.classList.add('bg-white');
      } else {
        dot.classList.remove('bg-white');
        dot.classList.add('bg-white/50');
      }
    });

    carousel.currentIndex = index;
  }

  // Attach event listeners to navigation buttons
  document.querySelectorAll('.carousel-prev').forEach(btn => {
    // Remove old listeners by cloning (prevents duplicate handlers)
    const newBtn = btn.cloneNode(true);
    btn.parentNode.replaceChild(newBtn, btn);

    newBtn.addEventListener('click', function(e) {
      e.preventDefault();
      const carouselId = this.dataset.carouselId;
      const carousel = carousels[carouselId];
      if (carousel) {
        showImage(carouselId, carousel.currentIndex - 1);
      }
    });
  });

  document.querySelectorAll('.carousel-next').forEach(btn => {
    // Remove old listeners by cloning (prevents duplicate handlers)
    const newBtn = btn.cloneNode(true);
    btn.parentNode.replaceChild(newBtn, btn);

    newBtn.addEventListener('click', function(e) {
      e.preventDefault();
      const carouselId = this.dataset.carouselId;
      const carousel = carousels[carouselId];
      if (carousel) {
        showImage(carouselId, carousel.currentIndex + 1);
      }
    });
  });

  return carousels;
}

// Auto-initialize on DOM ready
document.addEventListener('DOMContentLoaded', initializeCarousels);

// Reinitialize on Turbo page loads (for Turbo Drive navigation)
document.addEventListener('turbo:load', initializeCarousels);

// Also support direct calls for manual initialization
window.initializeCarousels = initializeCarousels;
