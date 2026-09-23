// PWA kaydi ve "Uygulamayi yukle" dugmesi.
//
// KAPSAM: yalniz KURULABILIRLIK. Cevrimdisi calisma kullanici karariyla
// kapsam disi (plan 07); servis calisani da yalniz statik varlik
// onbellekliyor — gerekcesi `wwwroot/sw.js` basindaki kutuda.
(function () {
    "use strict";

    // ── Servis calisani kaydi ────────────────────────────────────────────
    // Tarayici desteklemiyorsa SESSIZ gecilir: bu bir hata degil, yalniz
    // hizlanma ve kurulabilirlik kaybi. Uygulama aynen calisir.
    if ("serviceWorker" in navigator) {
        window.addEventListener("load", function () {
            navigator.serviceWorker.register("/sw.js", { scope: "/" })
                .catch(function (hata) {
                    // Kayit BASARISIZ olursa sessiz kalmiyoruz: kurulabilirlik
                    // kaybolur ve nedeni gorunmezse "neden yuklenmiyor" sorusu
                    // cevapsiz kalir. Kullaniciya bildirim YOK (onun yapacagi
                    // bir sey yok), konsola uyari VAR.
                    console.warn("Argus: servis calisani kaydedilemedi —", hata);
                });
        });
    }

    // ── Kurulum istemi ───────────────────────────────────────────────────
    var dugme = document.querySelector("[data-argus-install]");
    if (!dugme) return;

    var istem = null;

    // Tarayici "bu site kurulabilir" dediginde olayi YAKALARIZ ve kendi
    // dugmemizi gosteririz. Olay yakalanmazsa dugme GIZLI kalir — calismayan
    // bir dugme gostermek, bu oturumda kapattigimiz "olu kanca" hatasinin
    // aynisi olurdu.
    window.addEventListener("beforeinstallprompt", function (olay) {
        olay.preventDefault();
        istem = olay;
        dugme.hidden = false;
    });

    dugme.addEventListener("click", async function () {
        if (!istem) return;
        dugme.disabled = true;
        istem.prompt();
        await istem.userChoice;
        // Istem NESNESI tek kullanimliktir — ikinci `prompt()` cagrisi atar.
        istem = null;
        dugme.hidden = true;
        dugme.disabled = false;
    });

    // Kurulum tamamlaninca dugme anlamini yitirir.
    window.addEventListener("appinstalled", function () {
        istem = null;
        dugme.hidden = true;
    });
})();
