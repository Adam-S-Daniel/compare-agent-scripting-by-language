#!/usr/bin/env node
// install-dotnet-node.js — download and install .NET 10 SDK using Node.js
'use strict';

const https  = require('https');
const http   = require('http');
const fs     = require('fs');
const path   = require('path');
const { execSync, spawnSync } = require('child_process');
const os     = require('os');

const WORKSPACE  = __dirname;
const DOTNET_DIR = path.join(WORKSPACE, '.dotnet');
const DOTNET_BIN = path.join(DOTNET_DIR, 'dotnet');
const SCRIPT     = path.join(WORKSPACE, 'dotnet-install.sh');

function download(url, dest) {
  return new Promise((resolve, reject) => {
    const proto = url.startsWith('https') ? https : http;
    const file  = fs.createWriteStream(dest);
    proto.get(url, (res) => {
      if (res.statusCode === 301 || res.statusCode === 302) {
        file.close();
        fs.unlinkSync(dest);
        return download(res.headers.location, dest).then(resolve).catch(reject);
      }
      if (res.statusCode !== 200) {
        reject(new Error(`HTTP ${res.statusCode}`));
        return;
      }
      res.pipe(file);
      file.on('finish', () => { file.close(); resolve(); });
    }).on('error', reject);
  });
}

async function main() {
  // Check if dotnet already in PATH
  const inPath = spawnSync('which', ['dotnet'], { shell: false });
  if (inPath.status === 0) {
    const ver = spawnSync(inPath.stdout.toString().trim(), ['--version']);
    console.log(`dotnet in PATH: ${ver.stdout.toString().trim()}`);
    return;
  }

  // Check local install
  if (fs.existsSync(DOTNET_BIN)) {
    const ver = spawnSync(DOTNET_BIN, ['--version']);
    console.log(`dotnet local: ${ver.stdout.toString().trim()}`);
    return;
  }

  // Download install script
  console.log('Downloading dotnet-install.sh ...');
  await download('https://dot.net/v1/dotnet-install.sh', SCRIPT);
  fs.chmodSync(SCRIPT, 0o755);

  // Run it
  console.log(`Installing .NET 10 to ${DOTNET_DIR} ...`);
  const result = spawnSync('bash', [SCRIPT, '--channel', '10.0', '--install-dir', DOTNET_DIR], {
    stdio: 'inherit',
    shell: false,
  });

  if (result.status !== 0) {
    console.error('Installation failed');
    process.exit(1);
  }

  const ver = spawnSync(DOTNET_BIN, ['--version']);
  console.log(`Installed: ${ver.stdout.toString().trim()}`);
}

main().catch(err => { console.error(err); process.exit(1); });
