/**
 * Changelog Routes
 *
 * Provides API endpoints for accessing changelog and release notes
 *
 * Requirements: 12.10
 */

import express from 'express';
import ChangelogService from '../services/changelog-service.js';

const router = express.Router();
const changelogService = new ChangelogService();

/**
 * @swagger
 * /changelog:
 *   get:
 *     summary: Get changelog with pagination
 *     description: Retrieve paginated changelog entries with version history
 *     tags:
 *       - Documentation
 *     parameters:
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 10
 *         description: Number of versions to return
 *       - in: query
 *         name: offset
 *         schema:
 *           type: integer
 *           default: 0
 *         description: Number of versions to skip
 *     responses:
 *       200:
 *         description: Changelog entries retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 total:
 *                   type: integer
 *                   description: Total number of versions
 *                 limit:
 *                   type: integer
 *                   description: Limit used in query
 *                 offset:
 *                   type: integer
 *                   description: Offset used in query
 *                 versions:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       version:
 *                         type: string
 *                         description: Version number (semantic versioning)
 *                       date:
 *                         type: string
 *                         description: Release date
 *                       changes:
 *                         type: array
 *                         items:
 *                           type: string
 *                         description: List of changes
 *                       changeCount:
 *                         type: integer
 *                         description: Number of changes in this version
 *       400:
 *         description: Invalid query parameters
 *       500:
 *         description: Failed to retrieve changelog
 */
router.get('/', (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 10, 100);
    const offset = Math.max(parseInt(req.query.offset) || 0, 0);

    if (limit < 1 || limit > 100) {
      return res.status(400).json({
        error: 'Invalid limit parameter. Must be between 1 and 100.',
      });
    }

    if (offset < 0) {
      return res.status(400).json({
        error: 'Invalid offset parameter. Must be >= 0.',
      });
    }

    const result = changelogService.getAllVersions(limit, offset);

    // Format entries
    result.versions = result.versions.map((entry) =>
      changelogService.formatChangelogEntry(entry),
    );

    res.json(result);
  } catch (error) {
    res.status(500).json({
      error: 'Failed to retrieve changelog',
      message: error.message,
    });
  }
});

/**
 * @swagger
 * /changelog/latest:
 *   get:
 *     summary: Get latest version
 *     description: Retrieve the latest version from changelog
 *     tags:
 *       - Documentation
 *     responses:
 *       200:
 *         description: Latest version retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 version:
 *                   type: string
 *                   description: Version number
 *                 date:
 *                   type: string
 *                   description: Release date
 *                 changes:
 *                   type: array
 *                   items:
 *                     type: string
 *                   description: List of changes
 *                 changeCount:
 *                   type: integer
 *                   description: Number of changes
 *       404:
 *         description: No changelog entries found
 *       500:
 *         description: Failed to retrieve latest version
 */
router.get('/latest', (req, res) => {
  try {
    const latest = changelogService.getLatestVersion();

    if (!latest) {
      return res.status(404).json({
        error: 'No changelog entries found',
      });
    }

    res.json(changelogService.formatChangelogEntry(latest));
  } catch (error) {
    res.status(500).json({
      error: 'Failed to retrieve latest version',
      message: error.message,
    });
  }
});

/**
 * @swagger
 * /changelog/{version}:
 *   get:
 *     summary: Get release notes for specific version
 *     description: Retrieve detailed release notes for a specific API version
 *     tags:
 *       - Documentation
 *     parameters:
 *       - in: path
 *         name: version
 *         required: true
 *         schema:
 *           type: string
 *         description: Version number (e.g., 2.0.0)
 *     responses:
 *       200:
 *         description: Release notes retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 version:
 *                   type: string
 *                   description: Version number
 *                 date:
 *                   type: string
 *                   description: Release date
 *                 releaseNotes:
 *                   type: string
 *                   description: Full release notes text
 *                 formatted:
 *                   type: object
 *                   description: Formatted changelog entry
 *       404:
 *         description: Version not found
 *       500:
 *         description: Failed to retrieve release notes
 */
router.get('/:version', (req, res) => {
  try {
    const { version } = req.params;

    // Validate version format
    if (!version.match(/^\d+\.\d+\.\d+/)) {
      return res.status(400).json({
        error:
          'Invalid version format. Expected semantic versioning (e.g., 2.0.0)',
      });
    }

    const releaseNotes = changelogService.getReleaseNotes(version);

    if (!releaseNotes) {
      return res.status(404).json({
        error: `Release notes not found for version ${version}`,
      });
    }

    res.json(releaseNotes);
  } catch (error) {
    res.status(500).json({
      error: 'Failed to retrieve release notes',
      message: error.message,
    });
  }
});

/**
 * @swagger
 * /changelog/stats:
 *   get:
 *     summary: Get changelog statistics
 *     description: Retrieve statistics about the changelog
 *     tags:
 *       - Documentation
 *     responses:
 *       200:
 *         description: Changelog statistics retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 totalVersions:
 *                   type: integer
 *                   description: Total number of versions
 *                 latestVersion:
 *                   type: string
 *                   description: Latest version number
 *                 oldestVersion:
 *                   type: string
 *                   description: Oldest version number
 *                 totalChanges:
 *                   type: integer
 *                   description: Total number of changes across all versions
 *                 isValid:
 *                   type: boolean
 *                   description: Whether changelog format is valid
 *       500:
 *         description: Failed to retrieve statistics
 */
router.get('/stats', (req, res) => {
  try {
    const stats = changelogService.getChangelogStats();
    res.json(stats);
  } catch (error) {
    res.status(500).json({
      error: 'Failed to retrieve changelog statistics',
      message: error.message,
    });
  }
});

export default router;
