---
description: "Yeni stored procedure olustur (BkmArgus naming convention ile)"
---

Verilen bilgilere gore yeni SP olustur. Proje kurallarini otomatik uygula:

## KURALLAR (otomatik uygula):
- SP adi: schema.sp_Entity_Action (Ingilizce)
- Parametre adlari: Turkce, @ prefix
- SET NOCOUNT ON ilk satir
- TRY-CATCH zorunlu
- datetime2(0) kullan, datetime KULLANMA
- SYSDATETIME() kullan, GETDATE() KULLANMA
- Idempotent: IF OBJECT_ID DROP + CREATE pattern
- Tablo/kolon adlari INGILIZCE (CLAUDE.md naming convention)
- src.* view'leri DEGISMEZ, aliasing kullan

## FORMAT:
```sql
IF OBJECT_ID(N'schema.sp_Entity_Action', N'P') IS NOT NULL
    DROP PROCEDURE schema.sp_Entity_Action;
GO
CREATE PROCEDURE schema.sp_Entity_Action
    @Param1 int,
    @Param2 nvarchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Logic here
    END TRY
    BEGIN CATCH
        DECLARE @msg nvarchar(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH
END
GO
```

Kullanici istegi: $ARGUMENTS
