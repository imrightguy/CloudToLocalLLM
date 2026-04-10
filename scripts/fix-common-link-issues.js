#!/usr/bin/env node

/**
 * Fix Common Link Issues
 * Applies the most common link fixes to documentation files
 */

import fs from "fs";
import path from "path";

class CommonLinkFixer {
  constructor() {
    this.rootDir = process.cwd();
    this.fixedFiles = [];
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

  // Apply common fixes to a file
  fixFile(filePath) {
    try {
      const fullPath = path.join(this.rootDir, filePath);
      let content = fs.readFileSync(fullPath, "utf8");
      let modified = false;
      const appliedFixes = [];

      // Fix 1: Remove duplicate path segments
      const duplicatePathFixes = [
        {
          pattern: /services\/docs\/API\//g,
          replacement: "docs/API/",
          description: "Fix services/docs/API path to docs/API",
        },
        {
          pattern: /services\/\.kiro\/specs\//g,
          replacement: ".kiro/specs/",
          description: "Fix services/.kiro/specs path to .kiro/specs",
        },
        {
          pattern: /test\/integration\/\.kiro\/specs\//g,
          replacement: ".kiro/specs/",
          description: "Fix test/integration/.kiro/specs path to .kiro/specs",
        },
        {
          pattern: /lib\/services\/\.kiro\/specs\//g,
          replacement: ".kiro/specs/",
          description: "Fix lib/services/.kiro/specs path to .kiro/specs",
        },
        {
          pattern: /services\/streaming-proxy\/\.kiro\/specs\//g,
          replacement: ".kiro/specs/",
          description: "Fix streaming-proxy/.kiro/specs path to .kiro/specs",
        },
      ];

      for (const fix of duplicatePathFixes) {
        const originalContent = content;
        content = content.replace(fix.pattern, fix.replacement);

        if (content !== originalContent) {
          modified = true;
          appliedFixes.push(fix.description);
        }
      }

      // Fix 2: Replace non-existent Kubernetes files
      const kubernetesReplacements = [
        {
          pattern: /\]\(\.\.\/\.\.\/KUBERNETES_QUICKSTART\.md\)/g,
          replacement: "](../../k8s/README.md)",
          description: "Replace KUBERNETES_QUICKSTART.md with k8s/README.md",
        },
        {
          pattern: /\]\(\.\.\/KUBERNETES_QUICKSTART\.md\)/g,
          replacement: "](../k8s/README.md)",
          description: "Replace KUBERNETES_QUICKSTART.md with k8s/README.md",
        },
        {
          pattern: /\]\(KUBERNETES_QUICKSTART\.md\)/g,
          replacement: "](k8s/README.md)",
          description: "Replace KUBERNETES_QUICKSTART.md with k8s/README.md",
        },
      ];

      for (const fix of kubernetesReplacements) {
        const originalContent = content;
        content = content.replace(fix.pattern, fix.replacement);

        if (content !== originalContent) {
          modified = true;
          appliedFixes.push(fix.description);
        }
      }

      // Fix 3: Fix CONTRIBUTING.md references
      const contributingFixes = [
        {
          pattern: /\]\(CONTRIBUTING\.md\)/g,
          replacement: "](../../CONTRIBUTING.md)",
          description: "Fix CONTRIBUTING.md path",
        },
      ];

      for (const fix of contributingFixes) {
        const originalContent = content;
        content = content.replace(fix.pattern, fix.replacement);

        if (content !== originalContent) {
          modified = true;
          appliedFixes.push(fix.description);
        }
      }

      // Fix 4: Remove links to non-existent files
      const filesToRemove = [
        "ANDROID_BUILD_GUIDE.md",
        "CLOUDRUN_DEPLOYMENT.md",
        "SIMPLIFIED_TUNNEL_ARCHITECTURE.md",
        "VPS_DEPLOYMENT.md",
        "SECURITY_GUIDE.md",
        "TUNNEL_API.md",
        "AUTH_API.md",
        "WEB_API.md",
        "AKS_TROUBLESHOOTING.md",
        "DNS_CONFIGURATION.md",
        "MONITORING_SETUP.md",
        "BACKUP_STRATEGY.md",
        "SECURITY_BEST_PRACTICES.md",
        "PERFORMANCE_OPTIMIZATION.md",
        "PREREQUISITES.md",
        "FIRST_TIME_SETUP.md",
        "TROUBLESHOOTING.md",
      ];

      for (const fileName of filesToRemove) {
        const linkPattern = new RegExp(
          `\\[([^\\]]+)\\]\\([^)]*${fileName.replace(".", "\\.")}[^)]*\\)`,
          "g",
        );
        const originalContent = content;
        content = content.replace(linkPattern, "");

        if (content !== originalContent) {
          modified = true;
          appliedFixes.push(`Removed dead link to ${fileName}`);
        }
      }

      if (modified) {
        // Clean up any double newlines created by removing links
        content = content.replace(/\n\n\n+/g, "\n\n");
        fs.writeFileSync(fullPath, content, "utf8");
        this.fixedFiles.push({
          file: filePath,
          fixes: appliedFixes,
        });
        console.log(`✅ Fixed ${appliedFixes.length} issues in ${filePath}`);
      }

      return modified;
    } catch (error) {
      console.error(`❌ Error fixing file ${filePath}:`, error.message);
      return false;
    }
  }

  // Run the fixer
  fix() {
    console.log("🔧 Starting common link fixes...");

    const files = this.findMarkdownFiles();
    console.log(`📄 Found ${files.length} markdown files`);

    let totalFixed = 0;

    for (const filePath of files) {
      if (this.fixFile(filePath)) {
        totalFixed++;
      }
    }

    console.log("\n📊 Fix Summary");
    console.log("==============");
    console.log(`Files processed: ${files.length}`);
    console.log(`Files modified: ${totalFixed}`);

    if (this.fixedFiles.length > 0) {
      console.log("\n✅ Fixed Files:");
      for (const fix of this.fixedFiles) {
        console.log(`  ${fix.file}:`);
        for (const description of fix.fixes) {
          console.log(`    - ${description}`);
        }
      }
    }

    return totalFixed;
  }
}

// Run fixer
const fixer = new CommonLinkFixer();
const fixedCount = fixer.fix();

console.log(`\n🎉 Fixed ${fixedCount} files with common link issues!`);
process.exit(0);
