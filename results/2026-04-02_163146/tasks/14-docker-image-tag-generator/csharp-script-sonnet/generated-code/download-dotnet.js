#!/usr/bin/env node
// Downloads dotnet-install.sh and runs it to install .NET 10 SDK
const https = require('https');
const fs = require('fs');
const { execSync } = require('child_process');
const os = require('os');
const path = require('path');

const installScript = path.join(os.tmpdir(), 'dotnet-install.sh');
const dotnetDir = path.join(os.homedir(), '.dotnet');

console.log('Downloading dotnet-install.sh...');

const file = fs.createWriteStream(installScript);
https.get('https://dot.net/v1/dotnet-install.sh', (res) => {
  res.pipe(file);
  file.on('finish', () => {
    file.close();
    console.log('Running dotnet-install.sh...');
    fs.chmodSync(installScript, 0o755);
    execSync(`${installScript} --channel 10.0 --install-dir ${dotnetDir}`, { stdio: 'inherit' });
    console.log('Done! .NET installed to', dotnetDir);
  });
}).on('error', (err) => {
  console.error('Error:', err.message);
  process.exit(1);
});
