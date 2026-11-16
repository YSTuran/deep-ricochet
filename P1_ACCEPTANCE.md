# P1 Kabul Kontrol Listesi

Bu belge P1 kod gereksinimlerinin otomatik doğrulaması ile Galaxy A10 üzerindeki son kullanıcı kabul testini birbirinden ayırır. iOS sürümü, proje kararı gereği kapsam dışıdır.

## Otomatik doğrulananlar

- [x] Aynı seed ile yeniden başlatma ilk odayı ve üç rota teklifinin tamamını aynı üretir.
- [x] 1× ve 2× aynı sabit fizik adımlarını kullanır; blok canları, puan, oda sonucu ve top sayaçları eşittir.
- [x] Hafif darbe efektleri ve ses yığılma sınırı uygulanır.
- [x] Titreşim yalnız Android'de çalışır, açılıp kapatılabilir ve çağrılar hız sınırına sahiptir.
- [x] On P1 test olayı kişisel veri içermeyen izin listesiyle yerelde tutulur.
- [x] Test günlüğü en fazla 500 olay saklar, atomik yazılır ve JSON olarak panoya kopyalanabilir.
- [x] Yedi madende toplam 98 doğrulanan şablon ve dört oda/üç rota akışı bulunur.

## Galaxy A10 cihaz testi

Test APK'sı: `deep-ricochet-debug.apk`

- [ ] APK mevcut debug kurulumunun üzerine yükleniyor ve uygulama açılıyor.
- [ ] Yeni kurulumda ana menü, öğretici ve ilk maden sorunsuz açılıyor.
- [ ] Bir maden 1× hızda tamamlanıyor; oda, rota ve sonuç ekranlarında takılma olmuyor.
- [ ] Aynı koşu 2× hızda tamamlanıyor; top kaybı, fazladan hasar veya farklı sonuç gözlenmiyor.
- [ ] Sekiz top, ekran sarsıntısı ve Grafik modu birlikte deneniyor; kabul edilemez uzun donma veya çökme olmuyor.
- [ ] Performans modunda aynı yoğun sahne yeniden deneniyor ve Grafik modundan daha kararlı hissediliyor.
- [ ] Titreşim açıkken blok/çekirdek geri bildirimi geliyor; kapatıldığında tamamen kesiliyor.
- [ ] Efekt ve müzik sesleri ayrı ayrı açılıp kapatılıyor; melodik çarpışmalar bozulmadan duyuluyor.
- [ ] Bir koşu yarıda bırakılıp uygulama arka plana gönderiliyor; dönüşte yalnız `Devam` ile sürüyor.
- [ ] Sonuç ekranındaki **Aynı Madeni Dene** aynı başlangıç odasını ve aynı rota tekliflerini veriyor.
- [ ] **Ayarlar → Genel → Test Verisini Kopyala** sonrasında pano içeriği geçerli JSON olarak bir metin uygulamasına yapıştırılabiliyor.
- [ ] Dışa aktarılan JSON'da olay adı, UTC zaman, koşu kimliği, oda, seed ve içerik sürümü var; isim, e-posta veya cihaz kimliği yok.
- [ ] **Tüm Verileri Sil** sonrasında test verisi yeniden kopyalanmaya çalışıldığında kayıt bulunmadığı bildiriliyor.

## Test kaydı

- Cihaz: Samsung Galaxy A10
- Android sürümü: __________
- Test tarihi: __________
- APK dosya boyutu: __________
- Sonuç/notlar: __________
