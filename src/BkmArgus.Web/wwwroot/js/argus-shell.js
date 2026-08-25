// Kabuk etkilesimi — bildirim paneli. Cerceve yok, vanilla JS
// (razor-conventions.md). Mobil menu Solum'un solum.js'inde.
(function () {
    "use strict";

    // Panel disina tiklaninca kapat.
    document.addEventListener("click", function (e) {
        var kutu = document.getElementById("argusBell");
        var panel = document.getElementById("argusNotifPanel");
        if (kutu && panel && !kutu.contains(e.target)) {
            panel.hidden = true;
        }
    });

    window.argusToggleNotif = function () {
        var panel = document.getElementById("argusNotifPanel");
        if (panel) panel.hidden = !panel.hidden;
    };

    window.argusNotifOkundu = function (el) {
        var id = el.getAttribute("data-notif-id");
        if (!id) return;
        fetch("/api/notifications/mark-read?id=" + encodeURIComponent(id), {
            method: "POST",
            credentials: "same-origin"
        });
    };

    window.argusNotifTumunuOkundu = function () {
        fetch("/api/notifications/mark-all-read", {
            method: "POST",
            credentials: "same-origin"
        }).then(function (r) {
            if (r.ok) { location.reload(); return; }
            alert("Bildirimler işaretlenemedi. Lütfen tekrar deneyin.");
        }).catch(function () {
            alert("Bildirimler işaretlenemedi. Lütfen tekrar deneyin.");
        });
    };
})();
