// Servis calisani — YALNIZ STATIK VARLIK onbellegi.
//
// ┌─ GUVENLIK KARARI — BU DOSYANIN EN ONEMLI SATIRLARI ────────────────────┐
// │ HTML ve `/api/*` ASLA onbelleklenmez.                                  │
// │                                                                        │
// │ Gerekce (plan 07, reddedilen alternatif C): kimlik dogrulanmis bir     │
// │ sayfayi onbellege almak, cikis yapmis ya da YETKISI DUSURULMUS         │
// │ kullaniciya eski icerigi gosterir. Denetim yaziliminda bu, yetki       │
// │ kapisini DELEN bir onbellektir — ve kimse fark etmez, cunku ekranda    │
// │ dogru gorunur.                                                         │
// │                                                                        │
// │ Bu depoda tam olarak bu sinif hata YASANDI: rol bir CEREZ FOTOGRAFINDAN│
// │ okunuyordu, kullanicinin rolu DB'de dusurulmustu ve 7 gun boyunca      │
// │ silme yetkisi devam etti. Onbellege alinmis HTML ayni hatanin ikinci   │
// │ tasiyicisi olurdu.                                                     │
// └────────────────────────────────────────────────────────────────────────┘
//
// CEVRIMDISI CALISMA YOK — kullanici karari (plan 07). Bu dosyanin isi
// yalniz statik varligi hizlandirmak ve uygulamayi KURULABILIR kilmak.
//
// ── GERI ALMA (rollback) ──────────────────────────────────────────────────
// Bu dosyayi SILMEK YETMEZ: kayitli servis calisani tarayicida kalir ve
// eski surumu servis etmeye devam eder. Geri almak icin bu dosyanin
// ICERIGI asagidakiyle DEGISTIRILIR ve yayimlanir:
//
//     self.addEventListener("install", function () { self.skipWaiting(); });
//     self.addEventListener("activate", function (e) {
//         e.waitUntil((async function () {
//             var adlar = await caches.keys();
//             await Promise.all(adlar.map(function (a) { return caches.delete(a); }));
//             await self.registration.unregister();
//         })());
//     });
//
// Tarayici `/sw.js` adresini periyodik olarak yeniden indirir; yukaridaki
// surum yayimlandiginda kayit kendini siler. Acik sekmeler bir sonraki
// yuklemede temizlenmis olur.
//
// BU YOL TEST EDILDI (2026-09-23, localhost): gecici olarak yukaridaki
// govde yayimlandi -> `registration.update()` -> onbellek ["argus-statik-v1"]
// -> [] ve kayit sayisi 1 -> 0. Belgelenmis ama denenmemis bir geri alma
// yolu, geri alma yolu DEGILDIR.
"use strict";

// Surum yukseltilince ESKI onbellek tamamen silinir (asagida `activate`).
// Elle yukseltilir — statik adreslerin cogu zaten `asp-append-version`
// ile parmak izli oldugu icin bayatlama riski dusuk.
var ONBELLEK = "argus-statik-v1";

// BEYAZ LISTE (yol oneki). Burada olmayan HICBIR sey onbellege girmez.
// Dikkat: `/api` ve HTML bilerek YOK ve eklenmemeli. `/uploads` DA YOK —
// orada kullanici yuklemeleri (denetim fotograflari) duruyor.
var IZINLI_ONEKLER = [
    "/css/",
    "/js/",
    "/icons/",
    "/assets/",
    "/_content/"        // Solum.Web'in statik varliklari
];

// ICERIK TURU KAPISI. Yol oneki YETMEZ: `/assets/` bugun yalniz logo
// tasiyor ama adi "muhtelif statik" demek ve bir gun oraya kullanici
// yuklemesi konursa (denetim fotografi) uzanti kapisi olmadan onbellege
// GIRER ve paylasimli magaza tabletinde oturum kapandiktan sonra da kalir.
// `wwwroot/uploads/` ASLA beyaz listeye eklenmemeli — DOF ekleri orada.
var IZINLI_UZANTI = /\.(css|js|mjs|png|svg|webp|woff2?|ico)$/i;

