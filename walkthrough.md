# Evrensel WoW Cooldown Takip Mantığı ve Algoritma Referansı

Bu döküman, **herhangi bir WoW eklentisine** entegre edilebilecek, bağımsız ve modüler cooldown takip algoritmalarını içerir. Hedef; bir AI modelinin (Gemini vb.) bu mantığı kopyalayıp, var olan bir projeye ("WeakAuras", "Bartender" veya özel bir script) hatasız uygulayabilmesidir.

---

## 1. Modül: "Secret Value" Korumalı Cooldown Okuma Mantığı
**Problem:** WoW 11.0+ sonrası `GetSpellCooldown` fonksiyonu artık sayı değil, üzerinde matematik işlem yapılamayan bir `DurationObject` döndürür.
**Çözüm:** Veriyi doğrudan okumak yerine, API'nin beklediği formatta "paslamak" veya `GetCooldownTimes()` ile milisaniyeye çevirmek gerekir.

### Algoritma: Güvenli Veri Çekme
Herhangi bir cooldown frame'ine (örneğin action button üzerindeki sayaç) veri basarken şu yapı kullanılmalıdır:

```lua
-- Fonksiyon: UpdateCooldownDisplay
-- Girdi: cooldownFrame (Frame), spellID (Number)
local function UpdateCooldownDisplay(cooldownFrame, spellID)
    local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
    
    if not cooldownInfo then 
        cooldownFrame:Hide()
        return 
    end

    -- YÖNTEM 1: Standart SetCooldown (Önerilen)
    -- Blizzard'ın kendi API'si DurationObject'i kabul eder.
    -- Bu yöntem en güvenli ve performanslı yoldur.
    cooldownFrame:SetCooldown(cooldownInfo.startTime, cooldownInfo.duration)
    
    -- YÖNTEM 2: Matematiksel Veri İhtiyacı Varsa (Sadece hesaplama için)
    -- Eğer kalan süreyi "sayı" olarak (örn: 5.4 sn) bilmemiz gerekiyorsa:
    local startMs, durationMs = cooldownFrame:GetCooldownTimes()
    local startSec = startMs / 1000
    local durationSec = durationMs / 1000
    
    if durationSec > 0 then
        cooldownFrame:Show()
    else
        cooldownFrame:Hide()
    end
end
```

---

## 2. Modül: Dinamik CDR (Cooldown Reduction) Tespiti
**Problem:** Bir yetenek bekleme süresindeyken (örn: 30 sn kaldı), bir proc (tetiklenme) sonucu aniden sıfırlanabilir veya süresi azalabilir. Standart eventler bunu bazen kaçırır.
**Çözüm:** "Zaman Sıçraması" (Time Jump) algoritması.

### Algoritma: Time Jump Analizi
Bu fonksiyon her `SPELL_UPDATE_COOLDOWN` olayında çalıştırılmalıdır. Mantık şudur: Eğer `startTime` (başlangıç zamanı) ileri bir tarihe (geleceğe) atladıysa, sistem "eski cooldownu sildi, yerine yeni (daha kısa) bir cooldown koydu" demektir.

```lua
-- Global veya Frame-Local saklanacak bir tablo
local spellHistory = {} 

-- Fonksiyon: DetectCDR
-- Girdi: spellID (Number)
-- Çıktı: True (Eğer CDR olduysa), False (Normal akış)
local function DetectCDR(spellID)
    local info = C_Spell.GetSpellCooldown(spellID)
    if not info or info.duration == 0 then return false end
    
    local oldStart = spellHistory[spellID] or 0
    local newStart = info.startTime

    -- EŞİK DEĞERİ (Threshold): 0.1 sn
    -- Küçük gecikmeleri (latency) elemek için tolerans.
    -- Eğer yeni başlangıç zamanı, eskisinden "belirgin şekilde" büyükse:
    if newStart > (oldStart + 0.1) then
        spellHistory[spellID] = newStart
        return true -- EVET! Bekleme süresi aniden değişti (Sıfırlandı veya Azaldı)
    end
    
    spellHistory[spellID] = newStart
    return false
end
```
**Kullanım Senaryosu:** `DetectCDR` true döndürdüğünde, UI üzerinde bir "Parlama" (Glow) efekti tetiklenir veya ses çalınır.

---

## 3. Modül: Aura (Buff) Eşleştirme ve Takip
**Problem:** Kullanıcı "Combustion" (Spell ID: 190319) yeteneğini takip etmek ister, ancak oyun içinde bu yetenek kullanıldığında oyuncuya gelen Buff ID'si farklıdır.
**Çözüm:** Çift Katmanlı Kontrol (Dual-Lookup).

