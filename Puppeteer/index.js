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
      const { url, formId } = JSON.parse(body);
      const browser = await puppeteer.launch();
      const page = await browser.newPage();
      await page.goto(url, { waitUntil: 'networkidle0' });
			await page.waitForSelector(`*[id*="${formId}"], *[class*="${formId}"], *[name*="${formId}"], *[data-*="${formId}"], *[action*="${formId}"]`);
			const formHandle = await page.$(`*[id*="${formId}"], *[class*="${formId}"], *[name*="${formId}"], *[data-*="${formId}"], *[action*="${formId}"]`);
			/*await page.waitForSelector(`#${formId}`);
      const formHandle = await page.$(`#${formId}`);*/
      const screenshot = await formHandle.screenshot();
      await browser.close();
      res.setHeader('Content-Type', 'application/json');
      res.end(screenshot.toString('base64'));
    });
	} 
	else {
		res.statusCode = 404;
		res.end();
	}
});
server.listen(3002);
