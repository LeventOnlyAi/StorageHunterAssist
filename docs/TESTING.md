# Doğrulama kapsamı / Verification scope

## 0.3.0 — 27 Ekim 2026

Windows, oyun build **22160137**, UE4SS **v3.0.1-1181-g83330635**. Güncel F8 arayüzü temiz başlangıçta açıldı; kalite grupları, ürün sayıları, tek ürün kutuları, ayrı satış/depo hedefleri ve Kurallar sekmesi gözlendi.

| Kontrol | Gözlenen sonuç |
| --- | --- |
| Kaliteye göre karma işlem | Nadir kanepe Çayüzümü deposuna geçti; işlem anında stok 10 → 11. Seçili yaygın ürün native satış yoluyla çıkarıldı. |
| Doğrulanmamış satış sorunu | Geliştirmede doğrulanmamış yaygın ürünün native satışta sıfır nakit değişimiyle çıkabildiği görüldü. Yayına eklenen kontrol aynı durumda 0 işlemle satış isteğini reddetti. |
| Doğrulama sonrası kalite satışı | Oyunun doğrulama işlemi sonrasında yaygın ürün Naple hedefine satıldı; yeni koruma koduyla nakit +42 gözlendi. Ayrı önceki denemede +89 gözlendi. |
| Koleksiyon bilgisi | Hançer Arkeolog grubunda; Kano Hazırlıkçılar grubunda, güncel haftalık istek yıldızıyla gösterildi. Grup kutusu altındaki ürünü seçti. |
| Son temiz başlangıçta otomatik ayırma | Nadir koltuk Çayüzümü deposuna girdi: 10 → 11. Koleksiyonluk Kano `hold` durumunda listede kaldı, nakit değişmedi. |
| Koleksiyonluğu isteğe bağlı depolama | Kurallar kutusu açıldıktan sonra seçili Kano depoya geçti: 11 → 12. |
| Canlı liste | Panel açık ve otomatik işlem kapalıyken sonradan getirilen ürünler listeye eklendi. Mevcut seçimler korunur; yeni ürünler seçilmez. |
| Havuzlanan aktör | Daha önce işlenen Yatak ile sonradan edinilen ürünün aynı tam aktör adını kullandığı gözlendi. Bu durum için eski işlem kaydının temizlenmesi yerel regresyon testleriyle, kamyon-only durumu dahil kontrol edildi. |

Bu rakamlar vanilla satış fiyatı iddiası değildir; test ortamında başka satış modları vardır. Doğrulama sırasında geçici test komutları ve yedeklenmiş kayıt kullanıldı. İlk testte geçici fixture sıfırlama komutu erişim ihlaliyle oyunu kapattı; o komut yayın koduna dahil değildir. Son temiz başlangıç ve otomatik/depo testleri tamamlandı. Test oturumlarının kayıt değişiklikleri geri alındı; kurulan yayın Lua dosyaları kaynakla hash karşılaştırıldı.

Yerel Lua testleri ayrıca bütün nadirlik rotalarını, bilinmeyen/doğrulanmamış ürün bekletmesini, koleksiyoncu adını ve haftalık teslim durumunu, depo kapasite kontrolünü, kısmi depo reddinde satışı durdurmayı, native satışın gecikmesi sırasında sahiplik/mesafe/doğrulama/kalite değişimini kontrol eder. Bir ürünün adı okunamasa da kalan listenin görünmesi için eski 0.2.0 koduyla başarısız, yeni kodla başarılı regresyon testi çalıştırıldı. 7200 zaman sınırı kontrolü korunur. Mock arayüz testi, otomatik işlem kapalıyken yeni satır eklenmesini, seçim korumayı, değişmeyen listede arayüzü yeniden kurmamayı ve kural değişikliğinde otomatiği durdurmayı doğrular.

Her özel eşya/kutu türü, çok oyunculu istemci veya yeni Steam build'i ayrıca test edilmedi. Görünmeme sorununda yeniden üretilen nedenler giderildi; bütün olası nedenlerin giderildiği iddia edilmez. Koleksiyoncuya otomatik teslim bu sürümün özelliği değildir.

## 0.2.0 — önceki sürümün oyun içi testleri

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

Yayın kontrolü, yedi Lua dosyasının kurulan kopyayla SHA-256 eşleşmesini, paketteki üçüncü taraf lisansını ve ZIP bütünlüğünü denetler. Kullanıcı kayıtları, yerel kurulum makbuzları, hata dökümleri, test komut eklentileri ve başka modlar yayımlanmaz.
