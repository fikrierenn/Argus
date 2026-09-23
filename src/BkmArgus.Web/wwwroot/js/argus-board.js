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
            // TEK POST YOLU: ArgusApi.post token basligini ve JSON govdeyi
            // kuruyor (plan 06 Faz 4). Parametreler artik sorgu dizesinde
            // DEGIL — sorgu dizesi tarayici gecmisine ve Referer'a yaziliyor.
            yanit = await window.ArgusApi.post(url, { dofId: parseInt(id, 10), newStatus: durum });
            veri = await yanit.json().catch(function () { return null; });
        } catch (hata) {
            kart.removeAttribute("data-argus-busy");
            bildir(board, "Bağlantı hatası. Durum değişmedi.", "bad");
            return;
        }

        kart.removeAttribute("data-argus-busy");

        // Oturum dustuyse ya da CSRF token'i bayatladiysa sorun gecisin
        // mesruiyeti DEGIL — kullanici bunu "kural izin vermedi" sanip tekrar
        // deniyordu (bulgu 2.4). 403 artik iki sey olabilir: yetki yok VEYA
        // token gecersiz; sunucu kendi Turkce metnini yaziyorsa o kullanilir,
        // cunku dogru tavsiye ("sayfayi yenile") ona bagli.
        if (yanit.status === 401 || yanit.status === 403) {
            bildir(board, (veri && veri.error) ||
                "Oturumunuz sona ermiş. Sayfayı yenileyip tekrar deneyin.", "bad");
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

        // Kart artik bir SARMALAYICI (baglanti + durum dugmesi); sarmalayici
        // odaklanamaz. Odak ic ogeye verilir, yoksa klavye kullanicisi
        // tasimadan sonra sayfanin basina duser.
        var odak = kart.matches("a, button") ? kart : kart.querySelector("a, button");
        if (odak && typeof odak.focus === "function") odak.focus();

        bildir(board, "Durum güncellendi.", "good");
    }

    // ── Surukleme ────────────────────────────────────────────────────────
    document.addEventListener("dragstart", function (e) {
        var kart = e.target.closest("[data-argus-card]");
        if (!kart) return;
        e.dataTransfer.setData(SURUKLENEN, kart.getAttribute("data-argus-card"));
        e.dataTransfer.effectAllowed = "move";

        // `aria-grabbed` SURUKLENEN ogede durur — sarmalayici <div> odaklanmaz
        // ve rolu yoktur, orada yazan durum ekran okuyucunun odaklandigi
        // dugumde GORUNMEZ. Gorsel sonmeyi CSS `:has()` ile sarmalayiciya
        // tasiyoruz (code-reviewer bulgusu, 2026-09-23).
        (e.target.closest(".argus-board-card-body") || kart)
            .setAttribute("aria-grabbed", "true");
    });

    document.addEventListener("dragend", function (e) {
        var kart = e.target.closest("[data-argus-card]");
        if (!kart) return;
        var tasinan = kart.querySelector("[aria-grabbed]") || kart;
        tasinan.removeAttribute("aria-grabbed");
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

    // ── Dokunmatik: durum secici alt sayfa ───────────────────────────────
    //
    // NEDEN UCUNCU BIR YOL (olculdu 2026-09-22):
    //   Bu dosyada `touchstart`/`pointerdown` sayisi SIFIRDI ve HTML5
    //   surukle-birak dokunmatikte `dragstart`i HIC atesliyor. Klavye yolu
    //   (Alt+Ok) masaustu icindi. Yani panoda telefondan durum degistirmenin
    //   HICBIR yolu yoktu. Solum kendi panosunda ayni korlugu olctu ve bunu
    //   kendi kusuru olarak kaydetti (`js-disiplini.md` §5 "fare olmadan"
    //   derken dokunmayi FARE sayiyormus).
    //
    // NEDEN SURUKLEME TAKLIDI YOK:
    //   `pointer` olaylariyla surukleme yazmak dokunmatikte sayfa
    //   kaydirmasiyla CAKISIR — denetci listeyi kaydirmaya calisirken kart
    //   tasir. Dokun -> sec hem kazasiz hem erisilebilir.
    //
    // NEDEN KARTIN KENDISI DEGIL AYRI DUGME:
    //   Kart bir `<a>`; dokunmak DETAYA gidiyor ve bu dogru davranis. O
    //   dokunusu calmak calisan bir yolu kirardi (orta tik, yeni sekme,
    //   adres onizleme de gider). Durum ayri, acik bir dugme.
    function durumSeciciAc(dugme) {
        var kart = dugme.closest("[data-argus-card]");
        var board = pano(kart);

        // Bir alttaki `ArgusSheet` kontrolu fail-loud; bu da oyle olmali.
        // Eskiden sessiz `return` vardi: isaretleme bozulursa dugme basiliyor,
        // hicbir sey olmuyor ve konsolda iz kalmiyordu — kapattigimiz kusurun
        // aynisi (code-reviewer bulgusu, 2026-09-23).
        if (!kart || !board) {
            bildir(null, "Kart bulunamadı: ekran tanımı eksik. Sayfayı yenileyin.", "bad");
            return;
        }

        // Fail-loud: betik yuklenmediyse SESSIZ kalma. Sessiz kalirsa
        // dokunmatik kullanici dugmeye basar, hicbir sey olmaz ve nedenini
        // soyleyen hicbir sey yoktur — kapattigimiz kusurun ta kendisi.
        if (!window.ArgusSheet) {
            bildir(board, "Durum seçici yüklenemedi. Sayfayı yenileyin.", "bad");
            return;
        }

        var simdiki = kart.closest("[data-argus-column]");

        var secenekler = kolonlar(board).map(function (kolon) {
            var ad = kolon.querySelector("[data-argus-column-title]");
            return {
                etiket: ad ? ad.textContent.trim() : kolon.getAttribute("data-argus-column"),
                deger: kolon.getAttribute("data-argus-column"),
                secili: kolon === simdiki
            };
        });

        window.ArgusSheet.ac({
            baslik: "Durum değiştir",
            acan: dugme,
            altBaslik: dugme.getAttribute("data-argus-card-title") || null,
            secenekler: secenekler,
            onSec: function (durum) {
                var hedef = board.querySelector('[data-argus-column="' + durum + '"]');
                tasi(board, kart, hedef);
            }
        });
    }

    document.addEventListener("click", function (e) {
        var dugme = e.target.closest("[data-argus-status]");
        if (!dugme) return;
        // Dugme kartin ICINDE degil YANINDA duruyor (bir <button> bir <a>
        // icine konamaz), yine de tiklamanin karta sizmasi engelleniyor.
        e.preventDefault();
        durumSeciciAc(dugme);
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
