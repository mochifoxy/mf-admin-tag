# 👑 MF Admin Chat Tags Ultra (v2.2)

[![AMX Mod X](https://img.shields.io/badge/AMX%20Mod%20X-1.9%20%7C%201.10-blue.svg)](https://www.amxmodx.org/)
[![ReAPI](https://img.shields.io/badge/ReAPI-Required-green.svg)](https://github.com/s1lentq/reapi)
[![Platform](https://img.shields.io/badge/Engine-ReHLDS%20%7C%20GoldSrc-orange.svg)](https://store.steampowered.com/app/10/CounterStrike/)
[![License](https://img.shields.io/badge/License-Non--Commercial-red.svg)](LICENSE)

Counter-Strike 1.6 (ReHLDS) sunucuları için geliştirilmiş, **ReAPI** destekli, ultra yüksek performanslı, **SteamID**, **ValveID (Non-Steam)**, **Botlar**, **Oyuncu İsmi (Nick)** ve **Admin Yetkilerine (@flag)** göre özelleştirilebilir, çökme (crash) korumalı gelişmiş sohbet tag sistemi.

> ⛔ **ÖNEMLİ LİSANS UYARISI:** Bu eklenti tamamen ücretsiz ve açık kaynaklıdır. Para karşılığı **SATILMASI**, ücretli paketlere dahil edilmesi veya **ticari amaçla kullanılması KESİNLİKLE YASAKTIR**.

---

## 📋 Sistem Gereksinimleri

* **Oyun Motoru:** ReHLDS & ReGameDLL (En güncel sürüm önerilir)
* **AMX Mod X:** v1.9 veya v1.10+
* **ReAPI:** Kurulu ve aktif olmalıdır (Doğrudan bellek seviyesinde takım ve oyuncu erişimi için)

---

## ✨ Özellikler

- 🛡️ **Tam Çökme Koruması (Anti-Crash):** CS 1.6 `SayText` ağ paketi taşmalarını (`SZ_GetSpace: overflow`) ve format exploit'lerini (`%` crash) %100 engelleyen dinamik kırpma motoru.
- 🎯 **SteamID, ValveID & Bot Desteği:** `STEAM_0:0:...`, `VALVE_0:4:...` (DProto/Reunion) ve sunucu içi botlar için yinelenmeyen otomatik kimlik doğrulaması.
- 🎨 **Özelleştirilebilir Baş ve Son Süslemeleri:** Tagın başındaki (örn: `{`, `[`, `<`, `*`, `#`) ve sonundaki (`}`, `]`, `>`, `*`, `#`) süslemeleri ve bu süslemelerin renklerini birbirinden ve tagdan **bağımsız** olarak belirleyebilme.
- 🌈 **Zengin Renk Paleti:** Yeşil (`1`), Kırmızı (`2`), Mavi (`3`), Sarı/Normal (`4`), Gri (`5`) ve Otomatik Takım Rengi (`6`).
- ⚡ **Yüksek Performans & Sıfır FPS/Lag Etkisi:** Hash tabanlı **Trie** veri yapısı ve izole task yönetimiyle sunucu tickrate/FPS değerini kesinlikle düşürmez.
- 🔄 **Canlı Yenileme (`amx_reloadtags`):** Sunucuya veya haritaya restart atmadan `admin_tags.ini` dosyasını anında yeniden yükleme.
- 💬 **Takım Sohbeti (`say_team`) Desteği:** `(Terrorist)`, `(Counter-Terrorist)`, `*OLU*` ve `*IZLEYICI*` durumlarını renkleri bozmadan kusursuz korur.

---

## 📦 Kurulum ve Derleme

Bu proje açık kaynaklıdır ve `.sma` kaynak kodu olarak sağlanır.

1. **Derleme:**
   * `mf_admin_tags.sma` dosyasını `include/reapi.inc` barındıran yerel AMX Mod X derleyicinizle (`amxxpc`) derleyerek `mf_admin_tags.amxx` dosyasını elde edin.
2. **Yükleme:**
   * Derlediğiniz `mf_admin_tags.amxx` dosyasını sunucunuzun `cstrike/addons/amxmodx/plugins/` dizinine yükleyin.
   * `cstrike/addons/amxmodx/configs/plugins.ini` dosyasını açıp en alta şu satırı ekleyin:
     ```ini
     mf_admin_tags.amxx
     ```
3. **Yapılandırma:**
   * `cstrike/addons/amxmodx/configs/admin_tags.ini` dosyasını oluşturup taglarınızı yapılandırın.
4. Haritayı değiştirin veya konsola `amx_reloadtags` yazın.

---

## ⚙️ Yapılandırma (`admin_tags.ini`)

Dosya Yolu: `addons/amxmodx/configs/admin_tags.ini`

### Format:
```ini
"SteamID/ValveID/Nick/@Yetki" "Tag Metni" "Tag Rengi" "Yazi Rengi" "Isim Rengi" "Bas Susleme" "Bas Renk" "Son Susleme" "Son Renk"
```

### Renk Tablosu:
| Kod | Renk Adı | Açıklama |
| :---: | :---: | :--- |
| **`1`** | **Yeşil** | Klasik AMX Mod X yeşil rengi (`\x04`) |
| **`2`** | **Kırmızı** | Terörist takım rengi (`\x03`) |
| **`3`** | **Mavi** | Counter-Terrorist takım rengi (`\x03`) |
| **`4`** | **Sarı / Normal** | Standart sarı sohbet rengi (`\x01`) |
| **`5`** | **Gri** | Spectator/İzleyici açık gri rengi (`\x03`) |
| **`6`** | **Takım Rengi** | Oyuncunun kendi takımına göre otomatik renk (`\x03`) |

---

### 📝 Örnek Yapılandırma

```ini
; =======================================================================================================
;                                MF ADMIN TAGS ULTRA YAPILANDIRMASI
; =======================================================================================================
; "Kimlik/Nick/@Yetki" "Tag"     "TagRengi" "YaziRengi" "IsimRengi" "BasSusleme" "BasRenk" "SonSusleme" "SonRenk"

; Örnek 1: Steam Kurucu -> Baş { (Sarı 4), Tag KURUCU (Kırmızı 2), Son } (Sarı 4), İsim Kırmızı (2), Yazı Yeşil (1)
"STEAM_0:0:123456"     "KURUCU"   "2"        "1"         "2"         "{"          "4"       "}"          "4"

; Örnek 2: Non-Steam/Valve Admin -> Baş [ (Yeşil 1), Tag ADMIN (Yeşil 1), Son ] (Yeşil 1), İsim Mavi (3), Yazı Sarı (4)
"VALVE_0:4:987654"     "ADMIN"    "1"        "4"         "3"         "["          "1"       "]"          "1"

; Örnek 3: Özel Nick -> Baş ve Son [ ] Kırmızı (2), Tag YONETICI Kırmızı (2), İsim Yeşil (1)
"MochiFoxy"            "YONETICI" "2"        "4"         "1"         "["          "2"       "]"          "2"

; Örnek 4: Süslemesiz Kalpli Tag -> Mochi (Kırmızı 2), Kalp (Yeşil 1), İsim Sarı (4), Yazı Yeşil (1)
"Queen"                "Mochi"    "2"        "1"         "4"         ""           "0"       " <3"        "1"

; Örnek 5: @d Yetkisi (ADMIN_BAN) -> Baş ve Son Gri (5), Tag VIP Gri (5), İsim Sarı (4), Yazı Yeşil (1)
"@d"                   "VIP"      "5"        "1"         "4"         "{"          "5"       "}"          "5"

; Örnek 6: @c Yetkisi -> Süslemesiz Sade Yeşil Tag
"@c"                   "KOMUTAN"  "1"        "1"         "4"         ""           "0"       ""           "0"
```

---

## 🛠️ Konsol Komutları

| Komut | Yetki | Açıklama |
| :--- | :---: | :--- |
| `amx_reloadtags` | `ADMIN_RCON` (`l` bayrağı) | `admin_tags.ini` dosyasını sunucuyu yeniden başlatmadan anında yeniden yükler. |

---

## 📜 Lisans

Bu proje **Ticari Olmayan Yazılım Lisansı (Non-Commercial Software License)** ile lisanslanmıştır. Bireysel CS 1.6 sunucularında ücretsiz olarak kullanılabilir; ancak **satışı ve ticari dağıtımı yasaktır**. Detaylar için [LICENSE](LICENSE) dosyasına bakınız.

---

## 👤 Geliştirici

* **Yazar:** MochiFoxy
* **Sürüm:** 2.2
* **GitHub:** [mochifoxy/mf-admin-tag](https://github.com/mochifoxy/mf-admin-tag)
