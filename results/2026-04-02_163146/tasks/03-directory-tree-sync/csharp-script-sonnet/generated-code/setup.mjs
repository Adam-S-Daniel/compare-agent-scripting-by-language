#!/usr/bin/env node
// Install .NET 10 SDK and run tests using Node.js as a bootstrap

import { execSync, spawnSync } from 'child_process';
import { createWriteStream } from 'fs';
import { get } from 'https';
import { homedir } from 'os';
import { join } from 'path';
import { existsSync, chmodSync } from 'fs';

const dotnetPath = join(homedir(), '.dotnet', 'dotnet');
const installScript = '/tmp/dotnet-install.sh';

// Download the install script
async function download(url, dest) {
  return new Promise((resolve, reject) => {
    const file = createWriteStream(dest);
    get(url, res => {
      res.pipe(file);
      file.on('finish', () => file.close(resolve));
    }).on('error', reject);
  });
}

if (!existsSync(dotnetPath)) {
  console.log('Downloading .NET install script...');
  await download('https://dot.net/v1/dotnet-install.sh', installScript);
  chmodSync(installScript, '755');

  console.log('Installing .NET 10...');
  execSync(`${installScript} --channel 10.0`, { stdio: 'inherit' });
}

const dotnetRoot = join(homedir(), '.dotnet');
const env = { ...process.env, DOTNET_ROOT: dotnetRoot, PATH: `${dotnetRoot}:${process.env.PATH}` };

console.log('dotnet version:', execSync('dotnet --version', { env }).toString().trim());

console.log('\n=== Running Tests ===');
const result = spawnSync('dotnet', ['test', 'DirSync.Tests/', '--logger', 'console;verbosity=normal'], {
  env, stdio: 'inherit'
});
process.exit(result.status ?? 1);
