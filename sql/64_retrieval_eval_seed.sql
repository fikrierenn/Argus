-- ============================================================================
-- 64 — Geri getirme olcum seti tohumu (30 Turkce sorgu)
--
-- Sorgular ELLE yazildi, LLM'e urettirilmedi. Gerekce: uretici modelin
-- kendi ifade bicimini tasiyan sorgular, ayni aileden bir modelle yapilan
-- aramayi yapay olarak kolaylastirir. Elle yazim bu yanliligi tasimaz.
--
-- Ifade bicimi bilincli: sorgular kontrol maddesinin YENIDEN YAZIMI DEGIL,
-- bir denetcinin bulguyu nasil anlatacagi gibi. "X yapiliyor mu?" degil,
-- "X yapilmamis" veya "X'te sorun var". Gercek kullanim boyle olacak; soruyu
-- soruyla aramak yalnizca kelime eslesmesini olcerdi.
--
-- Ground truth = kaynak kayit. Ayni basliga sahip birden fazla kayit varsa
-- (ayni kontrol maddesi farkli denetimlerde tekrar ediyor) olcum kodu
-- BASLIK esitligini kabul eder — aksi halde dogru cevap yanlis sayilirdi.
--
-- Idempotent: sp_RetrievalEval_AddQuery ayni metni ikinci kez eklemez.
-- ============================================================================

SET NOCOUNT ON;
GO

DECLARE @sorgular TABLE (Metin nvarchar(500), Tip varchar(20), Id bigint);

INSERT INTO @sorgular (Metin, Tip, Id) VALUES
-- Temizlik / duzen
(N'kafe bar tezgahi kirli ve dagmik birakilmis',                              'DOF',   14),
(N'magazanin dis cephesi ve giris onu temiz degil',                           'DOF',   53),
(N'yemekhane zemini ve duvarlari kirli, sosluklar dagmik',                    'DOF',   51),
(N'geri donusum deposu dagmik, kartonlar yerde',                              'AUDIT', 163),
(N'hurda kagit ve naylon toplama alani duzensiz',                             'AUDIT', 161),

-- Gida guvenligi
(N'raftaki gida urunlerinin tarihi gecmis',                                   'DOF',   48),
(N'cig urunler hazir gidalarin ustunde duruyor, capraz bulasma riski',        'AUDIT', 97),
(N'siparis gelmeden yemek pisirilip bekletiliyor',                            'DOF',   42),
(N'atik yag varilinin agzi acik, sizinti var',                                'DOF',   89),
(N'kafede recete bilgilendirmesi asili degil',                                'DOF',   40),

-- Kasa / nakit
(N'kasa personeli musteriyi karsilamiyor, ilgisiz davraniyor',                'DOF',   34),
(N'sahte para kontrol cihazi bozuk',                                          'DOF',   57),
(N'gunluk kasa verisi sisteme girilmemis',                                    'DOF',   18),
(N'hediye urunler fise gecirilerek kapatilmis',                               'DOF',   20),

-- Sayim / stok
(N'sayim onayinda gerekce ile fiili durum uyusmuyor',                         'DOF',   25),
(N'ayni urun ayni ay icinde birden cok kez sayilmis',                         'DOF',   23),
(N'alti aydir hic hareket gormemis stok duruyor',                             'DOF',   55),
(N'gecen ayin sayimi mazeret gosterilip bu aya atilmis',                      'DOF',   46),

-- Guvenlik / demirbas
(N'elektrik panosunun onu malzemeyle kapatilmis',                             'DOF',   81),
(N'vitrin dolaplari kilitsiz birakilmis',                                     'DOF',   33),
(N'depoda urun disarida bekliyor, guvenlik zafiyeti olusuyor',                'DOF',   27),
(N'mutfakta kullanilmayan demirbaslar ortada duruyor, paketlenmemis',         'DOF',   90),
(N'yemekhane ekipmani arizali, talep acilmamis',                              'DOF',   80),

-- Personel
(N'personel yaka kartini takmiyor',                                           'DOF',   92),
(N'calisanin cantasi ve kisisel esyalari calisma alaninda',                   'DOF',   79),
(N'haftalik vardiya cizelgesi sisteme yuklenmemis',                           'DOF',   83),
(N'yillik izin formu insan kaynaklarina gonderilmemis',                       'DOF',   61),

-- Sistem / evrak
(N'magaza radyosu calismiyor, destek talebi acilmamis',                       'AUDIT', 131),
(N'tamim onay formlari imzasiz, denetim departmanina ulasmamis',              'DOF',   15),
(N'kafe personeli yaka karti takmamis',                                       'AUDIT', 88);

DECLARE @m nvarchar(500), @t varchar(20), @i bigint, @eklenen int = 0, @atlanan int = 0;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT Metin, Tip, Id FROM @sorgular;

OPEN c;
FETCH NEXT FROM c INTO @m, @t, @i;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        EXEC ai.sp_RetrievalEval_AddQuery
            @SorguMetni  = @m,
            @BeklenenTip = @t,
            @BeklenenId  = @i,
            @Kaynak      = 'MANUEL',
            @Not         = N'Denetci ifadesi; kontrol maddesinin yeniden yazimi degil.';
        SET @eklenen += 1;
    END TRY
    BEGIN CATCH
        -- Beklenen kayit arsivde yoksa sorgu atlanir; sessiz gecilmez
        PRINT CONCAT(N'ATLANDI: ', @t, N'#', @i, N' - ', ERROR_MESSAGE());
        SET @atlanan += 1;
    END CATCH

    FETCH NEXT FROM c INTO @m, @t, @i;
END

CLOSE c;
DEALLOCATE c;

PRINT CONCAT(N'64_retrieval_eval_seed: ', @eklenen, N' sorgu islendi, ', @atlanan, N' atlandi.');
GO
