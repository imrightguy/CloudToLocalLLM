/**
 * Changelog Service
 *
 * Manages API changelog and release notes generation from git commits
 * and version tracking.
 *
 * Requirements: 12.10
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

class ChangelogService {
  constructor() {
    this.changelogPath = path.join(__dirname, '../../docs/CHANGELOG.md');
    this.packageJsonPath = path.join(__dirname, '../package.json');
  }

  /**
   * Parse changelog file and extract version entries
   * Returns array of changelog entries with version, date, and changes
   */
  parseChangelog() {
    try {
      if (!fs.existsSync(this.changelogPath)) {
        return [];
      }

      const content = fs.readFileSync(this.changelogPath, 'utf-8');
      const entries = [];
      const lines = content.split('\n');

      let currentVersion = null;
      let currentDate = null;
      let currentChanges = [];
      let inChanges = false;

      for (let i = 0; i < lines.length; i++) {
        const line = lines[i];

        // Match version header: ## [version] - date
        const versionMatch = line.match(/^##\s+\[([^\]]+)\]\s+-\s+(.+)$/);
        if (versionMatch) {
          // Save previous entry
          if (currentVersion) {
            entries.push({
              version: currentVersion,
              date: currentDate,
              changes: currentChanges.filter((c) => c.trim()),
            });
          }

          currentVersion = versionMatch[1];
          currentDate = versionMatch[2];
          currentChanges = [];
          inChanges = true;
          continue;
        }

        // Match section headers (Added, Changed, Deprecated, Removed, Fixed, Security)
        if (
          line.match(/^###\s+(Added|Changed|Deprecated|Removed|Fixed|Security)/)
        ) {
          inChanges = true;
          currentChanges.push(line);
          continue;
        }

        // Match bullet points
        if (inChanges && line.match(/^-\s+/)) {
          currentChanges.push(line);
          continue;
        }

        // Empty line or other content
        if (inChanges && line.trim() === '') {
          continue;
        }

        if (inChanges && !line.match(/^-\s+/) && !line.match(/^###/)) {
          inChanges = false;
        }
      }

      // Save last entry
      if (currentVersion) {
        entries.push({
          version: currentVersion,
          date: currentDate,
          changes: currentChanges.filter((c) => c.trim()),
        });
      }

      return entries;
    } catch (error) {
      throw new Error(`Failed to parse changelog: ${error.message}`);
    }
  }

  /**
   * Get latest version from changelog
   */
  getLatestVersion() {
    const entries = this.parseChangelog();
    if (entries.length === 0) {
      return null;
    }
    return entries[0];
  }

  /**
   * Get version by version number
   */
  getVersionByNumber(versionNumber) {
    const entries = this.parseChangelog();
    return entries.find((entry) => entry.version === versionNumber) || null;
  }

  /**
   * Get all versions with pagination
   */
  getAllVersions(limit = 10, offset = 0) {
    const entries = this.parseChangelog();
    return {
      total: entries.length,
      limit,
      offset,
      versions: entries.slice(offset, offset + limit),
    };
  }

  /**
   * Get current API version from package.json
   */
  getCurrentApiVersion() {
    try {
      const packageJson = JSON.parse(
        fs.readFileSync(this.packageJsonPath, 'utf-8'),
      );
      return packageJson.version;
    } catch (error) {
      throw new Error(`Failed to read package.json: ${error.message}`);
    }
  }

  /**
   * Format changelog entry for API response
   */
  formatChangelogEntry(entry) {
    return {
      version: entry.version,
      date: entry.date,
      changes: entry.changes,
      changeCount: entry.changes.filter((c) => c.match(/^-\s+/)).length,
    };
  }

  /**
   * Get release notes for a specific version
   */
  getReleaseNotes(versionNumber) {
    const entry = this.getVersionByNumber(versionNumber);
    if (!entry) {
      return null;
    }

    return {
      version: entry.version,
      date: entry.date,
      releaseNotes: entry.changes.join('\n'),
      formatted: this.formatChangelogEntry(entry),
    };
  }

  /**
   * Validate changelog format
   * Returns true if changelog is valid, false otherwise
   */
  validateChangelogFormat() {
    try {
      const entries = this.parseChangelog();

      // Check that we have entries
      if (entries.length === 0) {
        return false;
      }

      // Check that each entry has required fields
      for (const entry of entries) {
        if (!entry.version || !entry.date || !Array.isArray(entry.changes)) {
          return false;
        }

        // Version should match semantic versioning
        if (!entry.version.match(/^\d+\.\d+\.\d+/)) {
          return false;
        }

        // Date should be valid
        if (isNaN(Date.parse(entry.date))) {
          return false;
        }
      }

      return true;
    } catch {
      return false;
    }
  }

  /**
   * Get changelog statistics
   */
  getChangelogStats() {
    const entries = this.parseChangelog();

    return {
      totalVersions: entries.length,
      latestVersion: entries.length > 0 ? entries[0].version : null,
      oldestVersion:
        entries.length > 0 ? entries[entries.length - 1].version : null,
      totalChanges: entries.reduce((sum, entry) => {
        return sum + entry.changes.filter((c) => c.match(/^-\s+/)).length;
      }, 0),
      isValid: this.validateChangelogFormat(),
    };
  }
}

export default ChangelogService;
