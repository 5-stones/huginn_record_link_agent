const fs = require('fs')
const filePath = './huginn_record_link_agent.gemspec';
const version = require('./package.json').version;

fs.readFile(filePath, 'utf8', (err, data) => {
  if (err) {
    return console.error(err);
  }

  const reg = /spec.version       = "([^"]+)"/g;
  const currentVersion = reg.exec(data)[1];
  console.info(`updating gemspec from v${currentVersion} to v${version}`);
  const result = data.replace(reg, `spec.version       = "${version}"`);

  fs.writeFile(filePath, result, 'utf8', (err) => {
     if (err) return console.error(err);
  });
});
