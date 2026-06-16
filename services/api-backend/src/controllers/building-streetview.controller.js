const https = require('https');
const { db } = require('../database/connection');
const { buildingsTable } = require('../database/schema');
const { eq } = require('drizzle-orm');
const logger = require('../utils/logger');

const GOOGLE_API_KEY = process.env.GOOGLE_MAPS_API_KEY;
const STREETVIEW_URL = 'https://maps.googleapis.com/maps/api/streetview';
const METADATA_URL = 'https://maps.googleapis.com/maps/api/streetview/metadata';
const STATIC_MAP_URL = 'https://maps.googleapis.com/maps/api/staticmap';

// Simple in-memory cache (façades changent rarement)
const imageCache = new Map();
const CACHE_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 jours

function fetchUrl(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { timeout: 8000 }, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        // Follow redirect
        https.get(res.headers.location, { timeout: 8000 }, (redirectRes) => {
          const chunks = [];
          redirectRes.on('data', c => chunks.push(c));
          redirectRes.on('end', () => resolve(Buffer.concat(chunks)));
          redirectRes.on('error', reject);
        }).on('error', reject);
        return;
      }
      if (res.statusCode !== 200) {
        reject(new Error(`HTTP ${res.statusCode}`));
        return;
      }
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => resolve(Buffer.concat(chunks)));
      res.on('error', reject);
    }).on('error', reject);
  });
}

async function checkStreetViewAvailability(lat, lng) {
  const url = `${METADATA_URL}?location=${lat},${lng}&key=${GOOGLE_API_KEY}`;
  try {
    const data = await fetchUrl(url);
    const json = JSON.parse(data.toString());
    return json.status === 'OK';
  } catch {
    return false;
  }
}

async function getStreetViewImage(lat, lng) {
  const url = `${STREETVIEW_URL}?size=640x360&location=${lat},${lng}&key=${GOOGLE_API_KEY}&fov=80&pitch=0`;
  return fetchUrl(url);
}

async function getSatelliteImage(lat, lng) {
  const url = `${STATIC_MAP_URL}?center=${lat},${lng}&zoom=18&size=640x360&maptype=satellite&key=${GOOGLE_API_KEY}`;
  return fetchUrl(url);
}

// GET /api/buildings/:id/streetview
exports.getStreetView = async (req, res) => {
  const { id } = req.params;

  if (!GOOGLE_API_KEY) {
    return res.status(501).json({ error: 'Google Maps API key not configured' });
  }

  // Check cache
  const cached = imageCache.get(id);
  if (cached && Date.now() - cached.timestamp < CACHE_TTL_MS) {
    res.set('Content-Type', 'image/jpeg');
    res.set('Cache-Control', 'public, max-age=604800');
    res.set('X-Image-Source', cached.source);
    return res.send(cached.buffer);
  }

  // Fetch building coordinates
  const [building] = await db.select({
    properties: buildingsTable.properties,
  }).from(buildingsTable).where(eq(buildingsTable.id, id)).limit(1);

  if (!building) {
    return res.status(404).json({ error: 'Building not found' });
  }

  const props = building.properties || {};
  const lat = props.latitude;
  const lng = props.longitude;

  if (lat == null || lng == null) {
    return res.status(404).json({ error: 'No coordinates for this building' });
  }

  try {
    // Check Street View availability
    const hasStreetView = await checkStreetViewAvailability(lat, lng);
    
    let imageBuffer;
    let source;

    if (hasStreetView) {
      imageBuffer = await getStreetViewImage(lat, lng);
      source = 'streetview';
    } else {
      // Fallback to satellite
      imageBuffer = await getSatelliteImage(lat, lng);
      source = 'satellite';
    }

    // Cache
    imageCache.set(id, { buffer: imageBuffer, source, timestamp: Date.now() });

    res.set('Content-Type', 'image/jpeg');
    res.set('Cache-Control', 'public, max-age=604800');
    res.set('X-Image-Source', source);
    return res.send(imageBuffer);
  } catch (err) {
    logger.error('Street View fetch failed', { buildingId: id, error: err.message });
    return res.status(502).json({ error: 'Failed to fetch image from Google Maps' });
  }
};
