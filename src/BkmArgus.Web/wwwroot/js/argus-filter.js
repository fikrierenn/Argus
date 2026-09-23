// Suzgec paneli — dar ekranda KAPALI acilir (plan 07, Faz 4).
//
// KATLAMAYI BU DOSYA YAPMAZ, <details> yapar. Buradaki tek is "ilk halde
// acik mi kapali mi" sorusunu ekran genisligine gore cevaplamak — sunucu
// genisligi bilemez, CSS de <details>'i kapatamaz (open bir nitelik).
//
// JS YUKLENMEZSE: panel ACIK kalir, yani bugunku davranis. Suzgec kaybolmaz,
// yalnizca yer kaplar; CSS'teki order kurali onu dar ekranda listenin ustune
// zaten almistir. Kademeli bozulma bilincli.
//
// SAYFA BASINA BIR KEZ: genislik sonradan degisirse (tablet donmesi, pencere
// boyutlandirma) panele DOKUNULMAZ. Kullanicinin actigi paneli ekran dondu
// diye kapatmak, kullanicinin kararini ezmektir.
(function () {
    "use strict";

    // CSS'teki .argus-split kirilma noktasiyla AYNI olmak ZORUNDA: panel o
    // noktada listenin ustune geciyor. Ikisi ayrilirsa arada kalan
    // genisliklerde panel hem altta hem acik olur — duzeltilmek istenen
    // kusurun ta kendisi.
    var DAR = "(max-width: 1100px)";

    function uygula() {
        if (!window.matchMedia || !window.matchMedia(DAR).matches) return;

        var paneller = document.querySelectorAll("details[data-argus-filter]");
        for (var i = 0; i < paneller.length; i++) {
            paneller[i].open = false;
        }
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", uygula);
    } else {
        uygula();
    }
})();
