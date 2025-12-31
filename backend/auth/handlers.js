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
app.use(cors({ origin: '*' })); // Adjust for Flutter origins

const AUTH0_DOMAIN = 'your-domain.auth0.com'; // Replace
const AUDIENCE = 'your-audience'; // Replace

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
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});
app.use('/api/', limiter);

// Protected endpoint
app.get('/api/protected', checkJwt, (req, res) => {
  res.json({
    message: 'Protected endpoint',
    user_id: req.auth.sub,
    email: req.auth.email,
  });
});

// Health check
app.get('/health', (req, res) => res.json({ status: 'ok' }));

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Auth backend on port ${port}`));
