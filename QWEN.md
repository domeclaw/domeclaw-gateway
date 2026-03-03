# Debugging Guide for domeclaw-proxy

## ระบบโดยรวม
- OpenResty (Nginx + Lua) ทำหน้าที่เป็น API Gateway
- Redis เก็บ token usage ของแต่ละ API Key
- Proxy ไปยัง https://coding-intl.dashscope.aliyuncs.com/v1

## ขั้นตอนการ Debug

### 1. ตรวจสอบสถานะ Container
```bash
# ดูสถานะ container ทั้งหมด
docker-compose ps

# ดู log ของแต่ละ container
docker-compose logs gateway
docker-compose logs redis
```

### 2. ตรวจสอบการเชื่อมต่อ Redis
```bash
# เชื่อมต่อ Redis container
docker-compose exec redis redis-cli

# ตรวจสอบ key ที่ถูกสร้าง
KEYS *
GET usage:Bearer_sk-xxx
```

### 3. ทดสอบ API Endpoint
```bash
# สร้าง API Key ใหม่
curl http://127.0.0.1:8080/admin/create_key

# ตรวจสอบ usage ของ key
curl "http://127.0.0.1:8080/admin/get_usage?key=sk-xxx"

# ทดสอบการเรียก API ผ่าน proxy
curl -X POST http://127.0.0.1:8080/v1/chat/completions \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer sk-xxx" \
     -d '{
       "model": "qwen-plus",
       "messages": [
         {
           "role": "user",
           "content": "Hello"
         }
       ]
     }'
```

### 4. ตรวจสอบ log ของ OpenResty
```bash
# ดู log ของ OpenResty
docker-compose logs gateway

# ถ้าต้องการ log แบบ real-time
docker-compose logs -f gateway
```

### 5. ตรวจสอบ nginx.conf
- ตรวจสอบ syntax ของ nginx.conf
- ยืนยันว่า upstream server ถูกต้อง
- ยืนยันว่า location block ถูกต้อง

### 6. ปัญหาที่พบบ่อย

#### ปัญหา: 401 Unauthorized
- สาเหตุ: ไม่ได้ส่ง Authorization header
- วิธีแก้: ยืนยันว่าส่ง `Authorization: Bearer YOUR_API_KEY`

#### ปัญหา: 429 Quota exceeded
- สาเหตุ: ใช้ token เกิน limit ที่กำหนด (100,000 tokens)
- วิธีแก้: รอให้ TTL หมด (5 ชั่วโมง) หรือ reset ค่าใน Redis

#### ปัญหา: 500 Internal Server Error
- สาเหตุ: ไม่สามารถเชื่อมต่อ Redis ได้
- วิธีแก้: ตรวจสอบว่า Redis container กำลังรันอยู่ และสามารถเข้าถึงได้จาก OpenResty

#### ปัญหา: 502 Bad Gateway
- สาเหตุ: ไม่สามารถเชื่อมต่อ upstream server ได้
- วิธ้แก้: ตรวจสอบว่า upstream server สามารถเข้าถึงได้ และ ALICLOUD_API_KEY ถูกต้อง

### 7. การตรวจสอบและทดสอบเพิ่มเติม

#### ใช้ telnet หรือ nc เพื่อทดสอบการเชื่อมต่อ
```bash
# ทดสอบการเชื่อมต่อ Redis
telnet localhost 6379

# ทดสอบการเชื่อมต่อ upstream
nc -zv coding-intl.dashscope.aliyuncs.com 443
```

#### ตรวจสอบ resource ของ container
```bash
# ดู resource usage ของ container
docker stats
```

### 8. วิธีการ restart service
```bash
# restart แค่ container เดียว
docker-compose restart gateway

# restart ทั้งหมด
docker-compose restart

# ถ้ามีปัญหา ลบ container และสร้างใหม่
docker-compose down
docker-compose up -d
```

### 9. การตั้งค่าเพิ่มเติมสำหรับการ debug
- เพิ่ม `error_log /var/log/nginx/error.log debug;` ใน nginx.conf สำหรับ log ระดับ debug
- ใช้ `lua_code_cache off;` สำหรับ reload โค้ด lua โดยไม่ต้อง restart nginx (ใน development เท่านั้น)