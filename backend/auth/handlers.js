// backend/auth/handlers.js
// Production-ready Express middleware for Auth0 JWT validation
// npm init -y; npm i express express-jwt jwks-rsa cors express-rate-limit
// node handlers.js

const express = require('express');
const cors = require('cors');
const { expressjwt } = require('express-jwt');
const jwksRsa = require('jwks-rsa');
const rateLimit = require('express-rate-limit');

const app = express();
app.use(express.json());
const allowedOrigins = [
  'https://app.cloudtolocalllm.online',
  'https://cloudtolocalllm.online',
  'http://localhost:3000',
  'http://localhost:8080',
  'http://127.0.0.1:3000',
  'http://127.0.0.1:8080'
];

app.use(cors({
  origin: (origin, callback) => {
    if (!origin) return callback(null, true);
    if (allowedOrigins.indexOf(origin) === -1) {
      const msg = 'The CORS policy for this site does not allow access from the specified Origin.';
      return callback(new Error(msg), false);
    }
    return callback(null, true);
  }
}));

const AUTH0_DOMAIN = process.env.AUTH0_DOMAIN || 'your-domain.auth0.com';
const AUDIENCE = process.env.AUTH0_AUDIENCE || 'your-audience';

const checkJwt = expressjwt({
  secret: jwksRsa.expressJwtSecret({
    cache: true,
    rateLimit: true,
    jwksRequestsPerMinute: 5,
    jwksUri: `https://${AUTH0_DOMAIN}/.well-known/jwks.json`,
  }),
  audience: AUDIENCE,
  issuer: `https://${AUTH0_DOMAIN}/`,
  algorithms: ['RS256'],
});

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100
});
app.use('/api/', limiter);

app.get('/api/protected', checkJwt, (req, res) => {
  res.json({
    message: 'Protected endpoint',
    user_id: req.auth.sub,
    email: req.auth.email,
  });
});

app.get('/health', (req, res) => res.json({ status: 'ok' }));

module.exports = { app };

if (require.main === module) {
  const port = process.env.PORT || 3000;
  app.listen(port, () => console.log(`Auth backend on port ${port}`));
}
