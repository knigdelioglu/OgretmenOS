#!/usr/bin/env bash
# ==============================================================================
# Flutter iPhone Kablosuz Derleme ve Dağıtım Scripti
# ==============================================================================
# İlk eşleştirme Xcode üzerinden USB ile yapılmalıdır. Sonrasında iPhone ve Mac
# aynı Wi-Fi ağındaysa Flutter/Xcode cihazı kablosuz olarak keşfedebilir.

set -u

# Scriptin bulunduğu klasöre git (Flutter proje kökü)
cd "$(dirname "$0")" || exit 1

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}====================================================${NC}"
echo -e "${BLUE}${BOLD}   Flutter iPhone Kablosuz Dağıtım Aracı            ${NC}"
echo -e "${BLUE}${BOLD}====================================================${NC}"
echo ""

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo -e "${RED}❌ iPhone dağıtımı yalnızca macOS ve Xcode ile çalışır.${NC}"
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo -e "${RED}❌ 'flutter' komutu bulunamadı.${NC}"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo -e "${RED}❌ 'python3' komutu bulunamadı; cihaz keşfi için gereklidir.${NC}"
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo -e "${RED}❌ Xcode komut satırı araçları bulunamadı.${NC}"
  exit 1
fi

# Flutter proje kökünde iOS runner yoksa yalnızca iOS platformunu oluştur.
if [[ ! -d "ios" ]]; then
  echo -e "${CYAN}🛠️ iOS proje dosyaları bulunamadı, oluşturuluyor...${NC}"
  flutter create --platforms=ios --no-pub . || {
    echo -e "${RED}❌ iOS proje dosyaları oluşturulamadı.${NC}"
    exit 1
  }
fi

echo -e "${CYAN}🔍 Eşleştirilmiş iPhone aranıyor...${NC}"

# Flutter'ın makine çıktısından fiziksel iOS cihazının UDID'sini al.
# Böylece IP, bundle ID veya cihaz adı projeye sabitlenmez.
DEVICE_ID=$(flutter devices --machine 2>/dev/null | python3 -c '
import json
import sys

try:
    devices = json.load(sys.stdin)
except (json.JSONDecodeError, UnicodeDecodeError):
    sys.exit(1)

for device in devices:
    platform = str(device.get("targetPlatform", "")).lower()
    if platform.startswith("ios") and not device.get("emulator", False):
        device_id = device.get("id")
        if device_id:
            print(device_id)
            break
')

if [[ -z "$DEVICE_ID" ]]; then
  echo -e "${YELLOW}⚠️ Eşleştirilmiş fiziksel iPhone bulunamadı.${NC}"
  echo ""
  echo "İlk kullanım için:"
  echo " • iPhone'u USB ile Mac'e bağlayın ve iPhone'da 'Güven' seçeneğini onaylayın."
  echo " • Xcode > Window > Devices and Simulators bölümünden iPhone'u eşleştirin."
  echo " • Xcode'da cihaz için 'Connect via network' seçeneğini etkinleştirin."
  echo " • iPhone'da Developer Mode'u açın ve Mac ile aynı Wi-Fi ağına bağlanın."
  echo ""
  echo "Eşleştirme tamamlandıktan sonra bu scripti tekrar çalıştırın."
  exit 1
fi

echo -e "${GREEN}✅ iPhone bulundu: ${BOLD}${DEVICE_ID}${NC}"

echo -e "${BLUE}📦 Release sürümü derleniyor ve iPhone'a yükleniyor...${NC}"

if flutter run --release --no-resident -d "$DEVICE_ID"; then
  echo ""
  echo -e "${GREEN}${BOLD}====================================================${NC}"
  echo -e "${GREEN}${BOLD}   🎉 iPhone'a yükleme başarıyla tamamlandı!        ${NC}"
  echo -e "${GREEN}${BOLD}====================================================${NC}"
else
  echo ""
  echo -e "${RED}❌ iPhone'a yükleme başarısız oldu.${NC}"
  echo -e "${YELLOW}İmzalama, provisioning, Developer Mode ve Xcode cihaz eşleştirmesini kontrol edin.${NC}"
  exit 1
fi
