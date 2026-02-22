# Environment Configuration

This folder contains environment-specific configuration files for the Notification Orchestrator.

## Available Environments

| File | Environment | Description |
|------|-------------|-------------|
| `dev.env` | Development | Local development with debug logging |
| `test.env` | Test | Automated testing with isolated databases |
| `staging.env` | Staging | Pre-production environment |
| `prod.env` | Production | Production environment with secrets from vault |
| `docker.env` | Docker | Docker Compose local development |

## Usage

### Local Development

```bash
cp envs/dev.env .env
mix phx.server
```

### Docker Development

```bash
docker-compose --env-file envs/docker.env up
```

## Service-Specific Variables

### Firebase Cloud Messaging (FCM)

- `FCM_PROJECT_ID` - Firebase project ID
- `FCM_PRIVATE_KEY` - Service account private key
- `FCM_CLIENT_EMAIL` - Service account email

### Apple Push Notification Service (APNS)

- `APNS_KEY_ID` - APNS key ID
- `APNS_TEAM_ID` - Apple Developer Team ID
- `APNS_KEY_PATH` - Path to .p8 key file
- `APNS_ENV` - `sandbox` or `production`

### Email (SMTP)

- `SMTP_HOST` - SMTP server hostname
- `SMTP_PORT` - SMTP server port
- `SMTP_USERNAME` - SMTP username
- `SMTP_PASSWORD` - SMTP password
- `SMTP_FROM_EMAIL` - Sender email address
- `SMTP_FROM_NAME` - Sender display name
