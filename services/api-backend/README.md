# ImmoGestion API Backend

API backend for the ImmoGestion leasing automation engine, built with Node.js, Express, and Drizzle ORM.

## Product framing

Core product focus:
- Inbound marketplace message handling from channels like Facebook Messenger
- Visit scheduling, confirmation, rescheduling, outcomes, and staff coordination
- SMS and email as communications inside the visit workflow, not as standalone products

Secondary support systems:
- Buildings, units, leads, documents, schedules, notifications, and analytics that support the core flow

Deferred or lower-priority scope:
- Broad property-management expansion that does not directly improve message intake or visit execution
- Deep accounting, maintenance management, and generic CRM surface area unless they directly serve the core workflow

See `../../docs/TEAM-OWNERSHIP-AND-REVIEW-CADENCE.md` for the cross-team ownership and roadmap review model.

## Features

- 🏢 **Building Management**: Full CRUD for buildings and units
- 📝 **Lead Management**: Lead tracking, status updates, and bulk operations
- 🏠 **Visit Scheduling**: Automated visit scheduling with SMS/email confirmations and reminders
- 📄 **Document Management**: Upload, review, and approval system for documents
- ⏰ **Schedule Management**: Automated scheduling with recurring exceptions
- 💬 **Communication Tools**: Inbound Facebook Messenger, SMS, email, and phone call integration
- 🔐 **Authentication**: JWT-based authentication with role-based access
- 🚦 **Rate Limiting**: Configurable rate limiting to prevent abuse
- 🛡️ **Security**: CORS, helmet, and other security middleware
- 📊 **Database**: PostgreSQL with Drizzle ORM for type-safe queries

## Getting Started

### Prerequisites

- Node.js >= 18.0.0
- PostgreSQL >= 14
- npm or yarn

### Installation

1. Clone the repository:
```bash
git clone https://github.com/imrightguy/ImmoGestion.git
cd ImmoGestion/services/api-backend
```

2. Install dependencies:
```bash
npm install
```

3. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your database credentials and other configuration
```

4. Run migrations:
```bash
npm run migrate
```

5. Start the server:
```bash
npm start
```

For development:
```bash
npm run dev
```

## API Endpoints

### Buildings
- `GET /api/buildings` - List all buildings
- `POST /api/buildings` - Create new building
- `GET /api/buildings/:id` - Get building by ID
- `PUT /api/buildings/:id` - Update building
- `DELETE /api/buildings/:id` - Delete building
- `GET /api/buildings/units` - List all units
- `POST /api/buildings/units` - Create new unit
- `GET /api/buildings/units/:id` - Get unit by ID
- `PUT /api/buildings/units/:id` - Update unit
- `DELETE /api/buildings/units/:id` - Delete unit

### Leads
- `GET /api/leads` - List all leads
- `POST /api/leads` - Create new lead
- `GET /api/leads/:id` - Get lead by ID
- `PUT /api/leads/:id` - Update lead
- `PATCH /api/leads/:id/status` - Update lead status
- `DELETE /api/leads/:id` - Delete lead

### Visits
- `GET /api/visits` - List all visits
- `POST /api/visits` - Schedule new visit
- `GET /api/visits/:id` - Get visit by ID
- `PUT /api/visits/:id` - Update visit
- `PATCH /api/visits/:id/status` - Update visit status
- `GET /api/visits/availability` - Check availability

### Documents
- `GET /api/documents` - List all documents
- `POST /api/documents` - Upload document
- `GET /api/documents/:id` - Get document by ID
- `PUT /api/documents/:id` - Update document
- `DELETE /api/documents/:id` - Delete document
- `GET /api/documents/search` - Search documents

### Schedules
- `GET /api/schedules` - List all schedules
- `POST /api/schedules` - Create new schedule
- `GET /api/schedules/:id` - Get schedule by ID
- `PUT /api/schedules/:id` - Update schedule
- `DELETE /api/schedules/:id` - Delete schedule
- `GET /api/schedules/availability` - Check schedule availability

### Communications
- `GET /api/communications` - List communications
- `POST /api/communications/email` - Send email
- `POST /api/communications/sms` - Send SMS
- `POST /api/communications/phone` - Record phone call
- `GET /api/communications/templates` - List templates
- `POST /api/communications/templates` - Create template

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | Required |
| `PORT` | Server port | 3000 |
| `NODE_ENV` | Environment (development/production) | development |
| `JWT_SECRET` | JWT signing secret | Required |
| `JWT_EXPIRES_IN` | JWT expiration time | 24h |
| `RATE_LIMIT_WINDOW_MS` | Rate limit window in milliseconds | 900000 |
| `RATE_LIMIT_MAX_REQUESTS` | Max requests per window | 100 |

### Database Schema

The database uses PostgreSQL with Drizzle ORM. Key tables include:

- `buildings` - Property information
- `units` - Rental units
- `leads` - Lead information
- `visits` - Scheduled visits
- `documents` - Document storage
- `schedules` - Recurring schedules
- `communications` - Communication logs

## Development

### Scripts

- `npm start` - Start production server
- `npm run dev` - Start development server with auto-reload
- `npm run test` - Run tests
- `npm run test:watch` - Run tests in watch mode
- `npm run test:coverage` - Run tests with coverage
- `npm run lint` - Run ESLint
- `npm run lint:fix` - Fix ESLint issues
- `npm run migrate` - Run database migrations
- `npm run seed` - Seed initial data

### Testing

The project uses Jest for testing. Create test files in the `tests/` directory:

```bash
# Run all tests
npm test

