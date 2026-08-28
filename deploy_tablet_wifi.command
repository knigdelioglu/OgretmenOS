#!/usr/bin/env bash
# ==============================================================================
# Ölçerim - Android Tablet Wi-Fi ADB Derleme & Otomatik Dağıtım Scripti
# ==============================================================================
# Finder'dan çift tıklanarak doğrudan çalıştırılabilir (.command formatı).
# ==============================================================================

# Scriptin bulunduğu klasöre git (Proje kökü)
cd "$(dirname "$0")" || exit 1

# Renkli çıktı tanımları
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}${BOLD}====================================================${NC}"
echo -e "${BLUE}${BOLD}   ÖLÇERİM - Android Tablet Wi-Fi Dağıtım Aracı     ${NC}"
echo -e "${BLUE}${BOLD}====================================================${NC}"
echo ""

# Ortam değişkenlerini ve PATH'i yapılandır
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/development/flutter/bin:$HOME/flutter/bin:$HOME/.flutter/bin:$HOME/Library/Android/sdk/platform-tools"
export ADB_MDNS_AUTO_CONNECT=1
export ADB_MDNS_OPENSCREEN=1

# Shell profillerini yükle
if [ -f "$HOME/.zprofile" ]; then
  source "$HOME/.zprofile" 2>/dev/null || true
fi
if [ -f "$HOME/.zshrc" ]; then
  source "$HOME/.zshrc" 2>/dev/null || true
fi

# 1. Gerekli CLI araçlarını denetle
if ! command -v adb >/dev/null 2>&1; then
  echo -e "${RED}❌ 'adb' (Android Debug Bridge) komutu bulunamadı!${NC}"
  echo -e "${YELLOW}Homebrew ile yüklemek için: ${CYAN}brew install android-platform-tools${NC}"
  echo ""
  read -p "Çıkmak için [Enter] tuşuna basın..." _
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo -e "${RED}❌ 'flutter' komutu bulunamadı!${NC}"
  echo -e "${YELLOW}Flutter SDK yolunun PATH değişkeninize eklendiğinden emin olun.${NC}"
  echo ""
  read -p "Çıkmak için [Enter] tuşuna basın..." _
  exit 1
fi

IP_CONFIG_FILE=".tablet_ip"
DEVICE_TARGET=""

# Fonksiyon: Aktif ve yetkili cihazları bul
get_connected_devices() {
  adb devices -l | awk 'NR>1 && $2=="device" {print $1}'
}

# Fonksiyon: Tek bir bağlı cihaz varsa hedef yap
check_single_connected_device() {
  local devices
  devices=$(get_connected_devices)
  local count
  count=$(echo "$devices" | grep -v '^$' | wc -l | tr -d ' ')
  if [ "$count" -eq 1 ]; then
    DEVICE_TARGET=$(echo "$devices" | head -n 1 | tr -d '[:space:]')
    echo "$DEVICE_TARGET"
    return 0
  fi
  return 1
}

# Fonksiyon: USB bağlıysa Wi-Fi moduna geçirip IP'sini al
try_usb_switch_to_wifi() {
  local usb_devices
  usb_devices=$(adb devices -l | awk 'NR>1 && $2=="device" && $1 !~ /:/ {print $1}')
  if [ -n "$usb_devices" ]; then
    local usb_dev
    usb_dev=$(echo "$usb_devices" | head -n 1)
    echo -e "${CYAN}🔌 USB ile bağlı cihaz tespit edildi ($usb_dev), Wi-Fi portu (5555) etkinleştiriliyor...${NC}" >&2
    local tablet_wlan_ip
    # IP'yi tcpip geçişinden önce oku; bazı Android sürümleri geçişten hemen
    # sonra USB üzerinden shell komutlarını kısa süreliğine yanıtlamaz.
    tablet_wlan_ip=$(adb -s "$usb_dev" shell ip -f inet addr show wlan0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n 1 | tr -d '[:space:]')
    if [ -z "$tablet_wlan_ip" ]; then
      tablet_wlan_ip=$(adb -s "$usb_dev" shell ifconfig wlan0 2>/dev/null | awk '/inet addr:/ {print $2}' | cut -d: -f2 | head -n 1 | tr -d '[:space:]')
    fi
    if [ -z "$tablet_wlan_ip" ]; then
      tablet_wlan_ip=$(adb -s "$usb_dev" shell ip -o -4 addr show scope global 2>/dev/null | awk '$2 != "lo" {sub(/\/.*/, "", $4); print $4; exit}' | tr -d '[:space:]')
    fi
    if [ -n "$tablet_wlan_ip" ]; then
      adb -s "$usb_dev" tcpip 5555 >/dev/null 2>&1 || true
      sleep 1
      echo -e "${GREEN}📱 Tablet Wi-Fi IP adresi alındı: ${tablet_wlan_ip}:5555${NC}" >&2
      adb connect "${tablet_wlan_ip}:5555" >/dev/null 2>&1 || true
      echo "${tablet_wlan_ip}:5555" > "$IP_CONFIG_FILE"
      DEVICE_TARGET="${tablet_wlan_ip}:5555"
      echo "$DEVICE_TARGET"
      return 0
    fi
  fi
  return 1
}