### Algoritma: Akıllı Aura Bulucu
Sadece Spell ID ile değil, o Spell'in yarattığı Aura ID ile de tarama yapmak gerekir.

```lua
-- Manuel Eşleştirme Tablosu (Gerektiğinde güncellenir)
local SPELL_TO_AURA = {
    [190319] = 190319, -- Combustion (Genelde aynıdır ama değişebilir)
    [102401] = 54817,  -- Wild Charge (Örnek: Spell ID != Aura ID)
}

-- Fonksiyon: FindActiveAura
-- Girdi: unit ("player"), spellID (Number)
-- Çıktı: auraData (Table) veya nil
local function FindActiveAura(unit, spellID)
    -- 1. ADIM: Manuel tablodan Aura ID'yi al
    local auraID = SPELL_TO_AURA[spellID] or spellID
    
    -- 2. ADIM: C_UnitAuras ile performanslı tarama
    -- "HELPFUL" (Buff) filtrelemesi, gereksiz Debuff taramasını engeller.
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura then break end -- Liste bitti
        
        if aura.spellId == auraID then
            return aura -- Bulundu!
        end
    end
    
    return nil -- Bulunamadı
end
```

---

## 4. Modül: Pixel Perfect Glow (Parlama) Matematiği
**Problem:** Hazır "Glow" kütüphaneleri (LibButtonGlow vb.) bazen ağırdır veya istenen "kare etrafında dönen nokta" efektini vermez.
**Çözüm:** Saf Lua Matematiği ile Çerçeve Gezintisi.

### Algoritma: 2D Çevre Gezintisi (Perimeter Traversal)
Bu kod bir `OnUpdate` (her karede çalışan) script içine yazılır.

```lua
-- Değişkenler (Closure veya self tablosunda saklanmalı)
local position = 0 -- 0 ile 1 arası (0 = Başlangıç, 1 = Tam Tur)
local speed = 0.5 -- Tur başına saniye (Hız)

-- Fonksiyon: UpdateGlowPosition
-- Girdi: frame (Frame), elapsed (Geçen süre - sn)
local function UpdateGlowPosition(frame, elapsed)
    local width, height = frame:GetSize()
    local perimeter = (width * 2) + (height * 2) -- Toplam çevre uzunluğu
    
    -- Pozisyonu ilerlet (Loop)
    position = position + (elapsed / speed)
    if position > 1 then position = position - 1 end
    
    -- 0-1 arasındaki değeri X,Y koordinatına çevir
    local currentDist = position * perimeter
    local x, y = 0, 0
    
    if currentDist < width then
        -- ÜST KENAR (Soldan Sağa)
        x = currentDist
        y = 0
    elseif currentDist < (width + height) then
        -- SAĞ KENAR (Yukarıdan Aşağı)
        x = width
        y = -(currentDist - width)
    elseif currentDist < (width * 2 + height) then
        -- ALT KENAR (Sağdan Sola)
        x = width - (currentDist - (width + height))
        y = -height
    else
        -- SOL KENAR (Aşağıdan Yukarı)
        x = 0
        y = -height + (currentDist - (width * 2 + height))
    end
    
    -- Glow dokusunu (texture) bu x,y noktasına taşı
    frame.glowTexture:SetPoint("CENTER", frame, "TOPLEFT", x, y)
end
```

---

## 5. Modül: Şarj (Charge) Tabanlı Gösterim
**Problem:** `2 Şarjı` olan bir yeteneğin sadece tek bir cooldown süresi yoktur. "Bir sonraki şarjın dolmasına kalan süre" gösterilmelidir.
**Çözüm:** `GetSpellCharges` API entegrasyonu.

### Algoritma: Şarj Öncelikli Gösterim

```lua
-- Fonksiyon: GetRechargeInfo
-- Girdi: spellID (Number)
-- Çıktı: startTime, duration, currentCharges, maxCharges
local function GetRechargeInfo(spellID)
    local charges = C_Spell.GetSpellCharges(spellID)
    
    if charges then
        -- Eğer şarj sistemi varsa, o an dönen şarjın süresini döner
        if charges.currentCharges < charges.maxCharges then
            return charges.cooldownStartTime, charges.cooldownDuration, charges.currentCharges, charges.maxCharges
        else
            -- Şarjlar dolu, bekleme süresi yok
            return 0, 0, charges.maxCharges, charges.maxCharges
        end
    else
        -- Şarjlı bir yetenek değil, normal Cooldown bakılır
        local cd = C_Spell.GetSpellCooldown(spellID)
        local onCD = (cd and cd.duration > 0)
        return cd.startTime, cd.duration, (onCD and 0 or 1), 1
    end
end
```

