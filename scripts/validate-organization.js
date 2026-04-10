#!/usr/bin/env node

/**
 * Documentation Organization Validator
 * Validates logical organization, naming conventions, and separation of concerns
 */

import fs from "fs";
import path from "path";

class OrganizationValidator {
  constructor() {
    this.rootDir = process.cwd();
    this.organizationIssues = [];
    this.namingIssues = [];
    this.separationIssues = [];

    // Expected directory structure
    this.expectedStructure = {
      "docs/": {
        "ARCHITECTURE/": "System design and architecture documentation",
        "DEPLOYMENT/": "Deployment guides and workflows",
        "DEVELOPMENT/": "Developer guides and onboarding",
        "INSTALLATION/": "Platform-specific installation guides",
        "OPERATIONS/": "Operations and infrastructure guides",
        "USER_DOCUMENTATION/": "End-user guides and tutorials",
        "RELEASE/": "Release notes and changelogs",
        "TESTING/": "Testing guides and strategies",
        "SECURITY/": "Security documentation",
        "VERSIONING/": "Version management documentation",
      },
    };
  }

  // Check directory structure
  validateDirectoryStructure() {
    console.log("📁 Validating directory structure...");

    const docsPath = path.join(this.rootDir, "docs");
    if (!fs.existsSync(docsPath)) {
      this.organizationIssues.push({
        type: "missing_directory",
        severity: "high",
        message: "docs/ directory is missing",
        path: "docs/",
      });
      return;
    }

    // Check for expected subdirectories
    for (const [dirName, description] of Object.entries(
      this.expectedStructure["docs/"],
    )) {
      const dirPath = path.join(docsPath, dirName);
      if (!fs.existsSync(dirPath)) {
        this.organizationIssues.push({
          type: "missing_expected_directory",
          severity: "medium",
          message: `Expected directory missing: ${dirName} (${description})`,
          path: `docs/${dirName}`,
        });
      }
    }

    // Check for unexpected directories in docs/
    const actualDirs = fs
      .readdirSync(docsPath, { withFileTypes: true })
      .filter((dirent) => dirent.isDirectory())
      .map((dirent) => dirent.name + "/");

    const expectedDirs = Object.keys(this.expectedStructure["docs/"]);
    const unexpectedDirs = actualDirs.filter(
      (dir) => !expectedDirs.includes(dir) && !dir.startsWith("."),
    );

    for (const dir of unexpectedDirs) {
      this.organizationIssues.push({
        type: "unexpected_directory",
        severity: "low",
        message: `Unexpected directory in docs/: ${dir}`,
        path: `docs/${dir}`,
      });
    }
  }

  // Check root directory cleanliness
  validateRootDirectory() {
    console.log("🏠 Validating root directory cleanliness...");

    const rootItems = fs.readdirSync(this.rootDir, { withFileTypes: true });

    // Essential files that should be in root
    const essentialFiles = [
      "README.md",
      "LICENSE",
      "SECURITY.md",
      "pubspec.yaml",
      "package.json",
      ".gitignore",
      ".gitattributes",
    ];

    // Essential directories that should be in root
    const essentialDirs = [
      "lib",
      "services",
      "scripts",
      "docs",
      "test",
      "k8s",
      "config",
      "web",
      "windows",
      "linux",
      "android",
    ];

    // Check for non-essential files in root
    const rootFiles = rootItems
      .filter((item) => item.isFile())
      .map((item) => item.name);

    const nonEssentialFiles = rootFiles.filter(
      (file) =>
        !essentialFiles.includes(file) &&
        !file.startsWith(".") &&
        !file.endsWith(".yaml") &&
        !file.endsWith(".yml") &&
        !file.endsWith(".json") &&
        !file.endsWith(".md"),
    );

    for (const file of nonEssentialFiles) {
      this.organizationIssues.push({
        type: "non_essential_root_file",
        severity: "medium",
        message: `Non-essential file in root: ${file}`,
        path: file,
      });
    }
  }

