// Dar ekranda tabloyu KART duzenine cevirmek icin hucrelere etiket yazar.
//
// ┌─ BU DOSYA SILINMEK UZERE YAZILDI ──────────────────────────────────┐
// │ Solum'a T1 olarak bildirildi: `<td>`ye `data-solum-label` basmasi   │
// │ istendi. Geldigi gun bu dosya SILINIR ve davranis DEGISMEZ —        │
// │ asagidaki kod zaten once `data-solum-label`a bakiyor.               │
// └────────────────────────────────────────────────────────────────────┘
//
// NEDEN GEREKLI (olculdu 2026-09-22):
//   TableRenderer.cs:278 -> sb.Append(col.Numeric ? "<td class=\"solum-num\">" : "<td>");
//   Yani hucrede etiket YOK. CSS `td::before{content:attr(data-label)}` ile
//   kart duzeni kurmanin baska yolu yok; CSS-only cozum IMKANSIZ.
//
// NEDEN KART, YATAY KAYDIRMA DEGIL:
//   /Risk 375px -> tablo 673px (7 kolon), sayfa 137px tasiyor. 7-11 kolonlu
//   denetim tablosunda yatay kaydirma, sahadaki denetcinin bir kaydin
//   TAMAMINI gormesini engeller. `screen-ux-standard` §11 yatay kaydirma
//   diyor; ayrildim ve gerekcesi plan 07'de yazili.
//
// GERI CEKILME: etiketleme basarisiz olursa `argus-cards` sinifi EKLENMEZ,
// tablo `.solum-table-wrap` icinde yatay kaydirmaya duser. Yani kotu durumda
// bugunku davranis korunur, bozuk kart uretilmez.
(function () {
    "use strict";

    // Kart duzenine gecis genisligi. CSS'teki `@media (max-width: 640px)` ile
    // AYNI olmak zorunda; ikisi ayrisirsa etiketsiz kart ya da etiketli tablo
    // cikar. Tek kaynak yapmak icin CSS degiskeni okunuyor.
    function kartEsigi() {
        var deger = getComputedStyle(document.documentElement)
            .getPropertyValue("--argus-kart-esigi");
        var sayi = parseInt(deger, 10);
        return isNaN(sayi) ? 640 : sayi;
    }

    function etiketle(tablo) {
        var basliklar = Array.prototype.map.call(
            tablo.querySelectorAll("thead th"),
            function (th) { return th.textContent.trim(); });

        // Baslik yoksa kart duzeni ANLAMSIZ — etiketsiz kart, kolon adi
        // olmayan bir yigin demek. Yatay kaydirmaya birakiliyor.
        if (basliklar.length === 0) return false;

        var satirlar = tablo.querySelectorAll("tbody tr");
        var yazildi = false;

        Array.prototype.forEach.call(satirlar, function (tr) {
            Array.prototype.forEach.call(tr.children, function (td, i) {
                // Solum kendi etiketini basmaya baslarsa ona DOKUNMA.
                if (td.hasAttribute("data-solum-label")) {
                    yazildi = true;
                    return;
                }
                var ad = basliklar[i];
                if (!ad) return;
                td.setAttribute("data-label", ad);
                yazildi = true;
            });
        });

        return yazildi;
    }

    function kur() {
        var tablolar = document.querySelectorAll(".solum-table");

        Array.prototype.forEach.call(tablolar, function (tablo) {
            if (!etiketle(tablo)) return;

            // Kart duzenini ACAN sinif sarmalayiciya konuyor: CSS yalniz
            // etiketleme BASARILI olduysa devreye girer.
            var sarmal = tablo.closest(".solum-table-wrap") || tablo.parentElement;
            if (sarmal) sarmal.classList.add("argus-cards");
        });
    }

    // Genislik degisince yeniden kurmaya GEREK YOK: etiketler her genislikte
    // duruyor, gorunumu CSS medya sorgusu karariyor. Tek sefer yeter.
    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", kur);
    } else {
        kur();
    }

    // Esik degeri disaridan okunabilsin (smoke olcumu icin).
    window.ArgusTabloMobil = { esik: kartEsigi };
})();