---

## 6. Özet Entegrasyon Listesi (Checklist)

Bu algoritmaları başka bir projeye eklerken şu sırayı izleyin:

1.  [ ] **Event Listener:** `SPELL_UPDATE_COOLDOWN` olayını dinle.
2.  [ ] **Veri Çekme:** Tetiklendiğinde `GetRechargeInfo` (Modül 5) çalıştır.
3.  [ ] **CDR Kontrolü:** Eğer bekleme süresi varsa `DetectCDR` (Modül 2) ile kontrol et.
4.  [ ] **Görsel:** Sonuçları `UpdateCooldownDisplay` (Modül 1) ile ekrana bas.
5.  [ ] **Aura (Opsiyonel):** Eğer kullanıcı aktif buff'ı da görmek istiyorsa `UNIT_AURA` olayında `FindActiveAura` (Modül 3) çalıştır.

Bu yapı, herhangi bir UI kütüphanesinden (Ace3, LibSharedMedia vb.) bağımsızdır ve saf WoW API üzerine kuruludur.





DÜZ ANLATIM


Nihai Teknik Referans: Gelişmiş WoW Cooldown Takip Mimarisi
Bu döküman, CooldownCompanion gibi yüksek performanslı ve modern bir WoW eklentisinin nasıl geliştirileceğini A'dan Z'ye açıklar. İçerik, WoW API'sinin en derin kısıtlamalarını (Secret Values), olay yönetimini, matematiksel görsel hesaplamaları ve performans optimizasyonlarını kapsar. Hiçbir detay atlanmamıştır.
________________________________________
Bölüm 1: Temel Mimari ve Çalışma Prensibi
Modern WoW eklentileri, olay tabanlı (event-driven) ve zamanlayıcı tabanlı (ticker-based) hibrid bir yapı kullanmalıdır. Sadece olaylara güvenmek yetersiz kalır (özellikle dinamik CD azalmalarında), sadece zamanlayıcı kullanmak ise performans kaybıdır.
1.1 Veri Akış Şeması
Aşağıdaki diyagram, oyun motorundan gelen verinin UI (Kullanıcı Arayüzü) katmanına nasıl aktığını gösterir.
Kullanıcı ArayüzüEklenti ÇekirdeğiOyun MotoruTetiklerTetiklerTetiklerKontrol EderEvetVeri ÇekerGüncellerGüncellerTetiklerSPELL_UPDATE_COOLDOWNUNIT_AURASPELL_UPDATE_CHARGESC_Spell APIDirty Flag?0.1s Ticker LoopCharge & Aura CacheYetenek SimgesiCooldown AnimasyonuPixel Glow Efekti
1.2 "Dirty Flag" Optimizasyonu
Her olayda (Event) tüm hesaplamaları yapmak yerine, olaylar sadece bir "Kirli" (Dirty) bayrağını işaretler. Asıl hesaplama 0.1 saniye sonra çalışan Ticker döngüsünde yapılır. Bu, "Event Storm" (aynı anda yüzlerce olayın tetiklenmesi) durumunda FPS düşüşünü engeller.
Örnek Kod:
lua
-- Olay Geldiğinde
function Addon:MarkDirty()
    self.isDirty = true
end
-- 0.1s Zamanlayıcı Döngüsü
C_Timer.NewTicker(0.1, function()
    if self.isDirty then
        self:UpdateAllButtons() -- Tüm butonları tek seferde güncelle
        self.isDirty = false
    end
end)
________________________________________
Bölüm 2: "Secret Value" (Gizli Değer) Yönetimi (WoW 12.0+)
WoW 12.0 ile birlikte, bekleme süreleri (Cooldown Duration) Protected (Korumalı) hale geldi. Yani GetSpellCooldown artık bir sayı (örneğin 12.5 saniye) döndürmez, bunun yerine özel bir DurationObject döndürür. Bu nesneyle matematiksel işlem yapılamaz (duration + 5 hata verir).
2.1 Çözüm: DurationObject Pass-Through
Eklenti, DurationObject'i görür görmez, hiç dokunmadan doğrudan SetCooldown fonksiyonuna iletir.
lua
local durationObj = C_Spell.GetSpellCooldownDuration(spellID)
if durationObj then
    -- HATA: print(durationObj) -> Protected Memory Access!
    -- DOĞRU: Doğrudan API'ye ver
    cooldownFrame:SetCooldownFromDurationObject(durationObj)
