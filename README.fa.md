# تستر گروهی OpenVPN
یک اسکریپت bash برای لینوکس که به صورت خودکار فایل‌های `.ovpn` را تست می‌کند و سرورهای کارآمد را پیدا می‌کند.
---
### [English Guide](https://github.com/siniorone/ovpn-bulk-tester/README.md)|[راهنمای فارسی](https://github.com/siniorone/ovpn-bulk-tester/README.fa.md)
---

## قابلیت‌ها

- تست خودکار صدها فایل `.ovpn` به صورت پشت سر هم
- نمایش لاگ زنده در حین هر اتصال
- تشخیص دقیق دلیل شکست اتصال (خطای TLS، رد احراز هویت، DNS، Timeout و...)
- تست سرعت بعد از هر اتصال موفق
- نمایش IP خارجی از طریق تونل VPN
- ذخیره خودکار کانفیگ‌های کارآمد با جزئیات کامل
- دو سطح لاگ: خلاصه + دیباگ کامل
- نصب و حذف پیش‌نیازها از طریق منوی تعاملی
- نوار پیشرفت و رابط رنگی

---

## پیش‌نیازها

- لینوکس (تست شده روی Ubuntu/Debian)
- دسترسی `sudo`
- ابزارهای `openvpn`، `curl`، `ip` — از داخل منو قابل نصب هستند

---

## نصب

```bash
git clone https://github.com/siniorone/ovpn-bulk-tester
cd ovpn-bulk-tester
chmod +x ovpn_tester.sh
```

---

## استفاده

۱. فایل‌های `.ovpn` خود را در پوشه‌ای به نام `configs/` قرار دهید
۲. اسکریپت را اجرا کنید:

```bash
./ovpn_tester.sh
```

یا مسیر سفارشی بدهید:

```bash
./ovpn_tester.sh /path/to/configs
```

یوزرنیم و پسورد را می‌توان از طریق متغیر محیطی هم وارد کرد:

```bash
OVPN_USER="username" OVPN_PASS="password" ./ovpn_tester.sh
```

---

## گزینه‌های منو

| گزینه | توضیح |
|-------|-------|
| 1 | اجرای تستر گروهی |
| 2 | بررسی و نصب پیش‌نیازها |
| 3 | حذف openvpn |
| 4 | مشاهده کانفیگ‌های کارآمد |
| 5 | مشاهده لاگ‌ها |
| q | خروج |

---

## فایل‌های خروجی

| فایل | توضیح |
|------|-------|
| `working.txt` | کانفیگ‌های موفق با IP و سرعت |
| `test.log` | لاگ خلاصه همه تست‌ها |
| `detail.log` | لاگ کامل دیباگ شامل خروجی خام OpenVPN |
| `results/working_names.txt` | لیست ساده نام فایل‌های کارآمد |

---

## دلایل شکست اتصال

اسکریپت این موارد را تشخیص می‌دهد:

| دلیل | توضیح |
|------|-------|
| `Timeout` | سرور در زمان مقرر پاسخ نداد |
| `Authentication Failed` | یوزرنیم یا پسورد اشتباه |
| `TLS Handshake Error` | مشکل گواهینامه یا TLS |
| `Connection Refused` | سرور اتصال را رد کرد |
| `DNS Resolution Failed` | آدرس سرور پیدا نشد |
| `Network Unreachable` | مسیری به سرور وجود ندارد |
| `Certificate Verification Failed` | عدم تطابق CA |
| `Config Options Error` | گزینه نامعتبر در فایل `.ovpn` |

---

## تنظیمات

در ابتدای فایل `ovpn_tester.sh` قابل تغییر هستند:

```bash
CONNECT_TIMEOUT=20     # ثانیه انتظار برای هر کانفیگ
SPEED_TEST_MB=5        # حجم دانلود برای تست سرعت (مگابایت)
SPEED_TEST=true        # false کنید تا تست سرعت حذف شود
```

---

## لایسنس

MIT