  // Check naming conventions
  validateNamingConventions() {
    console.log("📝 Validating naming conventions...");

    this.checkNamingInDirectory("docs");
  }

  checkNamingInDirectory(dirPath, relativePath = "") {
    const fullPath = path.join(this.rootDir, dirPath);

    if (!fs.existsSync(fullPath)) return;

    const items = fs.readdirSync(fullPath, { withFileTypes: true });

    for (const item of items) {
      const itemPath = path.join(relativePath, item.name);

      if (item.isDirectory()) {
        // Check directory naming
        if (item.name.includes(" ")) {
          this.namingIssues.push({
            type: "directory_spaces",
            severity: "medium",
            message: `Directory name contains spaces: ${item.name}`,
            path: itemPath,
          });
        }

        // Recursively check subdirectories
        this.checkNamingInDirectory(path.join(dirPath, item.name), itemPath);
      } else if (item.name.endsWith(".md")) {
        // Check markdown file naming
        if (item.name.includes(" ")) {
          this.namingIssues.push({
            type: "file_spaces",
            severity: "medium",
            message: `File name contains spaces: ${item.name}`,
            path: itemPath,
          });
        }

        // Check for inconsistent casing
        if (
          item.name !== item.name.toUpperCase() &&
          item.name !== item.name.toLowerCase() &&
          !this.isConsistentCasing(item.name)
        ) {
          this.namingIssues.push({
            type: "inconsistent_casing",
            severity: "low",
            message: `Inconsistent casing in file name: ${item.name}`,
            path: itemPath,
          });
        }
      }
    }
  }

  isConsistentCasing(filename) {
    // Check if filename follows consistent patterns like:
    // - ALL_CAPS_WITH_UNDERSCORES.md
    // - kebab-case.md
    // - PascalCase.md
    const patterns = [
      /^[A-Z][A-Z0-9_]*\.md$/, // ALL_CAPS_WITH_UNDERSCORES
      /^[a-z][a-z0-9-]*\.md$/, // kebab-case
      /^[A-Z][a-zA-Z0-9]*\.md$/, // PascalCase
    ];

    return patterns.some((pattern) => pattern.test(filename));
  }

  // Check separation of concerns
  validateSeparationOfConcerns() {
    console.log("🎯 Validating separation of concerns...");

    // Check if user docs are mixed with developer docs
    this.checkDocumentSeparation();
  }

  checkDocumentSeparation() {
    const docTypes = {
      user: ["USER_DOCUMENTATION", "INSTALLATION"],
      developer: ["DEVELOPMENT", "ARCHITECTURE", "TESTING"],
      operations: ["DEPLOYMENT", "OPERATIONS", "SECURITY"],
    };

    // Check for misplaced files
    for (const [type, directories] of Object.entries(docTypes)) {
      for (const dir of directories) {
        const dirPath = path.join(this.rootDir, "docs", dir);
        if (fs.existsSync(dirPath)) {
          this.checkForMisplacedFiles(dirPath, type, dir);
        }
      }
    }
  }

  checkForMisplacedFiles(dirPath, expectedType, dirName) {
    const files = fs
      .readdirSync(dirPath, { withFileTypes: true })
      .filter((item) => item.isFile() && item.name.endsWith(".md"))
      .map((item) => item.name);

    // Patterns that indicate wrong placement
    const patterns = {
      user: {
        wrongPatterns: ["DEVELOPMENT", "ARCHITECTURE", "DEPLOYMENT", "API"],
        rightPatterns: ["USER", "GUIDE", "SETUP", "INSTALL"],
      },
      developer: {
        wrongPatterns: ["USER_GUIDE", "INSTALLATION"],
        rightPatterns: ["DEVELOPMENT", "API", "ARCHITECTURE", "BUILD"],
      },
      operations: {
        wrongPatterns: ["USER_GUIDE", "DEVELOPMENT"],
        rightPatterns: ["DEPLOYMENT", "OPERATIONS", "SECURITY", "MONITORING"],
      },
    };

    const typePatterns = patterns[expectedType];
    if (!typePatterns) return;

    for (const file of files) {
      const upperFile = file.toUpperCase();

      // Check for wrong patterns
      for (const wrongPattern of typePatterns.wrongPatterns) {
        if (upperFile.includes(wrongPattern)) {
          this.separationIssues.push({
            type: "misplaced_document",
            severity: "medium",
            message: `File may be misplaced: ${file} contains ${wrongPattern} but is in ${dirName}/`,
            path: `docs/${dirName}/${file}`,
          });
        }
      }
    }
  }