end
2.2 Çözüm: Scratch Frame (Okuma Hilesi)
Eğer matematiksel bir işlem (örneğin CDR hesabı) için o sürenin kaç saniye olduğunu mutlaka bilmemiz gerekiyorsa, görünmez bir çerçeve (Scratch Frame) kullanırız.
Teknik Detay: SetCooldown fonksiyonu DurationObject'i kabul eder ve kendi içindeki C++ tarafında bunu işlemeye başlar. GetCooldownTimes() fonksiyonu ise, o anki durumu milisaniye (sayı) olarak geri döndürür. Bu, korumayı aşmanın tek yoludur.
lua
-- Görünmez bir "Çöp Kutusu" çerçevesi yarat
local scratch = CreateFrame("Cooldown", nil, UIParent, "CooldownFrameTemplate")
function GetRealSeconds(durationObj)
    -- 1. Gizli nesneyi çerçeveye yükle
    scratch:SetCooldownFromDurationObject(durationObj)
    
    -- 2. Çerçeveden "işlenmiş" zamanı geri oku (Milisaniye döner)
    local startMs, durationMs = scratch:GetCooldownTimes()
    
    -- 3. Saniyeye çevir ve döndür
    return startMs / 1000, durationMs / 1000
end
________________________________________
Bölüm 3: Dinamik Bekleme Süresi Azalması (CDR) ve Şarj (Charge) Takibi
Bazı yeteneklerin bekleme süresi, kritik vuruşlar veya proc'lar ile aniden azalabilir (Örn: Mage Icy Veins). Bunu tespit etmek için "Zaman Sıçraması" (Time Jump) algoritması kullanılır.
3.1 Zaman Sıçraması Mantığı
Normalde bir bekleme süresinin startTime (başlangıç zamanı) sabittir. Eğer startTime aniden ileri bir zamana (geleceğe) kayarsa, bu şu anlama gelir: "Eski bekleme süresi bitti, yerine yeni (daha kısa) bir bekleme süresi başladı."
CDR Proc GeldiSıçrama!Zaman 10.0sZaman 10.1sEski Start: 0.0sYeni Start: 5.0sAlgıla: Start Değişti!Şarj Sayısını Artır
3.2 Şarj Takip Kodu (Örnek)
lua
function Addon:CheckChargeJump(button, newStart)
    -- Önceki başlangıç zamanı ile yenisini kıyasla
    if button.prevStart and newStart > (button.prevStart + 0.5) then
        -- Yarım saniyeden büyük bir sıçrama var!
        -- Bu, bir şarjın aniden dolduğu anlamına gelir.
        button.chargeCount = button.chargeCount + 1
        print("CDR Tespit Edildi! Şarj Eklendi.")
    end
    button.prevStart = newStart
end
________________________________________
Bölüm 4: Buff ve Aura Eşleştirme Sistemi
WoW'da yetenek ID'si ile o yeteneğin verdiği Buff ID'si genellikle farklıdır. Örneğin, Druid Solar Eclipse yeteneği (ID: 123) oyuncuya Eclipse (Solar) buff'ı (ID: 48517) verir. Eklenti bu ikisini nasıl eşleştirir?
4.1 "Mapping" Tablosu
Manuel bir eşleştirme tablosu kullanılır. Bu tablo, yetenek ID'sini alıp buff ID'sini döndürür.
lua
Addon.ABILITY_BUFF_OVERRIDES = {
    [1233346] = "48517,48518", -- Güneş Tutulması -> Güneş veya Ay Buff'ı
    [1233272] = "48517,48518", -- Ay Tutulması -> Güneş veya Ay Buff'ı
}
function ResolveAura(abilityID)
    -- 1. Önce tablodan bak
    local override = Addon.ABILITY_BUFF_OVERRIDES[abilityID]
    if override then return override end
    -- 2. Yoksa Blizzard'ın ilişki fonksiyonunu dene
    local auraID = C_UnitAuras.GetCooldownAuraBySpellID(abilityID)
    if auraID ~= 0 then return auraID end
    -- 3. Bulamazsan yeteneğin kendi ID'sini buff ID sanarak dene
    return abilityID