# Fonksiyon: Ağ taraması ile port 5555 açık Android tableti bul
auto_scan_network() {
  python3 -c "
import socket
import concurrent.futures
import subprocess
import re

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return None

def check_ip(ip):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(0.35)
    try:
        s.connect((ip, 5555))
        s.close()
        return ip
    except Exception:
        return None

local_ip = get_local_ip()
if not local_ip:
    exit(1)

prefix = '.'.join(local_ip.split('.')[:3]) + '.'
ips = [f'{prefix}{i}' for i in range(1, 255) if f'{prefix}{i}' != local_ip]

found = []
with concurrent.futures.ThreadPoolExecutor(max_workers=60) as ex:
    for res in ex.map(check_ip, ips):
        if res:
            found.append(res)

if found:
    print(f'{found[0]}:5555')
    exit(0)
exit(1)
" 2>/dev/null
}

# Fonksiyon: mDNS servislerinden keşif yap
auto_scan_mdns() {
  adb mdns services 2>/dev/null | awk '/_adb-tls-connect\._tcp|_adb\._tcp/ {print $3}' | head -n 1
}

# Fonksiyon: APK içinden uygulama paket adını bul
get_apk_package_name() {
  local aapt_path=""
  local sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"

  if command -v aapt >/dev/null 2>&1; then
    aapt_path=$(command -v aapt)
  elif [ -d "$sdk_root/build-tools" ]; then
    aapt_path=$(find "$sdk_root/build-tools" -type f -name aapt -perm -111 2>/dev/null | sort -V | tail -n 1)
  fi

  if [ -z "$aapt_path" ]; then
    return 1
  fi

  "$aapt_path" dump badging "$1" 2>/dev/null \
    | sed -n "s/^package: name='\\([^']*\\)'.*/\\1/p" \
    | head -n 1
}

echo -e "${CYAN}🔍 Tablet otomatik aranıyor...${NC}"

# 1. Adım: USB bağlı cihaz varsa önce kablosuza geçir.
# Bu adım, tek USB cihazını doğrudan hedef seçmeden önce çalışmalıdır;
# aksi halde IP kaydedilmez ve sonraki çalıştırmada kullanıcıdan istenir.
if [ -z "$DEVICE_TARGET" ]; then
  USB_TARGET=$(try_usb_switch_to_wifi || true)
  if [ -n "$USB_TARGET" ]; then
    DEVICE_TARGET="$USB_TARGET"
  fi
fi

# 2. Adım: Zaten bağlı bir Wi-Fi cihazı varsa hedef yap
if [ -z "$DEVICE_TARGET" ] && check_single_connected_device >/dev/null 2>&1; then
  echo -e "${GREEN}✅ Aktif bağlı cihaz bulundu: ${BOLD}${DEVICE_TARGET}${NC}"
fi

# 3. Adım: Kayıtlı IP varsa sessizce bağlanmayı dene
if [ -z "$DEVICE_TARGET" ] && [ -f "$IP_CONFIG_FILE" ]; then
  SAVED_IP="$(cat "$IP_CONFIG_FILE" | tr -d '[:space:]')"
  if [ -n "$SAVED_IP" ]; then
    echo -e "Kayıtlı IP deneniyor (${SAVED_IP})..."
    adb connect "$SAVED_IP" >/dev/null 2>&1 || true
    sleep 0.5
    if adb devices | grep -E "${SAVED_IP}[[:space:]]+device" >/dev/null 2>&1; then
      DEVICE_TARGET="$SAVED_IP"
      echo -e "${GREEN}✅ Kayıtlı IP üzerinden bağlandı: ${BOLD}${DEVICE_TARGET}${NC}"
    fi
  fi
fi

# 4. Adım: mDNS ile Android 11+ Kablosuz Hata Ayıklama keşfi
if [ -z "$DEVICE_TARGET" ]; then
  MDNS_IP=$(auto_scan_mdns || true)
  if [ -n "$MDNS_IP" ]; then
    echo -e "${GREEN}✅ mDNS ile tablet bulundu: ${MDNS_IP}${NC}"
    adb connect "$MDNS_IP" >/dev/null 2>&1 || true
    if adb devices | grep -E "${MDNS_IP}[[:space:]]+device" >/dev/null 2>&1; then
      DEVICE_TARGET="$MDNS_IP"
      echo "$DEVICE_TARGET" > "$IP_CONFIG_FILE"
    fi
  fi
fi

