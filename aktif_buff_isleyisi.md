# BuffForge Aktif Buff Toplama İşleyişi (Analiz)

Bu dosya, BuffForge addonunun (workign addon full versiyonu) aktif buffları nasıl topladığını ve işlediğini adım adım açıklar.

## Genel Strateji
Addon, geleneksel `UnitAura` taraması yapmak yerine Blizzard'ın 11.1.5 yamasıyla gelen **Viewer (İzleyici)** sistemini (Protected/Untainted frames) kullanır. Bu sayede Blizzard'ın "smart" (akıllı) takibini doğrudan kullanabilir.

---

## 1. Adım: İzleyici Haritasının Oluşturulması (Mapping)
`Core.lua` dosyasındaki `BuildViewerAuraMap` fonksiyonu, Blizzard'ın dahili çerçevelerini tarayarak hangi büyünün hangi çerçeve tarafından takip edildiğini bulur.

**Dosya:** `Core.lua`
```lua
function CooldownCompanion:BuildViewerAuraMap()
    wipe(self.viewerAuraFrames) -- Eski haritayı temizler
    for _, name in ipairs(VIEWER_NAMES) do -- Blizzard'ın viewer isimlerini döner
        local viewer = _G[name] -- Frame'i (EssentialCooldownViewer vb.) alır
        if viewer then
            for _, child in pairs({viewer:GetChildren()}) do -- Alt frame'leri (butonları) döner
                if child.cooldownInfo then
                    local spellID = child.cooldownInfo.spellID
                    -- Spell ID → Blizzard Frame eşleşmesini kaydeder
                    if spellID then 
                        self.viewerAuraFrames[spellID] = child 
                    end
                    -- Varsa override (dönüşmüş büyü) ID'lerini de kaydeder
                    local override = child.cooldownInfo.overrideSpellID
                    if override then self.viewerAuraFrames[override] = child end
                end
            end
        end
    end
end
```

---

## 2. Adım: Buton Güncellemede Aura Tespiti
Bir buton ekranda tazelenirken, `ButtonFrame.lua` içindeki `UpdateButtonCooldown` fonksiyonu çalışır.

**Dosya:** `ButtonFrame.lua` (Satır 1348 civarı)
### İşleyiş Sırası:
1.  **Haritadan Bulma:** Büyü ID'si ile haritadaki Blizzard frame'ine ulaşılır.
2.  **Instance ID Çıkarma:** Blizzard'ın frame'indeki `auraInstanceID` okunur.
3.  **Birim (Unit) Tespiti:** Takip edilen birim (`player` veya `target`) belirlenir.
4.  **Süre Alımı:** `C_UnitAuras.GetAuraDuration` API'si ile süresi okunur.

```lua
-- 1. Haritadan Blizzard'ın o büyü için oluşturduğu frame'i bulur
local viewerFrame = CooldownCompanion.viewerAuraFrames[buttonData.id]

if viewerFrame then
    -- 2. Blizzard'ın dahili olarak atadığı auraInstanceID'yi alır (En kritik nokta)
    local viewerInstId = viewerFrame.auraInstanceID
    
    if viewerInstId then
        -- 3. Hangi unit (oyuncu/hedef) üzerinde olduğunu belirler
        local unit = viewerFrame.auraDataUnit or auraUnit
        
        -- 4. Blizzard API'si ile bu eşsiz (unique) ID'den süre bilgisini çeker
        local ok, durationObj = pcall(C_UnitAuras.GetAuraDuration, unit, viewerInstId)
        
        if ok and durationObj then
            -- Frame üzerindeki cooldown animasyonuna bu süreyi gönderir
            button.cooldown:SetCooldownFromDurationObject(durationObj)
            auraOverrideActive = true
        end
    end
end
```

---

## 3. Adım: Özel Durumlar (Pandemic ve Glow)
Addon sadece süreyi almaz, aynı zamanda buff'ın yenilenme zamanını (**Pandemic**) ve parlama efektini (**Glow**) de Blizzard'ın kendi frame'lerinden çalar:

*   **Pandemic (Yenileme Aralığı):** Blizzard'ın frame'inde `PandemicIcon` görünürse addon bunu fark eder (`viewerFrame.PandemicIcon:IsVisible()`).
*   **Aura Glow:** Eğer büyü aktifse ve ayarlanmışsa butona özel çerçeveler (solid, pixel veya blizzard stili) ekler (`UpdateIconModeGlows`).

## Özet
Addon manuel olarak her saniye tüm buffları taramak (`UnitAura` looping) yerine, Blizzard'ın kendi UI elementlerinin arkasına sakladığı veriyi (`auraInstanceID`) kullanarak çok daha performanslı ve "akıllı" bir toplama işlemi gerçekleştirir.
