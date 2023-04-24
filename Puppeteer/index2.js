const http = require('http');
const puppeteer = require('puppeteer');

const server = http.createServer(async (req, res) => {
  if (req.method === 'POST' && req.url === '/search') {
    let body = '';
    console.log("Incoming request");

    req.on('data', chunk => {
      body += chunk.toString();
    });

    req.on('end', async () => {
      const { url } = JSON.parse(body);
      const browser = await puppeteer.launch();
      const page = await browser.newPage();
      await page.goto(url, { waitUntil: 'networkidle0' });
      const html = await page.content();
      await browser.close();
      res.setHeader('Content-Type', 'text/html');
      res.end(JSON.parse(JSON.stringify(html)));
    });
  }
  else {
    res.statusCode = 404;
    res.end();
  }
});

server.listen(3003);

