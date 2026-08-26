// Pano (kanban) mekanizmasi — surukle-birak VE klavye ile kart tasima.
// Cerceve yok, vanilla JS (razor-conventions.md).
//
// NEDEN BU DOSYA VAR (3 olculmus kusur, 2026-08-26 Solum'a raporlandi):
//   1. Eski hali bes SATIR ICI olay isleyicisi kullaniyordu (ondragover,
//      ondrop, ondragstart...). CSP yazilacagi gun unsafe-inline gerektirirdi.
//      Burada hepsi addEventListener.
//   2. KLAVYE YOLU YOKTU — surukle-birak tek yoldu. Kendi
//      screen-ux-standard.md §10 kuralimiz "fare olmadan uctan uca" diyor,
//      yani ekran kendi kuralimizi ihlal ediyordu. Alt+Sol/Sag ile tasima.
//   3. Basaridan sonra location.reload() vardi: tek kart icin bes kolon ve
//      butun KPI'lar yeniden cekiliyordu. Artik DOM dugumu tasiniyor,
//      yalniz sayaclar guncelleniyor.
//
// POLITIKA BURADA DEGIL: hedef adres, durum kodlari ve gecisin mesru olup
// olmadigi sunucudan gelir (data-* nitelikleri + API yaniti).
(function () {
    "use strict";

    var SURUKLENEN = "argusBoardCardId";

    function pano(el) { return el ? el.closest("[data-argus-board]") : null; }
    function kolonlar(board) { return Array.prototype.slice.call(board.querySelectorAll("[data-argus-column]")); }

    // Kolon sayaci ve bos durum metni her tasimadan sonra guncellenir —
    // sayac yanlis kalirsa kullanici yanlis is yuku okur.
    function sayaclariYenile(board) {
        kolonlar(board).forEach(function (kolon) {
            var liste = kolon.querySelector("[data-argus-list]");
            var kart = liste ? liste.querySelectorAll("[data-argus-card]").length : 0;
            var sayac = kolon.querySelector("[data-argus-count]");
            if (sayac) sayac.textContent = String(kart);

            var bos = kolon.querySelector("[data-argus-empty]");
            if (bos) bos.hidden = kart > 0;
        });
    }

    function bildir(board, mesaj, tur) {
        var toast = document.getElementById("argusToast");
        if (!toast) return;
        toast.textContent = mesaj;
        toast.className = "argus-toast" + (tur ? " argus-toast-" + tur : "");
        toast.hidden = false;

        // clearTimeout KOSULSUZ: eskiden yalniz "tur" doluyken temizlenirdi,
        // yani basarili tasimadan 1 sn sonra baslayan ikinci tasimanin
        // "Durum degistiriliyor..." yazisi ONCEKI basarinin 3,5 sn'lik
        // zamanlayicisiyla is UCARKEN gizleniyordu. Yavas baglantida kullanici
        // hicbir sey olmadigini sanip tekrar tikliyordu (denetim bulgusu 2.6).
        window.clearTimeout(toast._zaman);
        if (tur) {
            toast._zaman = window.setTimeout(function () { toast.hidden = true; }, 3500);
        }
    }

    // Basarili tasimadan sonra ustteki KPI bandi SUNUCU GERCEGINDEN AYRISIR:
    // kolon sayaclari guncellenir ama "Acik bulgu" / "SLA geciken" eski deger
    // kalir. Eskiden location.reload() bunu ortuyordu; kaldirilinca iki gercek
    // yan yana kaldi ve hangisinin dogru oldugunu soyleyen hicbir sey yoktu
    // (denetim bulgusu 3.2). Artik ozet BAYAT olarak isaretlenir.
    function ozetiBayatIsaretle() {
        var uyari = document.querySelector("[data-argus-summary-stale]");
        if (uyari) uyari.hidden = false;
    }

    // Tek tasima yolu: hem surukleme hem klavye burayi cagirir.
    async function tasi(board, kart, hedefKolon) {
        if (!kart || !hedefKolon) return;
        var kaynak = kart.closest("[data-argus-column]");
        if (kaynak === hedefKolon) return;

        // YARIS KILIDI (denetim bulgusu 2.3): DOM ancak yanit dondukten sonra
        // guncellendigi icin iki hizli Alt+Sag ayni gecisi iki kez POST ediyordu.
        // Ikincisi SP'de "already in status" ile patliyor, kullanicinin ikinci
        // adimi kayboluyor ve aldigi mesaj nedenini soylemiyordu.
        if (kart.getAttribute("data-argus-busy") === "1") {
            bildir(board, "Bu kartın işlemi sürüyor, bekleyin.", null);
            return;
        }

        var url = board.getAttribute("data-argus-drop-url");
        var durum = hedefKolon.getAttribute("data-argus-column");
        var id = kart.getAttribute("data-argus-card");

        // Eskiden burada sessiz "return" vardi: isaretleme bozulursa Alt+Sag
        // hicbir sey yapmiyor, konsolda da iz kalmiyordu (bulgu 2.7).
        if (!url || !durum || !id) {
            bildir(board, "Kart taşınamadı: ekran tanımı eksik. Sayfayı yenileyin.", "bad");
            return;
        }

        kart.setAttribute("data-argus-busy", "1");
        bildir(board, "Durum değiştiriliyor…", null);

        var yanit = null;
        var veri = null;

        // TRY YALNIZ AG CAGRISINI SARIYOR. Eskiden appendChild/focus da icindeydi:
        // sunucu isi yaptiktan sonra bir DOM hatasi olusursa kullaniciya
        // "Baglanti hatasi. Durum degismedi." yaziyordu — DB'de kayit degismisti.
        // Yanlis mesajin en tehlikeli turu (denetim bulgusu 2.2).
        try {
            var adres = url + (url.indexOf("?") < 0 ? "?" : "&") +
                "dofId=" + encodeURIComponent(id) + "&newStatus=" + encodeURIComponent(durum);
            yanit = await fetch(adres, { method: "POST", credentials: "same-origin" });
            veri = await yanit.json().catch(function () { return null; });
        } catch (hata) {
            kart.removeAttribute("data-argus-busy");
            bildir(board, "Bağlantı hatası. Durum değişmedi.", "bad");
            return;
        }

        kart.removeAttribute("data-argus-busy");

        // Oturum dustuyse sorun gecisin mesruiyeti DEGIL — kullanici bunu
        // "kural izin vermedi" sanip tekrar deniyordu (bulgu 2.4).
        if (yanit.status === 401 || yanit.status === 403) {
            bildir(board, "Oturumunuz sona ermiş. Sayfayı yenileyip tekrar deneyin.", "bad");
            return;
        }

        // Sunucu "olmaz" derse DOM'a DOKUNULMAZ — kart yerinde kalir.
        // Aksi halde kullanici tasidigini sanip yanlis duruma guvenir.
        if (!yanit.ok || !veri || veri.success !== true) {
            bildir(board, (veri && veri.error) || "Geçiş yapılamadı.", "bad");
            return;
        }

        // Buradan asagisi TRY DISINDA: sunucu isi yapti, artik "durum degismedi"
        // demek yasak. Ekran guncellenemezse DOGRU mesaj verilir.
        var hedefListe = hedefKolon.querySelector("[data-argus-list]");
        if (!hedefListe) {
            bildir(board, "Durum değişti ama ekran güncellenemedi. Sayfayı yenileyin.", "warn");
            return;
        }

        hedefListe.appendChild(kart);
        sayaclariYenile(board);
        ozetiBayatIsaretle();
        if (typeof kart.focus === "function") kart.focus();
        bildir(board, "Durum güncellendi.", "good");
    }

    // ── Surukleme ────────────────────────────────────────────────────────
    document.addEventListener("dragstart", function (e) {
        var kart = e.target.closest("[data-argus-card]");
        if (!kart) return;
        e.dataTransfer.setData(SURUKLENEN, kart.getAttribute("data-argus-card"));
        e.dataTransfer.effectAllowed = "move";
        kart.setAttribute("aria-grabbed", "true");
    });

    document.addEventListener("dragend", function (e) {
        var kart = e.target.closest("[data-argus-card]");
        if (kart) kart.removeAttribute("aria-grabbed");
    });

    document.addEventListener("dragover", function (e) {
        var kolon = e.target.closest("[data-argus-column]");
        if (!kolon) return;
        e.preventDefault();
        kolon.classList.add("argus-board-column--over");
    });

    document.addEventListener("dragleave", function (e) {
        var kolon = e.target.closest("[data-argus-column]");
        if (kolon && !kolon.contains(e.relatedTarget)) {
            kolon.classList.remove("argus-board-column--over");
        }
    });

    document.addEventListener("drop", function (e) {
        var kolon = e.target.closest("[data-argus-column]");
        if (!kolon) return;
        e.preventDefault();
        kolon.classList.remove("argus-board-column--over");

        var board = pano(kolon);
        var id = e.dataTransfer.getData(SURUKLENEN);
        if (!board || !id) return;
        tasi(board, board.querySelector('[data-argus-card="' + id + '"]'), kolon);
    });

    // ── Klavye: Alt+Sol / Alt+Sag ────────────────────────────────────────
    document.addEventListener("keydown", function (e) {
        if (!e.altKey || (e.key !== "ArrowLeft" && e.key !== "ArrowRight")) return;
        var kart = document.activeElement ? document.activeElement.closest("[data-argus-card]") : null;
        if (!kart) return;

        var board = pano(kart);
        if (!board) return;

        e.preventDefault();
        var liste = kolonlar(board);
        var simdiki = liste.indexOf(kart.closest("[data-argus-column]"));
        var hedef = simdiki + (e.key === "ArrowRight" ? 1 : -1);

        // Uctan tasma sessizce yutulmaz — kullaniciya neden olmadigi soylenir.
        if (hedef < 0 || hedef >= liste.length) {
            bildir(board, e.key === "ArrowRight" ? "Son kolondasınız." : "İlk kolondasınız.", null);
            return;
        }
        tasi(board, kart, liste[hedef]);
    });
})();
