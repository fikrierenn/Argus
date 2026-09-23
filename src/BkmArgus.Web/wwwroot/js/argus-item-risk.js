// Denetim maddesi risk onizlemesi — yalniz /Audit/Items sayfasinda yuklenir.
//
// NEDEN AYRI DOSYA: bu davranis tek bir ekrana ait. Kabuk betigine
// (argus-shell.js) koymak her sayfaya tasitirdi; _Layout'a eklemek de
// oyle. Sayfa @section Scripts ile yalnizca burada cagiriyor.
//
// NEDEN SATIR ICI DEGIL: eski surumde iki input'ta oninput="updateRiskPreview()"
// vardi. Satir ici olay isleyicisi CSP yazildigi gun unsafe-inline gerektirir
// (TODO C11); depoda 27 tanesi zaten temizlenmisti, bu iki tanesi kalmisti.
//
// ESIK VE SINIF BURADA YOK: ikisi de sunucudan data-* ile geliyor. Eski
// surumde JS icinde "score >= 15 ise kirmizi" yaziyordu ve DB "<= 15 Medium"
// diyordu — ayni esigin iki kopyasi, biri yanlis. Tek kaynak: AuditView.
(function () {
    "use strict";

    var rozet = document.querySelector("[data-argus-risk-rozet]");
    if (!rozet) return;

    // Alanlar Solum'un <solum-field>'i tarafindan uretiliyor; ad uzerinden
    // bulunuyor cunku uretilen id bicimi Solum'un sozlesmesi degil.
    var olasilik = document.querySelector('[name="Input.Probability"]');
    var etki = document.querySelector('[name="Input.Impact"]');
    if (!olasilik || !etki) return;

    function sayi(alan) {
        var d = parseInt(alan.value, 10);
        return isNaN(d) ? 0 : d;
    }

    function guncelle() {
        var p = sayi(olasilik);
        var e = sayi(etki);
        var skor = p * e;

        rozet.textContent = p + " × " + e + " = " + skor;

        var esikKotu = parseInt(rozet.getAttribute("data-esik-kotu"), 10);
        var esikUyari = parseInt(rozet.getAttribute("data-esik-uyari"), 10);

        var sinif = skor >= esikKotu ? rozet.getAttribute("data-sinif-kotu")
                  : skor >= esikUyari ? rozet.getAttribute("data-sinif-uyari")
                  : rozet.getAttribute("data-sinif-iyi");

        if (sinif) rozet.className = sinif;
    }

    olasilik.addEventListener("input", guncelle);
    etki.addEventListener("input", guncelle);

    // Sayfa acilisinda CAGRILMIYOR: sunucu dogru degeri ve dogru sinifi
    // zaten basmis durumda. Burada tekrar hesaplamak, JS'in sunucuyla
    // ayni sonucu urettigini VARSAYMAK olurdu.
})();
