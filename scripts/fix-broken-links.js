#!/usr/bin/env node

/**
 * Broken Link Fixer
 * Automatically fixes common broken link patterns in documentation
 */

import fs from "fs";
import path from "path";
import LinkValidator from "./validate-internal-links.js";

class LinkFixer {
  constructor() {
    this.rootDir = process.cwd();
    this.fixedLinks = [];
    this.unfixableLinks = [];
  }

  // Common link fixes
  getCommonFixes() {
    return [
      // Remove incorrect relative paths
      {
        pattern: /docs\/DEVELOPMENT\/docs\/DEVELOPMENT\//g,
        replacement: "docs/DEVELOPMENT/",
        description: "Remove duplicate docs/DEVELOPMENT path",
      },
      {
        pattern: /docs\/DEPLOYMENT\/docs\/DEPLOYMENT\//g,
        replacement: "docs/DEPLOYMENT/",
        description: "Remove duplicate docs/DEPLOYMENT path",
      },
      {
        pattern: /docs\/DEPLOYMENT\/DEPLOYMENT\//g,
        replacement: "docs/DEPLOYMENT/",
        description: "Remove duplicate DEPLOYMENT path",
      },
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
      // Fix root-level file references
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
      {
        pattern: /\]\(\.\.\/\.\.\/KUBERNETES_SELF_HOSTED_GUIDE\.md\)/g,
        replacement: "](../../docs/DEPLOYMENT/KUBERNETES_SELF_HOSTED_GUIDE.md)",
        description: "Replace KUBERNETES_SELF_HOSTED_GUIDE.md with proper path",
      },
      {
        pattern: /\]\(\.\.\/KUBERNETES_SELF_HOSTED_GUIDE\.md\)/g,
        replacement: "](../docs/DEPLOYMENT/KUBERNETES_SELF_HOSTED_GUIDE.md)",
        description: "Replace KUBERNETES_SELF_HOSTED_GUIDE.md with proper path",
      },
      {
        pattern: /\]\(CONTRIBUTING\.md\)/g,
        replacement: "](../../CONTRIBUTING.md)",
        description: "Fix CONTRIBUTING.md path",
      },
      {
        pattern: /\]\(\.\.\/\.\.\/CONTRIBUTING\.md\)/g,
        replacement: "](../../CONTRIBUTING.md)",
        description: "Fix CONTRIBUTING.md path",
      },
    ];
  }

  // Apply fixes to a file
  fixFile(filePath) {
    try {
      const fullPath = path.join(this.rootDir, filePath);
      let content = fs.readFileSync(fullPath, "utf8");
      let modified = false;
      const appliedFixes = [];

      const fixes = this.getCommonFixes();

      for (const fix of fixes) {
        const originalContent = content;
        content = content.replace(fix.pattern, fix.replacement);

        if (content !== originalContent) {
          modified = true;
          appliedFixes.push(fix.description);
        }
      }

      if (modified) {
        fs.writeFileSync(fullPath, content, "utf8");
        this.fixedLinks.push({
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

  // Remove references to non-existent files
  removeDeadLinks(filePath, deadLinks) {
    try {
      const fullPath = path.join(this.rootDir, filePath);
      let content = fs.readFileSync(fullPath, "utf8");
      let modified = false;

      // Files that should be removed entirely
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
          console.log(`  Removed dead link to ${fileName}`);
        }
      }

      if (modified) {
        // Clean up any double newlines created by removing links
        content = content.replace(/\n\n\n+/g, "\n\n");
        fs.writeFileSync(fullPath, content, "utf8");
      }

      return modified;
    } catch (error) {
      console.error(
        `❌ Error removing dead links from ${filePath}:`,
        error.message,
      );
      return false;
    }
  }

  // Run the fixer
  async fix() {
    console.log("🔧 Starting automatic link fixing...");

    // First, get all broken links
    const validator = new LinkValidator();
    validator.findMarkdownFiles();

    const processedFiles = new Set();

    // Apply common fixes to all markdown files
    for (const filePath of validator.allFiles) {
      if (!processedFiles.has(filePath)) {
        this.fixFile(filePath);
        processedFiles.add(filePath);
      }
    }

    // Run validation again to see remaining issues
    console.log("\n🔍 Re-validating links after fixes...");
    const newValidator = new LinkValidator();
    const report = newValidator.validate();

    // Remove dead links for files that definitely don't exist
    console.log("\n🗑️  Removing dead links...");
    for (const filePath of validator.allFiles) {
      this.removeDeadLinks(filePath, report.details);
    }

    // Final validation
    console.log("\n🔍 Final validation...");
    const finalValidator = new LinkValidator();
    const finalReport = finalValidator.validate();

    this.generateReport(finalReport);
    return finalReport;
  }

  generateReport(finalReport) {
    console.log("\n📊 Link Fixing Report");
    console.log("=====================");
    console.log(`Files processed: ${this.fixedLinks.length}`);
    console.log(`Remaining broken links: ${finalReport.brokenLinks}`);

    if (this.fixedLinks.length > 0) {
      console.log("\n✅ Fixed Files:");
      for (const fix of this.fixedLinks) {
        console.log(`  ${fix.file}:`);
        for (const description of fix.fixes) {
          console.log(`    - ${description}`);
        }
      }
    }

    if (finalReport.brokenLinks > 0) {
      console.log("\n⚠️  Manual fixes needed for remaining broken links");
    } else {
      console.log("\n🎉 All links are now working!");
    }
  }
}

// Run fixer if called directly
const fixer = new LinkFixer();
fixer
  .fix()
  .then((report) => {
    process.exit(report.brokenLinks > 0 ? 1 : 0);
  })
  .catch((error) => {
    console.error("Error running link fixer:", error);
    process.exit(1);
  });

export default LinkFixer;
