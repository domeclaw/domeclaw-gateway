# Domeclaw Gateway

A lightweight API Gateway for Qwen/Alibaba Cloud (DashScope) with dual-layer token usage tracking and quota management.

## Features

- **API Key Management**: Create and manage custom API keys (keys exist permanently)
- **Dual Usage Tracking**: Monitor token consumption with 2 time windows:
  - **5-hour window**: 1,000 tokens limit
  - **7-day window**: 8,000 tokens limit
- **Automatic Reset**: Usage counters reset automatically when TTL expires
- **Proxy to Qwen**: Forward requests to `coding-intl.dashscope.aliyuncs.com`
- **Redis Backend**: Persistent storage with AOF persistence
- **Static IP Network**: Docker network with fixed IPs to avoid DNS issues

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────────────────┐
│   Client    │────▶│  OpenResty   │────▶│  Alibaba Cloud (DashScope)  │
│ (Bearer    │     │  (Nginx+Lua) │     │  coding-intl.dashscope...   │
│  Token)     │     └──────┬───────┘     └─────────────────────────────┘
└─────────────┘            │
                           ▼
              ┌────────────────────────┐
              │        Redis           │  172.20.0.10:6379
              ├────────────────────────┤
              │  key:Bearer <key>      │  Permanent (no TTL)
              │  usage:5h:Bearer <key> │  TTL: 5 hours, Limit: 1,000
              │  usage:7d:Bearer <key> │  TTL: 7 days, Limit: 8,000
              └────────────────────────┘
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
{
  "key": "sk-xxxxxxxxxxxxxxxx",
  "usage_5h": 245,
  "limit_5h": 1000,
  "ttl_5h": 15842,
  "usage_7d": 1245,
  "limit_7d": 8000,
  "ttl_7d": 592341
}
```

### 4. List All API Keys (localhost only)

```bash
curl http://127.0.0.1:8080/admin/list_keys
```

Response:
```json
{
  "count": 3,
  "keys": ["sk-xxx", "sk-yyy", "sk-zzz"]
}
```

## Quota Management

### Dual Usage Windows

| Window | TTL | Token Limit | Reset Behavior |
|--------|-----|-------------|----------------|
| **5-hour** | 5 hours | 1,000 tokens | Auto-reset to 0 when TTL expires |
| **7-day** | 7 days | 8,000 tokens | Auto-reset to 0 when TTL expires |

### How It Works

1. **Key Creation**: Key exists permanently (no expiration)
2. **Usage Tracking**: Two independent counters track token usage
3. **Auto-Reset**: When TTL expires, usage automatically resets to 0
4. **Quota Exceeded**: Returns HTTP 429 if either limit is reached

### Manually Reset Usage

```bash
# Reset 5-hour usage
docker-compose exec redis redis-cli SET "usage:5h:Bearer sk-xxxxxxxxxxxxxxxx" 0

# Reset 7-day usage
docker-compose exec redis redis-cli SET "usage:7d:Bearer sk-xxxxxxxxxxxxxxxx" 0
```

## Configuration

### Network Configuration

The services use a static IP network:
- **Redis**: `172.20.0.10`
- **Gateway**: `172.20.0.x` (dynamic)

Network: `172.20.0.0/24`

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `ALICLOUD_API_KEY` | Your Alibaba Cloud DashScope API Key | Yes |

## API Endpoints

### Admin Endpoints (localhost only)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/admin/create_key` | GET | Create new API key |
| `/admin/get_usage` | GET | Check token usage for a key |
| `/admin/list_keys` | GET | List all API keys |

### API Endpoint

| Endpoint | Method | Access | Description |
|----------|--------|--------|-------------|
| `/v1/chat/completions` | POST | Any (with Bearer token) | Chat completion API |

## Error Codes

| HTTP Status | Error | Description |
|-------------|-------|-------------|
| 401 | `Missing API Key` | No Authorization header |
| 401 | `Invalid API Key` | Key not found in system |
| 429 | `Quota exceeded for 5-hour window` | 5-hour token limit reached |
| 429 | `Quota exceeded for 7-day window` | 7-day token limit reached |
| 500 | `Redis connection failed` | Backend issue |
| 502 | `Bad Gateway` | Upstream connection error |

## Data Persistence

Redis data is persisted using:
- **AOF (Append Only File)**: Logs every write operation
- **RDB Snapshots**: Periodic snapshots every 60 seconds

Data survives container restarts:
```bash
docker-compose down
docker-compose up -d
# All keys and usage data are preserved
```

## Development

### Project Structure

```
.
├── docker-compose.yml    # Service orchestration
├── nginx.conf            # OpenResty configuration
├── test_local.sh         # Local testing script
├── QWEN.md               # Thai debugging guide
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

## Security Notes

- Admin endpoints (`/admin/*`) are restricted to localhost
- API keys exist permanently (no expiration)
- Usage counters have TTL and auto-reset
- `.env` file contains sensitive API keys - never commit it
- Redis data is stored in Docker named volume (excluded from git)

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