# 5. Adım: Yerel ağda port 5555 hızlı tarama
if [ -z "$DEVICE_TARGET" ]; then
  echo -e "Ağdaki cihazlar taranıyor..."
  SCANNED_IP=$(auto_scan_network || true)
  if [ -n "$SCANNED_IP" ]; then
    echo -e "${GREEN}✅ Ağda ADB portu açık tablet bulundu: ${SCANNED_IP}${NC}"
    adb connect "$SCANNED_IP" >/dev/null 2>&1 || true
    if adb devices | grep -E "${SCANNED_IP}[[:space:]]+device" >/dev/null 2>&1; then
      DEVICE_TARGET="$SCANNED_IP"
      echo "$DEVICE_TARGET" > "$IP_CONFIG_FILE"
    fi
  fi
fi

# 6. Adım: Hala bulunamadıysa kullanıcıya sor ve yol göster
while [ -z "$DEVICE_TARGET" ]; do
  echo ""
  echo -e "${YELLOW}⚠️  Tablet ağda otomatik algılanamadı.${NC}"
  echo -e "${CYAN}İpuçları:${NC}"
  echo " • Tableti 1 defa USB kablosu ile Mac'e bağlarsanız Wi-Fi bağlantısı otomatik yapılandırılır."
  echo " • Veya tablette Ayarlar > Geliştirici Seçenekleri > Kablosuz Hata Ayıklama ekranındaki IP:Port adresini girebilirsiniz."
  echo ""
  read -p "Tablet IP:Port (örn: 192.168.50.50 veya tekrar taramak için [Enter]): " USER_INPUT
  
  if [ -z "$USER_INPUT" ]; then
    echo -e "${CYAN}Yeniden taranıyor...${NC}"
    # USB kontrol
    USB_TARGET=$(try_usb_switch_to_wifi || true)
    if [ -n "$USB_TARGET" ]; then
      DEVICE_TARGET="$USB_TARGET"
      break
    fi
    # Port scan kontrol
    SCANNED_IP=$(auto_scan_network || true)
    if [ -n "$SCANNED_IP" ]; then
      adb connect "$SCANNED_IP" >/dev/null 2>&1 || true
      if adb devices | grep -E "${SCANNED_IP}[[:space:]]+device" >/dev/null 2>&1; then
        DEVICE_TARGET="$SCANNED_IP"
        echo "$DEVICE_TARGET" > "$IP_CONFIG_FILE"
        break
      fi
    fi
  else
    if [[ "$USER_INPUT" != *:* ]]; then
      USER_INPUT="${USER_INPUT}:5555"
    fi
    adb connect "$USER_INPUT" >/dev/null 2>&1 || true
    if adb devices | grep -E "${USER_INPUT}[[:space:]]+device" >/dev/null 2>&1; then
      DEVICE_TARGET="$USER_INPUT"
      echo "$DEVICE_TARGET" > "$IP_CONFIG_FILE"
      break
    else
      echo -e "${RED}❌ $USER_INPUT adresine bağlanılamadı. Lütfen tablet ekranında izin penceresi varsa onaylayın.${NC}"
    fi
  fi
done

echo ""
echo -e "${GREEN}🚀 Hedef Cihaz: ${BOLD}${DEVICE_TARGET}${NC}"
echo ""

# 4. Flutter Release Build
echo -e "${BLUE}📦 Release APK derleniyor (flutter build apk --release)...${NC}"
flutter build apk --release

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$APK_PATH" ]; then
  echo -e "${RED}❌ APK dosyası oluşturulamadı: $APK_PATH${NC}"
  read -p "Çıkmak için [Enter] tuşuna basın..." _
  exit 1
fi

echo -e "${GREEN}✅ Derleme tamamlandı.${NC}"
echo ""

# 5. Tablete Yükleme
echo -e "${BLUE}📲 Tablet üzerine yükleniyor (${DEVICE_TARGET})...${NC}"
adb -s "$DEVICE_TARGET" install -r "$APK_PATH"

# 6. Uygulamayı Başlat
PACKAGE_NAME=$(get_apk_package_name "$APK_PATH" || true)
if [ -n "$PACKAGE_NAME" ]; then
  echo -e "${BLUE}🚀 Uygulama tablet üzerinde başlatılıyor (${PACKAGE_NAME})...${NC}"
  adb -s "$DEVICE_TARGET" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true
else
  echo -e "${YELLOW}⚠️ APK paket adı otomatik okunamadı; uygulama başlatılmadı.${NC}"
  echo -e "${YELLOW}   Yükleme tamamlandı, ancak otomatik başlatma için Android SDK build-tools içindeki 'aapt' gerekli.${NC}"
fi

echo ""
echo -e "${GREEN}${BOLD}====================================================${NC}"
echo -e "${GREEN}${BOLD}   🎉 Tebrikler! Yükleme Başarıyla Tamamlandı!      ${NC}"
echo -e "${GREEN}${BOLD}====================================================${NC}"
echo ""
read -p "Pencereyi kapatmak için [Enter] tuşuna basın..." _
