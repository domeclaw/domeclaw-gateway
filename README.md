# Domeclaw Gateway

A lightweight API Gateway for Qwen/Alibaba Cloud (DashScope) with token usage tracking and quota management.

## Features

- **API Key Management**: Create and manage custom API keys
- **Token Usage Tracking**: Monitor token consumption per API key
- **Quota Management**: Set token limits with automatic reset (5-hour TTL)
- **Proxy to Qwen**: Forward requests to `coding-intl.dashscope.aliyuncs.com`
- **Redis Backend**: Persistent storage for usage data
- **Static IP Network**: Docker network with fixed IPs to avoid DNS issues

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────────────────┐
│   Client    │────▶│  OpenResty   │────▶│  Alibaba Cloud (DashScope)  │
│ (Bearer    │     │  (Nginx+Lua) │     │  coding-intl.dashscope...   │
│  Token)     │     └──────┬───────┘     └─────────────────────────────┘
└─────────────┘            │
                           ▼
                    ┌──────────────┐
                    │    Redis     │  172.20.0.10:6379
                    │  (Usage DB)  │
                    └──────────────┘
```

## Quick Start

### Prerequisites

- Docker
- Docker Compose
- Alibaba Cloud API Key (for DashScope)

### Installation

1. Clone the repository:
```bash
git clone git@github.com:domeclaw/domeclaw-gateway.git
cd domeclaw-gateway
```

2. Create `.env` file with your Alibaba Cloud API Key:
```bash
echo "ALICLOUD_API_KEY=your-api-key-here" > .env
```

3. Start the services:
```bash
docker-compose up -d
```

4. Verify the installation:
```bash
curl http://127.0.0.1:8080/admin/create_key
```

## Usage

### 1. Create API Key (localhost only)

```bash
curl http://127.0.0.1:8080/admin/create_key
```

Response:
```json
{"api_key": "sk-xxxxxxxxxxxxxxxx"}
```

### 2. Use the API

```bash
curl -X POST http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-xxxxxxxxxxxxxxxx" \
  -d '{
    "model": "qwen3-coder-plus",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### 3. Check Usage (localhost only)

```bash
curl "http://127.0.0.1:8080/admin/get_usage?key=sk-xxxxxxxxxxxxxxxx"
```

Response:
```json
{"key": "sk-xxxxxxxxxxxxxxxx", "usage": 45}
```

## Configuration

### Token Limit

Default token limit is **100,000 tokens per 5 hours**. To change:

Edit `nginx.conf`:
```lua
local limit = 100000  -- Change this value
```

Then restart:
```bash
docker-compose restart gateway
```

### Network Configuration

The services use a static IP network:
- **Redis**: `172.20.0.10`
- **Gateway**: `172.20.0.x` (dynamic)

Network: `172.20.0.0/24`

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `ALICLOUD_API_KEY` | Your Alibaba Cloud DashScope API Key | Yes |

## Reset Quota

To manually reset usage for a key:

```bash
docker-compose exec redis redis-cli SET "usage:Bearer sk-xxxxxxxxxxxxxxxx" 0
```

Or wait for the **5-hour TTL** to expire automatically.

## API Endpoints

| Endpoint | Method | Access | Description |
|----------|--------|--------|-------------|
| `/admin/create_key` | GET | localhost only | Create new API key |
| `/admin/get_usage` | GET | localhost only | Check token usage |
| `/v1/chat/completions` | POST | Any (with Bearer token) | Chat completion API |

## Error Codes

| HTTP Status | Code | Description |
|-------------|------|-------------|
| 401 | `Missing API Key` | No Authorization header |
| 429 | `Quota exceeded` | Token limit reached |
| 500 | `Redis connection failed` | Backend issue |
| 502 | `Bad Gateway` | Upstream connection error |

## Development

### Project Structure

```
.
├── docker-compose.yml    # Service orchestration
├── nginx.conf            # OpenResty configuration
├── deploy.sh             # Deployment script
├── test_local.sh         # Local testing script
└── README.md             # This file
```

### Testing

Run local tests:
```bash
./test_local.sh
```

### Logs

View gateway logs:
```bash
docker-compose logs -f gateway
```

View Redis logs:
```bash
docker-compose logs -f redis
```

## Deployment

### Using deploy script

```bash
./deploy.sh
```

### Manual deployment

See `deploy_commands.txt` for manual deployment steps.

## Security Notes

- Admin endpoints (`/admin/*`) are restricted to localhost
- API keys are stored in Redis with 5-hour TTL
- `.env` file contains sensitive API keys - never commit it
- Redis data is stored in `./redis_data/` (excluded from git)

## License

MIT License

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Support

For issues and feature requests, please use the GitHub issue tracker.
