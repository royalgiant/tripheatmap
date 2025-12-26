// app/javascript/carousel.js
// Simple, reliable carousel for image galleries with lightbox

// Create lightbox modal (once)
let lightbox = null;
let lightboxImg = null;
let lightboxImages = [];
let lightboxIndex = 0;

function createLightbox() {
  if (lightbox) return;

  lightbox = document.createElement('div');
  lightbox.innerHTML = `
    <div style="position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.95); z-index: 9999; display: none; align-items: center; justify-content: center;" id="lightbox-modal">
      <button onclick="closeLightbox()" style="position: absolute; top: 20px; right: 20px; background: white; border: none; border-radius: 50%; width: 40px; height: 40px; cursor: pointer; font-size: 24px; line-height: 1;">&times;</button>
      <button onclick="lightboxPrev()" style="position: absolute; left: 20px; top: 50%; transform: translateY(-50%); background: rgba(255,255,255,0.9); border: none; border-radius: 50%; width: 50px; height: 50px; cursor: pointer; font-size: 24px;">&#8249;</button>
      <img id="lightbox-image" style="max-width: 90%; max-height: 90%; object-fit: contain;">
      <button onclick="lightboxNext()" style="position: absolute; right: 20px; top: 50%; transform: translateY(-50%); background: rgba(255,255,255,0.9); border: none; border-radius: 50%; width: 50px; height: 50px; cursor: pointer; font-size: 24px;">&#8250;</button>
      <div style="position: absolute; bottom: 20px; color: white; font-size: 16px;" id="lightbox-counter"></div>
    </div>
  `;
  document.body.appendChild(lightbox);

  const modal = document.getElementById('lightbox-modal');
  lightboxImg = document.getElementById('lightbox-image');

  modal.onclick = (e) => { if (e.target === modal) closeLightbox(); };
  document.addEventListener('keydown', (e) => {
    if (!modal.style.display || modal.style.display === 'none') return;
    if (e.key === 'Escape') closeLightbox();
    if (e.key === 'ArrowLeft') lightboxPrev();
    if (e.key === 'ArrowRight') lightboxNext();
  });
}

window.openLightbox = function(images, index) {
  createLightbox();
  lightboxImages = images;
  lightboxIndex = index;
  updateLightbox();
  document.getElementById('lightbox-modal').style.display = 'flex';
};

window.closeLightbox = function() {
  document.getElementById('lightbox-modal').style.display = 'none';
};

window.lightboxPrev = function() {
  lightboxIndex = lightboxIndex === 0 ? lightboxImages.length - 1 : lightboxIndex - 1;
  updateLightbox();
};

window.lightboxNext = function() {
  lightboxIndex = lightboxIndex === lightboxImages.length - 1 ? 0 : lightboxIndex + 1;
  updateLightbox();
};

function updateLightbox() {
  lightboxImg.src = lightboxImages[lightboxIndex];
  document.getElementById('lightbox-counter').textContent = `${lightboxIndex + 1} / ${lightboxImages.length}`;
}

function setupCarousels() {
  const carousels = document.querySelectorAll('[data-carousel-id]');

  carousels.forEach(container => {
    const carouselId = container.dataset.carouselId;
    if (container.dataset.carouselInitialized === 'true') return;
    container.dataset.carouselInitialized = 'true';

    const images = container.querySelectorAll('.carousel-image');
    const dots = container.querySelectorAll('.carousel-dot');
    const prevBtn = document.querySelector(`.carousel-prev[data-carousel-id="${carouselId}"]`);
    const nextBtn = document.querySelector(`.carousel-next[data-carousel-id="${carouselId}"]`);

    if (images.length === 0) return;

    let currentIndex = 0;
    const imageSrcs = Array.from(images).map(img => img.src);

    function updateCarousel() {
      images.forEach((img, idx) => {
        if (idx === currentIndex) {
          img.classList.remove('hidden');
        } else {
          img.classList.add('hidden');
        }
      });

      dots.forEach((dot, idx) => {
        if (idx === currentIndex) {
          dot.classList.remove('bg-white/50');
          dot.classList.add('bg-white');
        } else {
          dot.classList.remove('bg-white');
          dot.classList.add('bg-white/50');
        }
      });
    }

    function goToPrev() {
      currentIndex = currentIndex === 0 ? images.length - 1 : currentIndex - 1;
      updateCarousel();
    }

    function goToNext() {
      currentIndex = currentIndex === images.length - 1 ? 0 : currentIndex + 1;
      updateCarousel();
    }

    images.forEach((img, idx) => {
      img.style.cursor = 'pointer';
      img.onclick = () => openLightbox(imageSrcs, idx);
    });

    if (prevBtn) {
      prevBtn.onclick = function(e) {
        e.preventDefault();
        goToPrev();
      };
    }

    if (nextBtn) {
      nextBtn.onclick = function(e) {
        e.preventDefault();
        goToNext();
      };
    }

    updateCarousel();
  });
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', setupCarousels);

// Initialize on Turbo navigation
document.addEventListener('turbo:load', setupCarousels);

// Initialize when Turbo frames load (for lazy-loaded content)
document.addEventListener('turbo:frame-load', setupCarousels);

// Export for manual calls if needed
export function initializeCarousels() {
  setupCarousels();
}

window.initializeCarousels = initializeCarousels;
