// OpenAI multipart transcription contract: synthetic audio and credentials only.
const http = require('http');
http.createServer(async (req, res) => {
  const send = (code, body) => {res.writeHead(code, {'Content-Type':'application/json'}); res.end(JSON.stringify(body));};
  if (req.method !== 'POST' || !req.url.endsWith('/audio/transcriptions')) return send(501, {});
  if (!req.headers['content-type']?.startsWith('multipart/form-data; boundary=')) return send(400, {error:'multipart required'});
  if (req.headers.authorization !== 'Bearer synthetic-speech-key') return send(401, {error:'invalid credential'});
  if (req.url.startsWith('/failure/')) return send(429, {error:'synthetic rate limit'});
  if (req.url.startsWith('/malformed/')) return send(200, {unexpected:true});
  return send(200, {text:'Hello — اردو آواز'});
}).listen(process.env.PORT, '127.0.0.1');
