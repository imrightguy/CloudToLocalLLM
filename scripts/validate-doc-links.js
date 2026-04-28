#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
import process from 'process';
import { fileURLToPath } from 'url';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

const defaultTargets = [
  'README.md',
  'AGENTS.md',
  'SPEC.md',
  'docs/README.md',
  'docs/DOCUMENTATION_INDEX.md',
  'docs/architecture/README.md',
  'docs/architecture/SYSTEM_ARCHITECTURE.md',
  'docs/architecture/AVATAR_SYSTEM.md',
  'docs/architecture/DESKTOP_CONTROL.md',
  'docs/architecture/VISION_SYSTEM.md',
  'docs/api/README.md',
  'docs/operations/README.md',
  'docs/deployment/README.md',
  'docs/development/DEVELOPER_ONBOARDING.md',
  'docs/development/DEVELOPMENT_WORKFLOW.md',
  'docs/development/testing/COMPREHENSIVE_TESTING_GUIDE.md',
];

const ignoredDirs = new Set([
  '.git',
  '.codex',
  'build',
  'dist',
  'node_modules',
]);

function walkMarkdown(dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    if (ignoredDirs.has(entry.name)) {
      continue;
    }

    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...walkMarkdown(fullPath));
    } else if (entry.isFile() && entry.name.endsWith('.md')) {
      files.push(fullPath);
    }
  }

  return files;
}

function parseArgs(args) {
  if (args.includes('--all')) {
    return walkMarkdown(repoRoot);
  }

  const explicit = args.filter((arg) => !arg.startsWith('--'));
  const targets = explicit.length > 0 ? explicit : defaultTargets;
  return targets.map((target) => path.resolve(repoRoot, target));
}

function isExternalTarget(target) {
  return (
    target === '' ||
    target.startsWith('#') ||
    /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(target)
  );
}

function normalizeTarget(rawTarget) {
  let target = rawTarget.trim();

  if (target.startsWith('<') && target.endsWith('>')) {
    target = target.slice(1, -1);
  }

  const titleMatch = target.match(/^(\S+)\s+["'][^"']+["']$/);
  if (titleMatch) {
    target = titleMatch[1];
  }

  target = target.split('#')[0].split('?')[0];

  try {
    target = decodeURIComponent(target);
  } catch {
    return target;
  }

  return target;
}

function stripLineSuffix(candidate) {
  if (fs.existsSync(candidate)) {
    return candidate;
  }

  const match = candidate.match(/^(.+):\d+(?::\d+)?$/);
  if (match && fs.existsSync(match[1])) {
    return match[1];
  }

  return candidate;
}

function candidatePaths(sourceFile, target) {
  const candidates = [];

  if (path.isAbsolute(target)) {
    candidates.push(path.resolve(repoRoot, target.slice(1)));
    candidates.push(target);
  } else {
    candidates.push(path.resolve(path.dirname(sourceFile), target));

    const firstSegment = target.split(/[\\/]/)[0];
    if (firstSegment && fs.existsSync(path.resolve(repoRoot, firstSegment))) {
      candidates.push(path.resolve(repoRoot, target));
    }
  }

  return candidates.map(stripLineSuffix);
}

function targetExists(sourceFile, target) {
  return candidatePaths(sourceFile, target).some((candidate) => {
    if (fs.existsSync(candidate)) {
      return true;
    }

    if (!path.extname(candidate) && fs.existsSync(`${candidate}.md`)) {
      return true;
    }

    return false;
  });
}

function extractTargets(markdown) {
  const targets = [];
  const inline = /!?\[[^\]]*]\(([^)]+)\)/g;
  const reference = /^\s*\[[^\]]+]:\s*(\S+)/gm;
  let match;

  while ((match = inline.exec(markdown)) !== null) {
    targets.push(match[1]);
  }

  while ((match = reference.exec(markdown)) !== null) {
    targets.push(match[1]);
  }

  return targets;
}

const files = parseArgs(process.argv.slice(2));
const missingFiles = files.filter((file) => !fs.existsSync(file));

if (missingFiles.length > 0) {
  for (const file of missingFiles) {
    console.error(`Missing markdown file: ${path.relative(repoRoot, file)}`);
  }
  process.exit(1);
}

const failures = [];

for (const file of files) {
  const markdown = fs.readFileSync(file, 'utf8');

  for (const rawTarget of extractTargets(markdown)) {
    const target = normalizeTarget(rawTarget);

    if (isExternalTarget(target)) {
      continue;
    }

    if (!targetExists(file, target)) {
      failures.push({
        file: path.relative(repoRoot, file),
        target,
      });
    }
  }
}

if (failures.length > 0) {
  for (const failure of failures) {
    console.error(`${failure.file}: broken link -> ${failure.target}`);
  }
  console.error(`\n${failures.length} broken link(s) found.`);
  process.exit(1);
}

console.log(`Validated markdown links in ${files.length} file(s).`);
