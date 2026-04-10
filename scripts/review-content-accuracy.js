#!/usr/bin/env node

/**
 * Content Accuracy and Completeness Reviewer
 * Reviews documentation for accuracy, outdated information, and completeness
 */

import fs from "fs";
import path from "path";

class ContentReviewer {
  constructor() {
    this.rootDir = process.cwd();
    this.issues = [];
    this.checkedFiles = 0;
  }

  // Find all markdown files
  findMarkdownFiles(dir = this.rootDir, relativePath = "") {
    const files = [];
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
        files.push(...this.findMarkdownFiles(fullPath, relativeItemPath));
      } else if (item.endsWith(".md")) {
        files.push(relativeItemPath.replace(/\\/g, "/"));
      }
    }

    return files;
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

  // Check for outdated infrastructure references
  checkInfrastructureAccuracy(content, filePath) {
    const issues = [];

    // Check for Azure vs AWS confusion
    if (content.includes("Azure AKS") && content.includes("AWS EKS")) {
      issues.push({
        type: "infrastructure_confusion",
        severity: "high",
        message:
          "Document contains both Azure AKS and AWS EKS references - needs clarification",
        file: filePath,
      });
    }

    // Check for outdated Azure references that should be AWS
    const azurePatterns = [
      /Azure Container Registry/gi,
      /\.azurecr\.io/gi,
      /az aks/gi,
      /Azure Resource Group/gi,
    ];

    for (const pattern of azurePatterns) {
      if (pattern.test(content)) {
        issues.push({
          type: "outdated_azure_reference",
          severity: "medium",
          message: `Contains outdated Azure reference: ${pattern.source}`,
          file: filePath,
        });
      }
    }

    // Check for correct AWS infrastructure references
    const correctAWSPatterns = [
      "AWS EKS",
      "CloudFormation",
      "OIDC authentication",
      "us-east-1",
    ];

    let hasCorrectAWS = false;
    for (const pattern of correctAWSPatterns) {
      if (content.includes(pattern)) {
        hasCorrectAWS = true;
        break;
      }
    }

    // If file mentions deployment/infrastructure but doesn't have correct AWS refs
    if (
      (content.includes("deployment") || content.includes("infrastructure")) &&
      content.length > 1000 &&
      !hasCorrectAWS
    ) {
      issues.push({
        type: "missing_aws_references",
        severity: "medium",
        message:
          "Infrastructure document may be missing current AWS EKS references",
        file: filePath,
      });
    }

    return issues;
  }

  // Check for version accuracy
  checkVersionAccuracy(content, filePath) {
    const issues = [];

    // Check for outdated version references
    const outdatedVersionPatterns = [
      /Flutter 2\./gi,
      /Dart 2\./gi,
      /Node\.js 14/gi,
      /Node\.js 16/gi,
      /Kubernetes 1\.2[0-4]/gi,
    ];

    for (const pattern of outdatedVersionPatterns) {
      if (pattern.test(content)) {
        issues.push({
          type: "outdated_version",
          severity: "medium",
          message: `Contains outdated version reference: ${pattern.source}`,
          file: filePath,
        });
      }
    }

    // Check for current version references
    const currentVersions = [
      "Flutter 3.5+",
      "Dart 3.5.0+",
      "Node.js",
      "Kubernetes 1.30",
    ];

    return issues;
  }

  // Check for completeness of major components
  checkComponentCompleteness(content, filePath) {
    const issues = [];

    // Major components that should have documentation
    const majorComponents = [
      "Authentication",
      "WebSocket",
      "SSH Tunnel",
      "API Backend",
      "Streaming Proxy",
      "Database",
      "Deployment",
    ];

    // If this is a main documentation file, check for component coverage
    if (filePath.includes("README.md") || filePath.includes("OVERVIEW")) {
      const missingComponents = [];

      for (const component of majorComponents) {
        if (!content.toLowerCase().includes(component.toLowerCase())) {
          missingComponents.push(component);
        }
      }

      if (missingComponents.length > 0) {
        issues.push({
          type: "missing_component_documentation",
          severity: "low",
          message: `May be missing documentation for: ${missingComponents.join(", ")}`,
          file: filePath,
        });
      }
    }

    return issues;
  }

  // Check for contradictory information
  checkContradictions(content, filePath) {
    const issues = [];

    // Common contradictions to check for
    const contradictionChecks = [
      {
        patterns: [/Azure/gi, /AWS/gi],
        message:
          "Contains both Azure and AWS references - may be contradictory",
      },
      {
        patterns: [/port 3000/gi, /port 8080/gi],
        message: "Contains multiple port references - may be contradictory",
      },
      {
        patterns: [/SQLite/gi, /PostgreSQL/gi],
        message:
          "Contains both SQLite and PostgreSQL references - may need clarification",
      },
    ];

    for (const check of contradictionChecks) {
      let matchCount = 0;
      for (const pattern of check.patterns) {
        if (pattern.test(content)) {
          matchCount++;
        }
      }

      if (matchCount > 1) {
        issues.push({
          type: "potential_contradiction",
          severity: "medium",
          message: check.message,
          file: filePath,
        });
      }
    }

    return issues;
  }

  // Review a single file
  reviewFile(filePath) {
    try {
      const fullPath = path.join(this.rootDir, filePath);
      const content = fs.readFileSync(fullPath, "utf8");

      this.checkedFiles++;

      const fileIssues = [
        ...this.checkInfrastructureAccuracy(content, filePath),
        ...this.checkVersionAccuracy(content, filePath),
        ...this.checkComponentCompleteness(content, filePath),
        ...this.checkContradictions(content, filePath),
      ];

      this.issues.push(...fileIssues);
    } catch (error) {
      console.error(`Error reviewing file ${filePath}:`, error.message);
    }
  }

  // Run the review
  review() {
    console.log("🔍 Starting content accuracy and completeness review...");

    const files = this.findMarkdownFiles();
    console.log(`📄 Found ${files.length} markdown files`);

    for (const filePath of files) {
      this.reviewFile(filePath);
    }

    return this.generateReport();
  }

  generateReport() {
    console.log("\n📊 Content Review Report");
    console.log("========================");
    console.log(`Files reviewed: ${this.checkedFiles}`);
    console.log(`Issues found: ${this.issues.length}`);

    // Group issues by severity
    const issuesBySeverity = {
      high: this.issues.filter((i) => i.severity === "high"),
      medium: this.issues.filter((i) => i.severity === "medium"),
      low: this.issues.filter((i) => i.severity === "low"),
    };

    for (const [severity, issues] of Object.entries(issuesBySeverity)) {
      if (issues.length > 0) {
        console.log(
          `\n${severity.toUpperCase()} Priority Issues (${issues.length}):`,
        );
        console.log("=".repeat(30));

        for (const issue of issues) {
          console.log(`\n📁 ${issue.file}`);
          console.log(`   Type: ${issue.type}`);
          console.log(`   Issue: ${issue.message}`);
        }
      }
    }

    if (this.issues.length === 0) {
      console.log("\n✅ No content accuracy issues found!");
    }

    return {
      totalFiles: this.checkedFiles,
      totalIssues: this.issues.length,
      issuesBySeverity,
      details: this.issues,
    };
  }
}

// Run review
const reviewer = new ContentReviewer();
const report = reviewer.review();

console.log(
  `\n📋 Review complete: ${report.totalIssues} issues found in ${report.totalFiles} files`,
);
process.exit(0);
