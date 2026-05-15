<div align="center">
  <h1>✨ Admin Chat Tags Ultra ✨</h1>
  <p><i>Counter-Strike 1.6 için Gelişmiş, Yüksek Performanslı ve Özelleştirilebilir Sohbet Tag Eklentisi</i></p>
</div>

---

## 🌟 Özellikler

- 🚀 **Yüksek Performans (Caching):** Her mesajda listeyi baştan sona taramaz. Oyuncu sunucuya girdiğinde tagı belleğe alınır (O(1) performansı).
- 👑 **Gelişmiş Yetki Sistemi:** Tagları `SteamID`, `Nickname` veya **Yetki Harfi (Flag)** (`FLAG_d` vb.) üzerinden kolayca atayabilirsiniz.
- 🎨 **Tam Renk Kontrolü:** Tag rengini, isim rengini ve mesaj rengini birbirinden bağımsız olarak (Yeşil, Kırmızı, Mavi, Sarı) ayarlayabilirsiniz.
- 👻 **Orijinal Oyun Mantığı:** Ölü oyuncuların başına `*ÖLÜ*`, izleyicilerin başına `*İZLEYİCİ*` ekler. Ölülerin mesajlarını diriler göremez (orijinal CS 1.6 kuralı).
- 💬 **Gelişmiş Takım Sohbeti:** Takım konuşmalarında düz "(Team)" yerine dinamik olarak `(Terrorist)`, `(Counter-Terrorist)` veya `(Spectator)` yazar.
- 🛑 **Komut Gizleme Koruması:** `/` ve `.` ile başlayan, diğer eklentiler (ör: `/gag`, `.mute`) tarafından gizlenen komutları ifşa etmez.

---

## 📋 Gereksinimler

- 🧩 **AMX Mod X:** 1.8.3 veya üzeri
- ⚙️ **ReAPI:** Kurulu olmalıdır.

---

## 🛠️ Kurulum

1. `admin_tags.sma` dosyasını derleyin.
2. Çıkan `admin_tags.amxx` dosyasını sunucunuzun `cstrike/addons/amxmodx/plugins/` klasörüne atın.
3. `cstrike/addons/amxmodx/configs/plugins.ini` dosyasını açın.
4. **En alt satıra** `admin_tags.amxx` yazıp kaydedin. *(Gizli komutların ifşa olmaması için en altta olması zorunludur!)*
5. Sunucuyu yeniden başlatın veya harita değiştirin.

---

## ⚙️ Yapılandırma (`admin_tags.ini`)

Eklenti ilk çalıştığında `configs/admin_tags.ini` dosyasını otomatik olarak oluşturacaktır.

### 📝 Kullanım Şeması
```ini
"SteamID / Nick / FLAG_x"  "Tag Metni"  "Tag Rengi"  "Yazi Rengi"  "Isim Rengi"
```

### 🎨 Renk Kodları
| Kod | Renk Karşılığı | Açıklama |
| :---: | :--- | :--- |
| **1** | 🟢 Yeşil | Klasik admin yeşili |
| **2** | 🔴 Kırmızı | Terrorist takım rengi |
| **3** | 🔵 Mavi | Counter-Terrorist takım rengi |
| **4** | 🟡 Sarı / Beyaz | Varsayılan oyun içi renk |

> ⚠️ **Önemli:** CS 1.6 oyun motoru gereği, aynı mesajda hem Mavi hem de Kırmızı *kullanılamaz*. Eğer ikisi de seçilmişse, ilk renk kodu geçerli olur.

### 💡 Örnek Kullanımlar

```ini
; 1. Ozel Kullanicilar (Bunlari daima uste yazin)
"STEAM_0:0:12345678"   "👑 Kurucu"   "2" "1" "2"
"MochiFoxy"            "🌸 Support"  "1" "4" "3"

; 2. Genel Yetkiler (Bunlari alta yazin)
"FLAG_l"               "🛠️ Yonetici" "1" "1" "1"
"FLAG_d"               "🛡️ Admin"    "3" "1" "3"
"FLAG_b"               "🌟 VIP"      "1" "4" "1"
```

> 📌 **Önemli (Yetki Önceliği):** Eklenti listeyi **yukarıdan aşağıya** doğru okur ve eşleşen **ilk** tagı verir. 
> - Eğer bir oyuncunun birden fazla yetkisi varsa (örneğin hem `FLAG_l` hem `FLAG_d` yetkisi), dosyada **üstte** hangi yetki yazılıysa o tagı alır.
> - Bu yüzden tagları önem sırasına göre (en yetkiliden en az yetkiliye doğru) yukarıdan aşağıya doğru sıralamalısınız.
> - Ayrıca özel (SteamID/Nick) tanımlamaları daima genel yetkilerden (FLAG_x) **üstte** olmalıdır.

---
<div align="center">
  <p>Made with ❤️ by <b>MochiFoxy</b></p>
</div>