// PARMAK IZI ZORUNLU. En onemli kapi, ve bunu denetci buldu:
//
//   Cache-first + parmak izsiz adres = ISTEMCI KODU KALICI DONAR.
//
// Sunucu `/_content/Solum.Web/solum.js` icin `Cache-Control: no-cache`
// beyan ediyor (olculdu: staticwebassets.endpoints.json). Cache-first bunu
// GORMEZDEN gelir ve `ONBELLEK` sabiti elle yukseltilene kadar eski kopyayi
// servis eder. Solum paylasilan katman ve aktif gelistirmede; oraya bir
// guvenlik duzeltmesi girdigi gun, onbellege bir kez girmis her tarayici
// duzeltmeyi HIC ALMAZ ve ekranda her sey dogru gorunur.
//
// Cozum: yalniz ICERIGI ADRESINDE tasiyan varlik onbekleklenir
// (`ad.<parmakizi>.uzanti` — MapStaticAssets bunu uretiyor — veya `?v=`).
// Icerik degisince ADRES degisir, yani bayat kopya mumkun degil.
// Parmak izsiz adres (ikonlar, favicon, manifest) hic onbekleklenmez;
// kucuk dosyalar, kazanci yok, riski var.
var PARMAK_IZI = /\.[0-9a-z]{8,}\.[0-9a-z]+$/i;

function parmakIzliMi(url) {
    return PARMAK_IZI.test(url.pathname) || url.searchParams.has("v");
}

function onbelleklenebilir(url) {
    if (!IZINLI_UZANTI.test(url.pathname)) return false;
    if (!parmakIzliMi(url)) return false;

    for (var i = 0; i < IZINLI_ONEKLER.length; i++) {
        if (url.pathname.indexOf(IZINLI_ONEKLER[i]) === 0) return true;
    }
    return false;
}

self.addEventListener("install", function () {
    // On-yukleme YOK: cevrimdisi calisma kapsam disi, dolayisiyla kurulum
    // aninda dosya toplamanin faydasi yok. Yeni surum hemen devralsin.
    self.skipWaiting();
});

self.addEventListener("activate", function (olay) {
    olay.waitUntil((async function () {
        var adlar = await caches.keys();
        await Promise.all(adlar
            .filter(function (ad) { return ad !== ONBELLEK; })
            .map(function (ad) { return caches.delete(ad); }));
        await self.clients.claim();
    })());
});

self.addEventListener("fetch", function (olay) {
    var istek = olay.request;

    // GET disi hicbir sey (POST/PUT/DELETE) ele alinmaz — ag neyse o.
    if (istek.method !== "GET") return;

    // Farkli kaynak (Google Fonts, Tailwind CDN) ele alinmaz: opak yanit
    // onbelleklemek ne dogrulanabilir ne temizlenebilir.
    var url = new URL(istek.url);
    if (url.origin !== self.location.origin) return;

    // Gezinme istegi = HTML. Kesinlikle dokunulmaz (bkz. yukaridaki kutu).
    if (istek.mode === "navigate") return;

    if (!onbelleklenebilir(url)) return;

    olay.respondWith((async function () {
        var onbellek = await caches.open(ONBELLEK);

        var kayitli = await onbellek.match(istek);
        if (kayitli) return kayitli;

        var yanit = await fetch(istek);

        // SAVUNMA KATMANI: beyaz listedeki bir adres HTML donduruyorsa
        // (404/401 hata sayfasi, oturum sonu yonlendirmesi) onbellege
        // ALINMAZ. Beyaz liste yolu kontrol eder, bu kontrol ICERIGI.
        var tur = yanit.headers.get("content-type") || "";
        var guvenli = yanit.ok
            && yanit.type === "basic"
            && tur.indexOf("text/html") === -1;

        if (guvenli) {
            // Yanit govdesi bir kez okunur; kopyasi onbellege gider.
            onbellek.put(istek, yanit.clone());
        }
        return yanit;
    })());
});
