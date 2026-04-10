#!/usr/bin/env node

/**
 * Documentation Link Validator
 * Scans all markdown files for internal links and validates they exist
 */

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

class LinkValidator {
  constructor() {
    this.brokenLinks = [];
    this.checkedFiles = new Set();
    this.allFiles = new Set();
    this.rootDir = process.cwd();
  }

  // Find all markdown files in the project
  findMarkdownFiles(dir = this.rootDir, relativePath = "") {
    const items = fs.readdirSync(dir);

    for (const item of items) {
      const fullPath = path.join(dir, item);
      const relativeItemPath = path.join(relativePath, item);

      // Skip certain directories
      if (this.shouldSkipDirectory(item)) {
        continue;
      }

      const stat = fs.statSync(fullPath);

      if (stat.isDirectory()) {
        this.findMarkdownFiles(fullPath, relativeItemPath);
      } else if (item.endsWith(".md")) {
        this.allFiles.add(relativeItemPath.replace(/\\/g, "/"));
      }
    }
  }

  shouldSkipDirectory(dirName) {
    const skipDirs = [
      "node_modules",
      ".git",
      ".dart_tool",
      "build",
      "dist",
      ".vscode",
      ".idea",
      "coverage",
      "logs",
      ".sentry-native",
    ];
    return skipDirs.includes(dirName) || dirName.startsWith(".");
  }

  // Extract internal links from markdown content
  extractInternalLinks(content, filePath) {
    const links = [];

    // Match markdown links [text](path) and [text](path#anchor)
    const markdownLinkRegex = /\[([^\]]*)\]\(([^)]+)\)/g;
    let match;

    while ((match = markdownLinkRegex.exec(content)) !== null) {
      const linkText = match[1];
      const linkPath = match[2];

      // Skip external links (http/https)
      if (linkPath.startsWith("http://") || linkPath.startsWith("https://")) {
        continue;
      }

      // Skip email links
      if (linkPath.startsWith("mailto:")) {
        continue;
      }

      links.push({
        text: linkText,
        path: linkPath,
        line: this.getLineNumber(content, match.index),
        sourceFile: filePath,
      });
    }

    return links;
  }

  getLineNumber(content, index) {
    return content.substring(0, index).split("\n").length;
  }

  // Resolve relative path from source file
  resolvePath(linkPath, sourceFile) {
    // Remove anchor if present
    const [pathPart] = linkPath.split("#");

    if (path.isAbsolute(pathPart)) {
      return pathPart.substring(1); // Remove leading slash
    }

    const sourceDir = path.dirname(sourceFile);
    const resolved = path.join(sourceDir, pathPart);
    return resolved.replace(/\\/g, "/");
  }

  // Check if a file exists
  fileExists(filePath) {
    try {
      const fullPath = path.join(this.rootDir, filePath);
      return fs.existsSync(fullPath);
    } catch (error) {
      return false;
    }
  }

  // Validate all links in a file
  validateFile(filePath) {
    if (this.checkedFiles.has(filePath)) {
      return;
    }

    this.checkedFiles.add(filePath);

    try {
      const fullPath = path.join(this.rootDir, filePath);
      const content = fs.readFileSync(fullPath, "utf8");
      const links = this.extractInternalLinks(content, filePath);

      for (const link of links) {
        const resolvedPath = this.resolvePath(link.path, filePath);

        // Check if target file exists
        if (!this.fileExists(resolvedPath)) {
          // Try with .md extension if not present
          const withMdExtension = resolvedPath.endsWith(".md")
            ? resolvedPath
            : resolvedPath + ".md";

          if (!this.fileExists(withMdExtension)) {
            this.brokenLinks.push({
              ...link,
              resolvedPath,
              reason: "File not found",
            });
          }
        }
      }
    } catch (error) {
      console.error(`Error reading file ${filePath}:`, error.message);
    }
  }

  // Run validation on all files
  validate() {
    console.log("🔍 Finding markdown files...");
    this.findMarkdownFiles();

    console.log(`📄 Found ${this.allFiles.size} markdown files`);
    console.log("🔗 Validating internal links...");

    for (const filePath of this.allFiles) {
      this.validateFile(filePath);
    }

    return this.generateReport();
  }

  generateReport() {
    const report = {
      totalFiles: this.allFiles.size,
      checkedFiles: this.checkedFiles.size,
      brokenLinks: this.brokenLinks.length,
      details: this.brokenLinks,
    };

    console.log("\n📊 Link Validation Report");
    console.log("========================");
    console.log(`Total markdown files: ${report.totalFiles}`);
    console.log(`Files checked: ${report.checkedFiles}`);
    console.log(`Broken links found: ${report.brokenLinks}`);

    if (this.brokenLinks.length > 0) {
      console.log("\n❌ Broken Links:");
      console.log("================");

      for (const link of this.brokenLinks) {
        console.log(`\n📁 ${link.sourceFile}:${link.line}`);
        console.log(`   Link: [${link.text}](${link.path})`);
        console.log(`   Resolved: ${link.resolvedPath}`);
        console.log(`   Reason: ${link.reason}`);
      }
    } else {
      console.log("\n✅ All internal links are valid!");
    }

    return report;
  }
}

// Run validation - always run when script is executed directly
console.log("Starting link validation...");
const validator = new LinkValidator();
const report = validator.validate();

// Exit with error code if broken links found
process.exit(report.brokenLinks > 0 ? 1 : 0);

export default LinkValidator;
