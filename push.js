const { exec } = require('child_process');
const version = require('./package.json').version;

dir = exec(`gem push huginn_record_link_agent-${version}.gem`, (err, stdout, stderr) => {
  if (err) {
    console.error(err);
  }

  console.info(stdout);
});
