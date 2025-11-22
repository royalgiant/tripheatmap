// Central list of [longitude, latitude] map centers for supported cities.
// Used by places_map.js to initialize Mapbox views before neighborhood
// boundaries are loaded. Keep entries lowercase for consistent lookups.

const cityCoordinates = {
  // US Cities
  'new york': [-74.00, 40.71],
  'los angeles': [-118.24, 34.05],
  'chicago': [-87.65, 41.85],
  'houston': [-95.37, 29.76],
  'phoenix': [-112.07, 33.45],
  'philadelphia': [-75.16, 39.95],
  'san antonio': [-98.49, 29.42],
  'san diego': [-117.16, 32.72],
  'dallas': [-96.80, 32.78],
  'san jose': [-121.89, 37.34],
  'austin': [-97.74, 30.27],
  'jacksonville': [-81.66, 30.33],
  'fort worth': [-97.32, 32.75],
  'columbus': [-82.99, 39.96],
  'charlotte': [-80.84, 35.23],
  'san francisco': [-122.42, 37.77],
  'indianapolis': [-86.16, 39.77],
  'seattle': [-122.33, 47.61],
  'denver': [-104.99, 39.74],
  'washington': [-77.04, 38.91],
  'boston': [-71.06, 42.36],
  'nashville': [-86.78, 36.16],
  'detroit': [-83.05, 42.33],
  'oklahoma city': [-97.52, 35.47],
  'portland': [-122.68, 45.52],
  'las vegas': [-115.14, 36.17],
  'memphis': [-90.05, 35.15],
  'louisville': [-85.76, 38.25],
  'baltimore': [-76.61, 39.29],
  'milwaukee': [-87.91, 43.04],
  'albuquerque': [-106.65, 35.08],
  'tucson': [-110.93, 32.22],
  'fresno': [-119.77, 36.74],
  'sacramento': [-121.49, 38.58],
  'mesa': [-111.83, 33.42],
  'kansas city': [-94.58, 39.10],
  'atlanta': [-84.39, 33.75],
  'miami': [-80.19, 25.76],
  'colorado springs': [-104.82, 38.83],
  'raleigh': [-78.64, 35.77],
  'omaha': [-95.94, 41.26],
  'long beach': [-118.19, 33.77],
  'virginia beach': [-75.98, 36.85],
  'oakland': [-122.27, 37.80],
  'minneapolis': [-93.26, 44.98],
  'tulsa': [-95.99, 36.15],
  'tampa': [-82.46, 27.95],
  'arlington': [-97.11, 32.74],
  'new orleans': [-90.07, 29.95],
  'wichita': [-97.34, 37.69],
  'cleveland': [-81.69, 41.50],
  'bakersfield': [-119.02, 35.37],
  'aurora': [-104.83, 39.73],
  'anaheim': [-117.91, 33.84],
  'honolulu': [-157.86, 21.31],
  'henderson': [-115.04, 36.04],
  'stockton': [-121.29, 37.96],
  'lexington': [-84.50, 38.04],
  'corpus christi': [-97.40, 27.80],
  'riverside': [-117.40, 33.95],
  'santa ana': [-117.87, 33.75],
  'irvine': [-117.82, 33.68],
  'cincinnati': [-84.51, 39.10],
  'newark': [-74.17, 40.74],
  'st paul': [-93.09, 44.95],
  'pittsburgh': [-79.99, 40.44],
  'greensboro': [-79.79, 36.07],
  'lincoln': [-96.68, 40.81],
  'orlando': [-81.38, 28.54],
  'plano': [-96.70, 33.02],
  'jersey city': [-74.08, 40.72],
  'durham': [-78.90, 35.99],
  'gilbert': [-111.79, 33.35],
  'north las vegas': [-115.12, 36.20],
  'el paso': [-106.49, 31.76],
  // Newer US additions
  'charleston': [-79.93, 32.78],
  'savannah': [-81.10, 32.08],
  'sedona': [-111.76, 34.87],
  'aspen': [-106.82, 39.19],
  'scottsdale': [-111.93, 33.49],
  'salt lake city': [-111.89, 40.76],
  'santa fe': [-105.94, 35.69],
  'st louis': [-90.20, 38.63],
  'anchorage': [-149.90, 61.22],
  'boulder': [-105.27, 40.01],
  'napa': [-122.29, 38.30],
  'calistoga': [-122.58, 38.58],

  // Latin America / existing intl
  'buenos aires': [-58.38, -34.60],
  'marciaga': [10.73, 45.59],
  'costermano sul garda': [10.72, 45.60],
  'verona': [10.99, 45.44],

  // United Kingdom
  'london': [-0.1276, 51.5072],
  'birmingham': [-1.8904, 52.4862],
  'manchester': [-2.2426, 53.4808],
  'liverpool': [-2.9810, 53.4084],
  'leeds': [-1.5491, 53.8008],
  'sheffield': [-1.4701, 53.3811],
  'bristol': [-2.5879, 51.4545],
  'glasgow': [-4.2518, 55.8642],
  'edinburgh': [-3.1883, 55.9533],
  'cardiff': [-3.1791, 51.4816],

  // Australia & New Zealand
  'sydney': [151.2093, -33.8688],
  'melbourne': [144.9631, -37.8136],
  'brisbane': [153.0251, -27.4698],
  'perth': [115.8605, -31.9505],
  'adelaide': [138.6007, -34.9285],
  'auckland': [174.7633, -36.8485],
  'wellington': [174.7772, -41.2865],
  'christchurch': [172.6362, -43.5321],

  // Canada
  'toronto': [-79.3832, 43.6532],
  'vancouver': [-123.1207, 49.2827],
  'montreal': [-73.5673, 45.5017],
  'calgary': [-114.0719, 51.0447],
  'ottawa': [-75.6972, 45.4215],
  'edmonton': [-113.4909, 53.5461],

  // Asia / Middle East
  'singapore': [103.8198, 1.3521],
  'dubai': [55.2708, 25.2048],

  // Germany
  'berlin': [13.4050, 52.5200],
  'munich': [11.5820, 48.1351],
  'hamburg': [9.9937, 53.5511],
  'frankfurt': [8.6821, 50.1109],
  'cologne': [6.9603, 50.9375],
  'stuttgart': [9.1829, 48.7758],
  'dusseldorf': [6.7735, 51.2277],

  // Netherlands
  'amsterdam': [4.9041, 52.3676],
  'rotterdam': [4.4792, 51.9244],
  'the hague': [4.3000, 52.0705],
  'utrecht': [5.1214, 52.0907],
  'eindhoven': [5.4797, 51.4416],

  // Switzerland
  'zurich': [8.5417, 47.3769],
  'geneva': [6.1432, 46.2044],
  'basel': [7.5886, 47.5596],
  'lausanne': [6.6323, 46.5197],
  'bern': [7.4474, 46.9480],

  // Sweden
  'stockholm': [18.0686, 59.3293],
  'gothenburg': [11.9746, 57.7089],
  'malmo': [12.5683, 55.6049],
  'uppsala': [17.6389, 59.8586],

  // Denmark
  'copenhagen': [12.5683, 55.6761],
  'aarhus': [10.2039, 56.1629],
  'odense': [10.3883, 55.4038],
  'aalborg': [9.9217, 57.0488],

  // Belgium
  'brussels': [4.3517, 50.8503],
  'antwerp': [4.4025, 51.2194],
  'ghent': [3.7210, 51.0543],
  'charleroi': [4.4445, 50.4114],
  'liege': [5.5797, 50.6326],

  // France
  'paris': [2.3522, 48.8566],
  'lyon': [4.8357, 45.7640],
  'marseille': [5.3698, 43.2965],
  'nice': [7.2619, 43.7102],
  'toulouse': [1.4442, 43.6047],
  'lille': [3.0573, 50.6292],

  // Austria
  'vienna': [16.3738, 48.2082],
  'salzburg': [13.0470, 47.8095],
  'graz': [15.4395, 47.0707],
  'linz': [14.2858, 48.3069],

  // Norway
  'oslo': [10.7522, 59.9139],
  'bergen': [5.3221, 60.3920],
  'trondheim': [10.3951, 63.4305],
  'stavanger': [5.7331, 58.9690],

  // Japan
  'tokyo': [139.6917, 35.6895],
  'osaka': [135.5022, 34.6937],
  'kyoto': [135.7681, 35.0116],
  'yokohama': [139.6380, 35.4437],

  // Spain
  'madrid': [-3.7038, 40.4168],
  'barcelona': [2.1734, 41.3851],
  'valencia': [-0.3763, 39.4699],
  'seville': [-5.9845, 37.3891],

  // Italy
  'rome': [12.4964, 41.9028],
  'milan': [9.1900, 45.4642],
  'naples': [14.2681, 40.8518],
  'venice': [12.3155, 45.4408],

  // Portugal
  'lisbon': [-9.1393, 38.7223],
  'porto': [-8.6291, 41.1579],

  // Greece
  'athens': [23.7275, 37.9838],
  'thessaloniki': [22.9444, 40.6401],

  // Thailand
  'bangkok': [100.5018, 13.7563],
  'chiang mai': [98.9665, 18.7883],
  'phuket': [98.3923, 7.8804],

  // Vietnam
  'ho chi minh city': [106.6297, 10.8231],
  'hanoi': [105.8342, 21.0278],
  'da nang': [108.2208, 16.0678],

  // Mexico
  'mexico city': [-99.1332, 19.4326],
  'guadalajara': [-103.3496, 20.6597],
  'monterrey': [-100.3161, 25.6866],
  'cancun': [-86.8515, 21.1619],

  // Brazil
  'sao paulo': [-46.6333, -23.5505],
  'rio de janeiro': [-43.1729, -22.9068],
  'salvador': [-38.5014, -12.9730],
  'brasilia': [-47.8825, -15.7939]
};

export default cityCoordinates;
