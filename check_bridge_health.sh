#!/bin/bash

echo "==============================================="
echo "   WhatsApp Bridge Health Check"
echo "==============================================="

echo -e "\n=== Container Status ==="
docker ps --filter name=mautrix-whatsapp --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo -e "\n=== Bridge Process ==="
docker exec mautrix-whatsapp ps aux | grep mautrix

echo -e "\n=== Bridge Port Listening ==="
docker exec mautrix-whatsapp netstat -ln | grep 29318

echo -e "\n=== Matrix Appservice Registration ==="
docker logs arc-matrix 2>&1 | grep "Loaded application service" | grep whatsapp | tail -1

echo -e "\n=== Recent Bridge Activity ==="
echo "Note: Bridge logs may not be captured due to output format"
echo "Use: docker logs mautrix-whatsapp"

echo -e "\n=== Configuration Files ==="
echo "Config file exists: $(docker exec mautrix-whatsapp test -f /data/config.yaml && echo "✅ YES" || echo "❌ NO")"
echo "Registration file exists: $(docker exec mautrix-whatsapp test -f /data/registration.yaml && echo "✅ YES" || echo "❌ NO")"

echo -e "\n=== Network Connectivity ==="
echo "Bridge can reach Matrix: $(docker exec mautrix-whatsapp wget -q --spider http://arc-matrix:8008 && echo "✅ YES" || echo "❌ NO")"

echo -e "\n=== Next Steps ==="
echo "1. Connect to Matrix client (Element, etc.)"
echo "2. Start chat with: @whatsappbot:endurance.network"
echo "3. Send: !wa help"
echo "4. Send: !wa login"
echo "5. Scan QR code with WhatsApp app"

echo -e "\n==============================================="
