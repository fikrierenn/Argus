// Alt sayfa (bottom sheet) — dar ekranda alttan acilan secim katmani.
//
// NEDEN BIZDE (olculdu 2026-09-23, Solum'a T5 olarak soruldu):
//   Solum deposunda `solum-sheet` / `bottom-sheet` -> SIFIR eslesme, ve
//   planlarinda da yok. Cevaplari: "ucuncu tuketici olunca konusuruz, siz
//   yazin". Yani bu dosya BILEREK bizde; Solum bir gun ilkel cikarirsa
//   buradaki akis referans olur.
//
// NEDEN ALT SAYFA, AYRI SAYFA DEGIL:
//   Durum secimi panonun BAGLAMINDA yapilir. Ayri sayfaya gitmek panoyu
//   kaybettirir, geri donunce kaydirma konumu ve hangi karta dokunuldugu
//   gider. `screen-ux-standard` §10 "Esc = modal/panel kapat" zaten panel
//   kalibini taniyor.
//
// KAPSAM: yalniz "bir liste goster, biri secilsin". Form, sekme, ic ice
// sayfa YOK — ihtiyac dogmadan buyutulmez (footprint-ladder).
(function () {
    "use strict";

    var acikOlan = null;

    // Odagi sayfada birakmamak icin: alt sayfa acikken Tab disari cikmaz.
    // Erisilebilirlik gerekliligi (WAI-ARIA dialog kalibi); olmazsa ekran
    // okuyucu kullanicisi arkadaki panoda kaybolur.
    function odakTuzagi(kap, e) {
        if (e.key !== "Tab") return;
        var odaklanabilir = kap.querySelectorAll("button:not([disabled]), [href], [tabindex]:not([tabindex='-1'])");
        if (odaklanabilir.length === 0) return;

        var ilk = odaklanabilir[0];
        var son = odaklanabilir[odaklanabilir.length - 1];

        if (e.shiftKey && document.activeElement === ilk) {
            e.preventDefault();
            son.focus();
        } else if (!e.shiftKey && document.activeElement === son) {
            e.preventDefault();
            ilk.focus();
        }
    }

    function kapat() {
        if (!acikOlan) return;
        var kayit = acikOlan;
        acikOlan = null;

        document.removeEventListener("keydown", kayit.tusIsleyici, true);
        kayit.kap.remove();

        // Odak ACAN ogeye geri doner. Donmezse dokunmatikte sorun degil ama
        // klavye kullanicisi sayfanin basina atilir.
        if (kayit.acan && document.contains(kayit.acan) && typeof kayit.acan.focus === "function") {
            kayit.acan.focus();
        }
    }

    // secenekler: [{ etiket, deger, secili?, pasif?, ipucu? }]
    // onSec(deger) -> alt sayfa kapandiktan SONRA cagrilir; cagiran DOM'u
    // degistirecsekse acik bir katmanin altinda calismasin.
    function ac(ayar) {
        kapat();

        var baslikId = "argus-sheet-baslik";

        var kap = document.createElement("div");
        kap.className = "argus-sheet-kap";

        var perde = document.createElement("div");
        perde.className = "argus-sheet-perde";
        // Perde bir DUGME degil: ekran okuyucuda gezilecek bir sey yok,
        // kapatmanin erisilebilir yolu Esc ve "Vazgec" dugmesi.
        perde.setAttribute("aria-hidden", "true");
        perde.addEventListener("click", kapat);

        var govde = document.createElement("div");
        govde.className = "argus-sheet";
        govde.setAttribute("role", "dialog");
        govde.setAttribute("aria-modal", "true");
        govde.setAttribute("aria-labelledby", baslikId);

        var baslik = document.createElement("h2");
        baslik.className = "argus-sheet-baslik";
        baslik.id = baslikId;
        baslik.textContent = ayar.baslik || "Seçim";
        govde.appendChild(baslik);

        if (ayar.altBaslik) {
            var alt = document.createElement("p");
            alt.className = "argus-sheet-alt";
            alt.textContent = ayar.altBaslik;
            govde.appendChild(alt);
        }

        var liste = document.createElement("div");
        liste.className = "argus-sheet-liste";

        (ayar.secenekler || []).forEach(function (secenek) {
            var dugme = document.createElement("button");
            dugme.type = "button";
            dugme.className = "argus-sheet-oge" + (secenek.secili ? " argus-sheet-oge--secili" : "");
            dugme.textContent = secenek.etiket;

            if (secenek.ipucu) {
                var ipucu = document.createElement("span");
                ipucu.className = "argus-sheet-ipucu";
                ipucu.textContent = secenek.ipucu;
                dugme.appendChild(ipucu);
            }

            // Yapilamayacak secenek GIZLENMEZ, pasif gosterilir: kullanici
            // listede neyin olmadigini degil, neyin SU AN olmadigini gorur
            // (`screen-ux-standard` §7).
            if (secenek.pasif || secenek.secili) {
                dugme.disabled = true;
                if (secenek.secili) dugme.setAttribute("aria-current", "true");
            } else {
                dugme.addEventListener("click", function () {
                    kapat();
                    if (typeof ayar.onSec === "function") ayar.onSec(secenek.deger);
                });
            }

            liste.appendChild(dugme);
        });

        govde.appendChild(liste);

        var vazgec = document.createElement("button");
        vazgec.type = "button";
        vazgec.className = "solum-btn argus-sheet-vazgec";
        vazgec.textContent = "Vazgeç";
        vazgec.addEventListener("click", kapat);
        govde.appendChild(vazgec);

        kap.appendChild(perde);
        kap.appendChild(govde);
        document.body.appendChild(kap);

        var tusIsleyici = function (e) {
            if (e.key === "Escape") {
                e.preventDefault();
                kapat();
                return;
            }
            odakTuzagi(govde, e);
        };
        // capture: arkadaki pano da Alt+Ok dinliyor; alt sayfa acikken
        // o kisayol calismamali (iki farkli tasima ayni anda tetiklenirdi).
        document.addEventListener("keydown", tusIsleyici, true);

        // ACAN OGE: cagiran acikca versin, yoksa odaktaki oge. `activeElement`e
        // guvenmek YETMEZ — dokunmatikte buton tiklamasi bazi tarayicilarda
        // odak vermez, o zaman `acan` BODY olur ve kapaninca odak sayfanin
        // basina duser (olculdu 2026-09-23: kapandi ama odak BODY'de kaldi).
        acikOlan = { kap: kap, acan: ayar.acan || document.activeElement, tusIsleyici: tusIsleyici };

        // Ilk secilebilir ogeye odak; hicbiri yoksa Vazgec'e.
        var ilkAktif = liste.querySelector("button:not([disabled])") || vazgec;
        ilkAktif.focus();
    }

    window.ArgusSheet = { ac: ac, kapat: kapat };
})();