  // Check for consistent formatting
  validateFormatting() {
    console.log("📄 Validating formatting consistency...");

    // This would check for consistent markdown formatting
    // For now, we'll do a basic check
    this.checkBasicFormatting();
  }

  checkBasicFormatting() {
    const docsPath = path.join(this.rootDir, "docs");
    if (!fs.existsSync(docsPath)) return;

    // Check README files for consistent structure
    this.checkReadmeFiles(docsPath);
  }

  checkReadmeFiles(dirPath, relativePath = "") {
    const items = fs.readdirSync(dirPath, { withFileTypes: true });

    for (const item of items) {
      if (item.isDirectory()) {
        this.checkReadmeFiles(
          path.join(dirPath, item.name),
          path.join(relativePath, item.name),
        );
      } else if (item.name === "README.md") {
        const filePath = path.join(dirPath, item.name);
        const content = fs.readFileSync(filePath, "utf8");

        // Check for basic structure
        if (!content.includes("#")) {
          this.organizationIssues.push({
            type: "missing_headers",
            severity: "low",
            message: `README.md missing headers: ${relativePath}/README.md`,
            path: path.join(relativePath, "README.md"),
          });
        }
      }
    }
  }

  // Run all validations
  validate() {
    console.log("🔍 Starting documentation organization validation...");

    this.validateDirectoryStructure();
    this.validateRootDirectory();
    this.validateNamingConventions();
    this.validateSeparationOfConcerns();
    this.validateFormatting();

    return this.generateReport();
  }

  generateReport() {
    const allIssues = [
      ...this.organizationIssues,
      ...this.namingIssues,
      ...this.separationIssues,
    ];

    console.log("\n📊 Organization Validation Report");
    console.log("=================================");
    console.log(`Total issues found: ${allIssues.length}`);
    console.log(`Organization issues: ${this.organizationIssues.length}`);
    console.log(`Naming issues: ${this.namingIssues.length}`);
    console.log(`Separation issues: ${this.separationIssues.length}`);

    // Group by severity
    const issuesBySeverity = {
      high: allIssues.filter((i) => i.severity === "high"),
      medium: allIssues.filter((i) => i.severity === "medium"),
      low: allIssues.filter((i) => i.severity === "low"),
    };

    for (const [severity, issues] of Object.entries(issuesBySeverity)) {
      if (issues.length > 0) {
        console.log(
          `\n${severity.toUpperCase()} Priority Issues (${issues.length}):`,
        );
        console.log("=".repeat(30));

        for (const issue of issues) {
          console.log(`\n📁 ${issue.path}`);
          console.log(`   Type: ${issue.type}`);
          console.log(`   Issue: ${issue.message}`);
        }
      }
    }

    if (allIssues.length === 0) {
      console.log("\n✅ Documentation organization looks good!");
    }

    return {
      totalIssues: allIssues.length,
      organizationIssues: this.organizationIssues.length,
      namingIssues: this.namingIssues.length,
      separationIssues: this.separationIssues.length,
      issuesBySeverity,
      details: allIssues,
    };
  }
}

// Run validation
const validator = new OrganizationValidator();
const report = validator.validate();

console.log(
  `\n📋 Validation complete: ${report.totalIssues} organizational issues found`,
);
process.exit(0);
