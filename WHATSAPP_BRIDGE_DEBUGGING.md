# WhatsApp Bridge Debugging & Next Steps

## 🔍 Debugging the WhatsApp Container

### 1. Check Container Status
```bash
# View all containers
docker ps

# Check specific WhatsApp bridge container
docker ps --filter name=mautrix-whatsapp
```

### 2. View Bridge Logs
```bash
# View all logs
docker logs mautrix-whatsapp

# Follow logs in real-time
docker logs -f mautrix-whatsapp

# View last 50 lines
docker logs --tail=50 mautrix-whatsapp

# View logs since specific time
docker logs --since="10m" mautrix-whatsapp
```

### 3. Access Bridge Container
```bash
# Get shell access to the container
docker exec -it mautrix-whatsapp /bin/sh

# Check bridge config inside container
docker exec mautrix-whatsapp cat /data/config.yaml

# Check registration file
docker exec mautrix-whatsapp cat /data/registration.yaml
```

### 4. Check Bridge Health
```bash
# Test if bridge is responding
curl -X POST http://localhost:29318/_matrix/app/v1/ping

# Check bridge database connection
docker exec mautrix-whatsapp /usr/bin/mautrix-whatsapp --config /data/config.yaml --test-db
```

### 5. Matrix Homeserver Logs
```bash
# Check if Matrix sees the appservice
docker logs arc-matrix | grep -i "whatsapp\|appservice"

# View recent Matrix errors
docker logs arc-matrix --since="5m" | grep ERROR
```

## 🚀 Next Steps After Launch

### Step 1: Verify Bridge is Running
```bash
# Check container status
docker ps --filter name=mautrix-whatsapp

# Should show: STATUS = Up X minutes
```

### Step 2: Check Bridge Logs for Errors
```bash
docker logs mautrix-whatsapp --tail=20
```

**Look for:**
- ✅ `Started appservice web server` - Bridge is listening
- ✅ `Connected to Matrix homeserver` - Connected to Matrix
- ❌ Connection errors, database errors, config errors

### Step 3: Verify Matrix Recognizes the Bridge
```bash
docker logs arc-matrix | grep "Loaded application service" | grep whatsapp
```

**Should show:**
```
INFO - Loaded application service: ApplicationService: {'id': 'whatsapp', ...}
```

### Step 4: Test Bridge Connectivity from Matrix
1. **Login to your Matrix client** (Element, etc.)
2. **Start a chat with the bridge bot**: `@whatsappbot:endurance.network`
3. **Send a test message**: `!wa help`

**Expected response:**
- The bot should respond with help commands
- If no response, check logs for errors

### Step 5: Connect Your WhatsApp Account
Once the bridge responds:

1. **Send login command**: `!wa login`
2. **Get QR code**: Bridge will provide a QR code or link
3. **Scan with WhatsApp**: Use WhatsApp mobile app to scan
4. **Wait for connection**: Bridge will confirm successful login

### Step 6: Verify WhatsApp Connection
```bash
# Check bridge logs for WhatsApp connection
docker logs mautrix-whatsapp | grep -E "(login|connected|authenticated)"
```

**Look for:**
- ✅ `Successfully logged in`
- ✅ `WhatsApp connection established`
- ❌ Login errors, connection timeouts

## 🐛 Common Issues & Solutions

### Issue 1: Bridge Container Won't Start
```bash
# Check container logs for startup errors
docker logs mautrix-whatsapp

# Common causes:
# - Config file syntax errors
# - Database connection issues
# - Permission problems
```

### Issue 2: Matrix Can't Connect to Bridge
```bash
# Check if bridge is listening on correct port
docker exec mautrix-whatsapp netstat -ln | grep 29318

# Check bridge network connectivity
docker network ls | grep matrix-internal
```

### Issue 3: Bridge Bot Doesn't Respond
```bash
# Check Matrix logs for appservice communication
docker logs arc-matrix | grep "appservice.*whatsapp"

# Verify bot user exists
docker logs arc-matrix | grep "whatsappbot"
```

### Issue 4: Database Connection Problems
```bash
# Test database connectivity
docker exec mautrix-whatsapp /usr/bin/mautrix-whatsapp --config /data/config.yaml --test-db

# Check PostgreSQL logs
docker logs arc-matrix-db
```

## 📊 Monitoring Commands

### Real-time Monitoring
```bash
# Monitor all Matrix-related containers
docker stats arc-matrix arc-matrix-db mautrix-whatsapp

# Follow logs from multiple containers
docker compose logs -f arc-matrix mautrix-whatsapp
```

### Health Checks
```bash
# Create a simple health check script
cat > check_bridge_health.sh << 'EOF'
#!/bin/bash
echo "=== Container Status ==="
docker ps --filter name=mautrix-whatsapp --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo -e "\n=== Recent Logs ==="
docker logs mautrix-whatsapp --tail=5

echo -e "\n=== Matrix Appservice Status ==="
docker logs arc-matrix --since="1m" | grep -i whatsapp | tail -3
EOF

chmod +x check_bridge_health.sh
./check_bridge_health.sh
```

## 🔧 Configuration Adjustments

### Enable Debug Logging
Edit `volume/mautrix-whatsapp/config.yaml`:
```yaml
logging:
    print_level: debug

python_logging:
    root:
        level: DEBUG
```

Then restart:
```bash
docker compose restart mautrix-whatsapp
```

### Increase Connection Timeouts
If experiencing connection issues:
```yaml
homeserver:
    address: http://arc-matrix:8008
    # Add timeout settings
    http_retry_count: 3
    http_timeout: 30
```

## 📱 Testing the Bridge

### Basic Test Sequence
1. **Start conversation with bridge bot**
2. **Send**: `!wa help`
3. **Send**: `!wa version`
4. **Send**: `!wa login`
5. **Scan QR code with WhatsApp**
6. **Send**: `!wa sync` (after login)

### Verify WhatsApp Integration
- New WhatsApp messages should appear in Matrix
- Matrix messages should be sent to WhatsApp
- Media files should transfer properly
- Group chats should be bridged

Let me know if you encounter any specific issues, and I'll help debug them!
