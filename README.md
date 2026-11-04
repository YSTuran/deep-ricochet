# Deep Ricochet

Deep Ricochet, dikey ekranda oynanan nişan alma ve sekme odaklı bir mobil oyun prototipidir. Oyuncu topları fırlatır; normal blokları, cevher bloklarını ve çekirdeği kırmaya çalışırken sert kayalardan ve duvarlardan yararlanır.

## Dizin yapısı

- `deep-ricochet/`: Godot projesi ve çalıştırılabilir oyun kaynakları.
- `assets/`: Orijinal görseller, üretim notları ve asset manifesti.

Oda içerikleri `deep-ricochet/content/rooms/` altındaki JSON şablonlarında tutulur. Oynanış sahnesi bu şablonlardan blok dizilimini, blok canlarını ve oda çarpanını yükler; kaynak şablonu değiştirmeden her başlangıçta yeni bir tahta üretir.

Godot'ta açılması gereken dosya `deep-ricochet/project.godot` dosyasıdır. Ana klasör ise Git deposunun köküdür; böylece hem proje hem de kaynak asset paketi birlikte sürümlenir.

## Teknolojiler

- Godot 4.7.2
- Typed GDScript
- Compatibility renderer
- Dikey ekran: 540 × 960
- Hedef platform: Android 9 ve üzeri

## Çalıştırma

1. Godot Project Manager içinde **Import** seçeneğini açın.
2. `deep-ricochet/project.godot` dosyasını seçin.
3. Projeyi açıp **F5** ile dört odalık ana oyun akışını çalıştırın.

Oyun alanında fareyle ya da dokunmatik ekranla basılı tutup yön seçilir; bırakıldığında top fırlatılır. Kesikli nişan çizgisi gerçek atışla aynı fizik simülatörünü kullanır. İlk üç başarılı odadan sonra gerçek oda şablonlarını gösteren güvenli ve bonus rota kartlarından biri seçilir.

## P0 mevcut durum

- Sabit zaman adımlı top hareketi ve duvar sekmesi
- Alt sınırda top toplama
- Kare normal, cevher ve sert kaya çarpışmaları
- Dairesel çekirdek çarpışması
- Normal, cevher ve çekirdek için can/hasar sistemi
- Aynı temas sırasında yinelenen hasarı engelleme
- Kırılabilir nesnede duran ve temas noktasını gösteren simülasyon tabanlı nişan önizlemesi
- Aynı noktadan 0,08 saniye arayla çıkan 8 topluk yaylım
- 10 saniyelik yaylım üst sınırı ve tek seferlik atış sonucu
- Kırılma puanları, kalan atış bonusu ve oda çarpanı hesabı
- Başarı, son atışta başarı önceliği ve başarısız oda sonucu
- JSON tabanlı, doğrulanan ve yeniden kullanılabilir oda şablonları
- Dışarıdan oda yükleyebilen ve sonucu sinyalle bildiren `GameplayRoom`
- Dört oda, üç rota tercihi ve tek seferlik sonuç işleyen `RunSession` / `RunController`
- Seed tabanlı, aynı koşuda daha önce sunulan şablonu yeniden kullanmayan içerik seçimi
- Gerçek şablondan çizilen güvenli/bonus rota önizlemeleri ve geçici sonuç ekranı
- 6 güvenli ve 6 bonus olmak üzere 12 doğrulanan oda şablonu
- Sürümlendirilmiş `RunSnapshot`, `RoomSnapshot` ve JSON kayıt zarfı
- Atomik geçici dosya yazımı, son geçerli yedek ve bozuk kayıt doğrulaması
- Atış öncesi snapshot; yarıda kesilen yaylımda hak/puan kaybetmeden geri dönüş
- Oda, rota adayları ve sonuç ekranı için otomatik kararlı durum kaydı

Aktif koşu `user://deep_ricochet_active_run.json` konumuna yazılır; önceki geçerli kayıt `.bak` uzantısıyla korunur. Ana menü henüz bulunmadığı için geçerli kayıt uygulama açılışında otomatik devam eder. Kesilmiş atışta canlı top konumları yüklenmez; atış öncesindeki kararlı oda geri gelir.

Duraklatma/arka plan yaşam döngüsü, ana menü, iki dil, öğretici ve ses sonraki P0 adımlarında eklenecektir. Şablonlardaki örnek açı dizileri otomatik simülasyonda çekirdeği kırmaktadır; gerçek Android cihaz geçişleri ayrıca doğrulanacaktır.

## Otomatik test

Godot komut satırından proje kökünde şu sahne çalıştırılır:

```text
godot --headless --path deep-ricochet --scene res://tests/smoke_test.tscn
```

Test; 12 oda şablonunu, örnek açı geçişlerini, 100 seed seçimini, dört oda/üç rota akışını, kararlı kayıt round-trip işlemini, atış ortası kurtarmayı, sabit rota adaylarını, yedekten kurtarmayı, bozuk kayıt reddini, açılışta otomatik devamı, yinelenen sonuç korumasını, fiziği ve puanı doğrular.
