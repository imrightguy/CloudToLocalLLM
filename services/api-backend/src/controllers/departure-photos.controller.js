const departurePhotosService = require('../services/departure-photos.service');
const { child } = require('../utils/logger');

const log = child({ controller: 'departure-photos' });

// GET /api/departure-photos
exports.list = async (req, res) => {
  try {
    const { photos, metadata } = await departurePhotosService.listPhotos(req.query);
    return res.json({ success: true, data: photos, metadata });
  } catch (error) {
    log.error('Error listing departure photos', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'DEPARTURE_PHOTOS_FETCH_FAILED' },
    });
  }
};

// POST /api/departure-photos
exports.create = async (req, res) => {
  try {
    const photo = await departurePhotosService.createPhoto(req.body);
    return res.status(201).json({ success: true, data: photo, message: 'Photo enregistrée' });
  } catch (error) {
    log.error('Error creating departure photo', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'DEPARTURE_PHOTO_CREATE_FAILED' },
    });
  }
};

// DELETE /api/departure-photos/:id
exports.remove = async (req, res) => {
  try {
    const photo = await departurePhotosService.deletePhoto(req.params.id);
    if (!photo) {
      return res.status(404).json({
        success: false,
        error: { message: 'Photo introuvable', code: 'DEPARTURE_PHOTO_NOT_FOUND' },
      });
    }
    return res.json({ success: true, data: photo, message: 'Photo supprimée' });
  } catch (error) {
    log.error('Error deleting departure photo', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'DEPARTURE_PHOTO_DELETE_FAILED' },
    });
  }
};