end
4.2 Blizzard Cooldown Viewer "Scraping" (Veri Kazıma)
Blizzard'ın kendi arayüzü (CooldownFrame), hangi yeteneğin hangi buff ile takip edildiğini zaten bilir. Eklenti, bu "gizli bilgiyi" okumak için Blizzard çerçevelerini tarar.
lua
function Addon:BuildViewerMap()
    -- Blizzard'ın ana cooldown çerçevesini al
    local viewer = _G["EssentialCooldownViewer"]
    
    -- İçindeki tüm çocukları (child frames) gez
    for _, child in pairs({viewer:GetChildren()}) do
        if child.cooldownInfo then
            local spellID = child.cooldownInfo.spellID
            local auraData = child.auraInstanceID -- <-- GİZLİ VERİ BURADA!
            
            -- Bu bilgiyi kendi haritamıza kaydedelim
            self.ViewerMap[spellID] = auraData
        end
    end
end
________________________________________
Bölüm 5: Pixel Glow Matematiği
Pixel Glow efekti, bir karenin çevresinde dönen noktalar (partiküller) oluşturur. Bu, saf matematiksel bir simülasyondur.
5.1 Çevre Hesabı (Perimeter)
Bir karenin çevresi: 2 * (Genişlik + Yükseklik). Partikülün "konumu" (offset), 0 ile Çevre Değeri arasında bir sayıdır.
lua
local w, h = button:GetSize()
local perimeter = 2 * (w + h)
local speed = 60 -- Piksel/Saniye
-- Her karede (OnUpdate) konumu güncelle
self.offset = (self.offset + (elapsed * speed)) % perimeter
5.2 Koordinat Dönüşümü
0-Perimeter arasındaki tek boyutlu sayıyı, 2D (x, y) koordinatlarına çevirmek gerekir.
1.	Üst Kenar (0 - w): x = offset, y = 0
2.	Sağ Kenar (w - w+h): x = w, y = -(offset - w)
3.	Alt Kenar (w+h - 2w+h): x = w - (offset - (w+h)), y = -h
4.	Sol Kenar (2w+h - perimeter): x = 0, y = -(h - (offset - (2w+h)))
Bu matematik sayesinde, noktalar köşeleri "dönüyormuş" gibi görünür.
________________________________________
Bölüm 6: Performans ve "Taint" (Bulaşma) Koruması
Eklenti yazarken FPS düşüşünü ve arayüz hatalarını engellemek için şu kurallara mutlaka uyulmalıdır:
1.	Combatsız İşlem: Arayüz değişiklikleri (boyutlandırma, gizleme/gösterme) ASLA kombat sırasında yapılmamalıdır. Eklenti, OnCombatStart olayında konfigürasyon pencerelerini kapatır.
2.	Table Recycling (Tablo Geri Dönüşümü): Her karede local t = {} yapmak yerine, global bir reuseTable kullanıp iş bitince wipe(reuseTable) yapılmalıdır. Bu, "Garbage Collector" (Çöp Toplayıcı) kaynaklı takılmaları önler.
3.	Secure Templates: Tıklanabilir butonlar için SecureActionButtonTemplate kullanılmalıdır. CooldownCompanion, butonları bu şablondan türeterek Blizzard'ın güvenlik sistemine uyumlu kalır.
________________________________________
Sonuç
CooldownCompanion gibi bir eklenti, sadece API çağırmaktan ibaret değildir. Secret Value korumalarını aşmak, matematiksel animasyonlar çizmek ve oyun motorunun açıklarını (CDR jump tespiti gibi) kullanarak veri üretmek üzerine kuruludur.
10. Manuel Eşleştirme Tablosu (Mapping Tables)
Bazı yeteneklerin takibi için ID eşleştirmesi gerekir. Aşağıdaki tablo, 
mappings.lua dosyasından alınmış olup, yetenek ID'si ile buff ID'si arasındaki ilişkiyi gösterir.
Sınıf	Yetenek (Ability)	Yetenek ID	Takip Edilen Buff (Aura)	Buff ID	Notlar
Druid	Solar Eclipse	1233346	Eclipse (Solar) / (Lunar)	48517, 48518	İki tutulma da birbirini tetikler
Druid	Lunar Eclipse	1233272	Eclipse (Solar) / (Lunar)	48517, 48518	
Paladin	Avenging Wrath	31884	Avenging Wrath	31884	Genelde aynıdır
Mage	Icy Veins	12472	Icy Veins	12472	
Troll	Berserking	26297	Berserking	26297	Irk özelliği
Not: Bu tablonun Lua kodu halini 
mappings.lua dosyasında bulabilirsin. Kod içinde direkt require ederek kullanabilirsin.


