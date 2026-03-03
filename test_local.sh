#!/bin/bash

# Script สำหรับทดสอบ domeclaw-proxy ที่ local

set -e  # หยุดการทำงานเมื่อเจอ error

echo "กำลังทดสอบ domeclaw-proxy ที่ local..."

# ตรวจสอบว่า container กำลังรันอยู่
if ! docker-compose ps | grep -q "Up"; then
    echo "Container ไม่ได้กำลังรัน กำลังเริ่มต้นด้วย docker-compose up -d..."
    docker-compose up -d
    sleep 5  # รอให้ container เริ่มต้น
fi

# ทดสอบการสร้าง API Key (เฉพาะ local)
echo "1. กำลังทดสอบการสร้าง API Key..."
NEW_KEY=$(curl -s http://127.0.0.1:8080/admin/create_key | python3 -c "import sys, json; print(json.load(sys.stdin)['api_key'])" 2>/dev/null || echo "")
if [ -z "$NEW_KEY" ]; then
    echo "ไม่สามารถสร้าง API Key ได้"
else
    echo "สร้าง API Key ใหม่แล้ว: $NEW_KEY"
    
    # ทดสอบการเรียก API ผ่าน proxy
    echo "2. กำลังทดสอบการเรียก API ผ่าน proxy..."
    curl -X POST http://127.0.0.1:8080/v1/chat/completions \
         -H "Content-Type: application/json" \
         -H "Authorization: Bearer $NEW_KEY" \
         -d '{
           "model": "qwen-plus",
           "messages": [
             {
               "role": "user",
               "content": "Hello, how are you?"
             }
           ]
         }'
    echo ""
    
    # ตรวจสอบ usage ของ key นี้
    echo "3. กำลังตรวจสอบ usage ของ key นี้..."
    curl -s "http://127.0.0.1:8080/admin/get_usage?key=$NEW_KEY"
    echo ""
fi

echo "การทดสอบเสร็จสิ้น!"