// Kabuk etkilesimi — bildirim paneli. Cerceve yok, vanilla JS
// (razor-conventions.md). Mobil menu Solum'un solum.js'inde.
//
// SATIR ICI OLAY ISLEYICISI YOK: eskiden onclick nitelikleriyle baglaniyordu
// (panel basina 20+ nitelik) ve CSP yazilacagi gun unsafe-inline gerektirirdi
// (TODO C11). Hepsi olay devri (event delegation) ile baglandi — 2026-08-26.
(function () {
    "use strict";

    function panel() { return document.getElementById("argusNotifPanel"); }

    function bildir(mesaj) {
        var t = document.getElementById("argusToast");
        if (t) { t.textContent = mesaj; t.className = "argus-toast argus-toast-bad"; t.hidden = false; return; }
        alert(mesaj);
    }

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
                    bildir("Bildirimler işaretlenemedi. Lütfen tekrar deneyin.");
                })
                .catch(function () { bildir("Bildirimler işaretlenemedi. Lütfen tekrar deneyin."); });
            return;
        }

        // Tek bildirim okundu — baglantiya tiklama akisini engellemez
        var oge = e.target.closest("[data-argus-notif-id]");
        if (oge) {
            var id = oge.getAttribute("data-argus-notif-id");
            if (id) {
                fetch("/api/notifications/mark-read?id=" + encodeURIComponent(id),
                      { method: "POST", credentials: "same-origin" });
            }
            return;
        }

        // Panel disina tiklandi -> kapat
        var kutu = document.getElementById("argusBell");
        var p2 = panel();
        if (kutu && p2 && !kutu.contains(e.target)) p2.hidden = true;
    });
})();
