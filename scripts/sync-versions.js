#!/usr/bin/env node
/**
 * Version Synchronization Script
 * Updates all skill versions to match package.json version
 */

const fs = require('fs');
const path = require('path');

const PROJECT_ROOT = path.join(__dirname, '..');
const PACKAGE_JSON = path.join(PROJECT_ROOT, 'package.json');
const SKILLS_DIR = path.join(PROJECT_ROOT, 'skills');

// Colors for output
const GREEN = '\x1b[32m';
const YELLOW = '\x1b[33m';
const CYAN = '\x1b[36m';
const RESET = '\x1b[0m';

function ok(msg) {
  console.log(`  ${GREEN}✓${RESET} ${msg}`);
}

function warn(msg) {
  console.log(`  ${YELLOW}⚠${RESET} ${msg}`);
}

function info(msg) {
  console.log(`  ${CYAN}ℹ${RESET} ${msg}`);
}

function getPackageVersion() {
  try {
    const pkg = JSON.parse(fs.readFileSync(PACKAGE_JSON, 'utf8'));
    return pkg.version;
  } catch (err) {
    console.error('Error reading package.json:', err.message);
    process.exit(1);
  }
}

function updateSkillVersion(skillDir, newVersion) {
  const skillFile = path.join(skillDir, 'SKILL.md');
  
  if (!fs.existsSync(skillFile)) {
    warn(`No SKILL.md found in ${path.basename(skillDir)}`);
    return false;
  }
  
  let content = fs.readFileSync(skillFile, 'utf8');
  const originalContent = content;
  
  // Update version in frontmatter (YAML format)
  // Matches: version: x.y.z or version: "x.y.z"
  const versionRegex = /^(version:\s*)(["']?[0-9]+\.[0-9]+\.[0-9]+["']?)$/m;
  
  if (versionRegex.test(content)) {
    content = content.replace(versionRegex, `$1"${newVersion}"`);
    
    if (content !== originalContent) {
      fs.writeFileSync(skillFile, content, 'utf8');
      return true;
    }
  } else {
    warn(`No version field found in ${path.basename(skillDir)}/SKILL.md`);
  }
  
  return false;
}

function main() {
  const packageVersion = getPackageVersion();
  
  console.log('\n📦 Synchronizing versions to:', packageVersion);
  console.log('');
  
  let updatedCount = 0;
  
  // Find all skill directories
  if (!fs.existsSync(SKILLS_DIR)) {
    warn('No skills directory found');
    process.exit(0);
  }
  
  const skillDirs = fs.readdirSync(SKILLS_DIR, { withFileTypes: true })
    .filter(dirent => dirent.isDirectory())
    .map(dirent => path.join(SKILLS_DIR, dirent.name));
  
  if (skillDirs.length === 0) {
    warn('No skills found');
    process.exit(0);
  }
  
  for (const skillDir of skillDirs) {
    const skillName = path.basename(skillDir);
    
    if (updateSkillVersion(skillDir, packageVersion)) {
      ok(`Updated ${skillName} to ${packageVersion}`);
      updatedCount++;
    } else {
      info(`${skillName}: already at ${packageVersion} or no update needed`);
    }
  }
  
  console.log('');
  
  if (updatedCount > 0) {
    ok(`Synchronized ${updatedCount} skill(s) to version ${packageVersion}`);
  } else {
    info('All skills already at correct version');
  }
  
  console.log('');
}

main();
