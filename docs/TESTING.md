# Doğrulama kapsamı / Verification scope

## Oyun içi testler

Modun 0.2.0 çalışma kodu oyun build **22160137**, Windows ve **UE4SS v3.0.1-1181-g83330635** ile doğrulandı. Bu yayında çalışan Lua dosyaları değiştirilmeden paketlenmiştir. Kullanıcı da daha sonraki oynanışında modun çalıştığını bildirdi.

| İşlev | Gözlenen sonuç |
| --- | --- |
| Uzak depoya elle gönderme | Seçili eşya listeden çıktı; hedef mağaza stok sayısı 16'dan 17'ye yükseldi. |
| Kamyon yükünü bulma | Gerçek kamyon yük kaydı listelendi ve yakın eşya listesiyle çift sayılmadı. |
| Kamyondan uzaktan satış | Naple hedefine satışta nakit 865 → 928, banka 27 → 34; kamyon kayıt sayısı 1 → 0. |
| Yakındaki iki eşyayı birlikte satma | Aynı uzak satış noktasında nakit 706 → 865. |
| Otomatik depo | İlk ve daha sonra getirilen ikinci eşya depoya alındı; otomatik açık kalmaya devam etti. |
| Panelden +60 dakika | Oyun dakika sayacı 13348 → 13408. |
| Temiz başlangıçta F7 / F6 | 120 dakika seçildi, panel seçimi eşleşti; sayaç 13348 → 13468. |
| Gün sonu sınırı | Önceki sınır denemesinde istenen atlama kalan bir dakikaya sınırlandı. |

Satış denemelerindeki tutarlar örnektir. Deneme ortamında başka satış modları da bulunduğundan bu rakamlar vanilla fiyat iddiası değildir. StorageHunterAssist satış fiyatı veya para miktarını elle yazmaz; oyunun hızlı satış olayını çağırır.

Hedef listesindeki **beş dükkân** kontrol edildi. Fiilî uzak satış denemesi **Naple**, depo denemesi sahip olunan **Çayüzümü** mağazası içindir. Diğer dört hedefte ayrı birer satış testi yapılmış gibi yorumlanmamalıdır. Her yeni Steam build'i, özel kap / eşya türü veya çok oyunculu senaryo için ayrı doğrulama yapılmadı. Çok oyunculu istemci desteklenmez.

## Yerel kontroller

`tests/verify_remote.lua` şu durumları mock oyun nesneleriyle kontrol eder:

- 7200 zaman adımı / gün sonu durumu.
- Oyuncu ve mevcut kayıttaki sahiplik adları; yabancı / sahipsiz eşya filtreleri.
- Elde, rafta, depoda ve kutu içinde bulunan alt eşya filtreleri.
- Kamyon / yakın listesi tekilleştirmesi; işlemden önce mesafenin yeniden kontrol edilmesi.
- Başkasının deposuna aktarımı ve dolu depoya yazmayı engelleme.
- İki işlem / üst üste satış isteğinde aynı eşyayı tekrar işlememe.
- Sonucu belirsiz motor hatasında aynı eşyayı otomatik tekrar işlememe.

Bu kontroller oyun içi çalışmanın yerine geçmez. Geliştiriciler Python 3 ve `lupa` kurulu bir ortamda, depo kökünden `python tools/check_release.py` çalıştırabilir. Oyuncuların Python veya Lua yüklemesi gerekmez.

## Yayın paketi

Yayın kontrolü, altı Lua dosyasının çalışan kopyayla SHA-256 eşleşmesini, paketteki üçüncü taraf lisansını ve ZIP bütünlüğünü denetler. Kullanıcı kayıtları, yerel kurulum makbuzları, hata dökümleri, test komut eklentileri ve başka modlar yayımlanmaz.