# Run tests in watch mode
npm run test:watch

# Run tests with coverage
npm run test:coverage
```

## API Response Format

All API responses follow this format:

```json
{
  "success": true,
  "data": {},
  "message": "Success message",
  "metadata": {
    "pagination": {
      "total": 100,
      "page": 1,
      "limit": 20
    }
  }
}
```

Error responses:

```json
{
  "success": false,
  "error": {
    "message": "Error message",
    "code": "ERROR_CODE",
    "details": {}
  }
}
```

## Security Features

- JWT-based authentication
- Rate limiting
- CORS configuration
- Helmet security headers
- Input validation with Joi
- Password hashing with bcrypt
- File type and size validation

## Integrations

### Email Services

- **SMTP**: Email sending via nodemailer
- **Gmail**: Gmail API integration
- **SendGrid**: SendGrid API integration

### SMS Services

- **Twilio**: SMS sending via Twilio API
- **Local SMS**: SMS integration for local Quebec providers

### Social Media

- **Facebook Messenger**: Facebook Messenger bot integration

### Third-party APIs

- **Google Maps**: Location services
- **OpenAI**: AI-powered content generation

## Monitoring

The backend includes built-in logging and error tracking:

- Application logs
- Error tracking integration
- Performance metrics
- Database query logging

## Deployment

### Production Setup

1. Set environment variables for production
2. Run migrations: `npm run migrate`
3. Start server: `npm start`
4. Configure reverse proxy (nginx, etc.)
5. Set up SSL certificates
6. Configure monitoring and logging

### Docker Support

```bash
# Build and run with Docker
docker build -t immogestion-api .
docker run -p 3000:3000 immogestion-api
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:

- Email: christopher.maltais@gmail.com
- GitHub: https://github.com/imrightguy/ImmoGestion/issues
- Discord: right_guy

## Roadmap

### Launch Scope
- Public landing page, login wall, and core message-to-visit workflow
- Visit coordination and confirmation workflows
- Reporting focused on message-to-visit conversion
- Web demo hardening and UI polish

### Deferred / Future
- Mobile app support for the core workflow is deferred and not part of this launch
- Automated follow-up systems tied to visits and replies
- Integration with third-party services that support the core workflow
- Advanced analytics dashboard for lead and visit operations
- Machine learning predictions that improve message or visit outcomes
- Advanced automation features for leasing operations
- Multi-tenant support
- International expansion