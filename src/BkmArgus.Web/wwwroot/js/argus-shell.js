// Kabuk etkilesimi — bildirim paneli. Cerceve yok, vanilla JS
// (razor-conventions.md). Mobil menu Solum'un solum.js'inde.
//
// SATIR ICI OLAY ISLEYICISI YOK: eskiden onclick nitelikleriyle baglaniyordu
// (panel basina 20+ nitelik) ve CSP yazilacagi gun unsafe-inline gerektirirdi
// (TODO C11). Hepsi olay devri (event delegation) ile baglandi — 2026-08-26.
(function () {
    "use strict";

    function panel() { return document.getElementById("argusNotifPanel"); }

    // Toast: zamanlayici EKLENDI. Eskiden mesaj sayfa omru boyunca ekranda
    // kaliyordu; kullanici eski bir hatayi guncel sanabiliyordu (bulgu 4.2a).
    function bildir(mesaj, tur) {
        var t = document.getElementById("argusToast");
        if (!t) { alert(mesaj); return; }
        t.textContent = mesaj;
        t.className = "argus-toast argus-toast-" + (tur || "bad");
        t.hidden = false;
        window.clearTimeout(t._zaman);
        t._zaman = window.setTimeout(function () { t.hidden = true; }, 4000);
    }

    // Yikici islem onayi: satir ici onclick="return confirm(...)" yerine
    // data-argus-confirm. Onay REDDEDILIRSE gonderim durur (CSP + tek yer).
    document.addEventListener("click", function (e) {
        var onayli = e.target.closest("[data-argus-confirm]");
        if (onayli && !window.confirm(onayli.getAttribute("data-argus-confirm"))) {
            e.preventDefault();
            e.stopPropagation();
            return;
        }
    }, true);

    document.addEventListener("click", function (e) {
        // Panel ac/kapat
        if (e.target.closest("[data-argus-notif-toggle]")) {
            var p = panel();
            if (p) p.hidden = !p.hidden;
            return;
        }

        // Tumunu okundu isaretle
        if (e.target.closest("[data-argus-notif-all]")) {
            fetch("/api/notifications/mark-all-read", { method: "POST", credentials: "same-origin" })
                .then(function (r) {
                    if (r.ok) { location.reload(); return; }
                    bildir("Bildirimler işaretlenemedi. Lütfen tekrar deneyin.", "bad");
                })
                .catch(function () { bildir("Bildirimler işaretlenemedi. Lütfen tekrar deneyin.", "bad"); });
            return;
        }

        // Tek bildirim okundu.
        //
        // IKI KUSUR KAPANDI (denetim bulgusu 4.1):
        //   1. Yanit HIC kontrol edilmiyordu — .then yok, .catch yok. 500 veya
        //      401 halinde kullaniciya sifir geri bildirim vardi.
        //   2. Oge bir <a href> oldugu icin tiklama AYNI ANDA gezinme baslatiyor;
        //      ucusta olan POST sayfa bosaltilirken tarayici tarafindan IPTAL
        //      edilebiliyordu. Bildirim okundu isaretlenmiyor, zil rozeti eski
        //      sayida kaliyordu. keepalive: true istegin gezinmeye dayanmasini
        //      saglar (fetch spesifikasyonu bu is icin var).
        var oge = e.target.closest("[data-argus-notif-id]");
        if (oge) {
            var id = oge.getAttribute("data-argus-notif-id");
            if (id) {
                fetch("/api/notifications/mark-read?id=" + encodeURIComponent(id),
                      { method: "POST", credentials: "same-origin", keepalive: true })
                    .then(function (r) {
                        if (!r.ok) bildir("Bildirim okundu işaretlenemedi.");
                    })
                    .catch(function () { bildir("Bildirim okundu işaretlenemedi."); });
            }
            return;
        }

        // Panel disina tiklandi -> kapat
        var kutu = document.getElementById("argusBell");
        var p2 = panel();
        if (kutu && p2 && !kutu.contains(e.target)) p2.hidden = true;
    });
})();
