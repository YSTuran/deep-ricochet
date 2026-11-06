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
- Açılışta `Devam` ve `Yeni Oyun` seçeneklerini sunan ana menü
- Devam eden koşuyu yanlışlıkla silmemek için yeni oyun onayı
- Oynanış ve rota ekranında simülasyonu tamamen donduran duraklatma menüsü
- Android arka plana geçişinde ve masaüstü odak kaybında otomatik duraklatma
- Uygulama yeniden öne geldiğinde yalnızca oyuncu `Devam` dediğinde çalışma
- Aktif koşudan ayrı ve atomik yazılan profil/istatistik kaydı
- En iyi skor, koşu, başarı ve kırılan toplam çekirdek takibi
- Ana menüde profil özeti ve sonuç ekranında yeni rekor bildirimi
- Her oda için ham puan, kalan atış bonusu, çarpan ve ödülü saklayan sonuç geçmişi
- Sonuç ekranında dört odaya kadar ayrıntılı puan dökümü
- Kalıcı dil tercihiyle eksiksiz Türkçe–İngilizce arayüz
- İlk yeni oyunda atış, çekirdek ve rota aşamalarına bağlanan üç adımlı etkileşimli öğretici
- Ayarlardan tekrar açılabilen üç sayfalı öğretici özeti
- Dil, ayrı efekt/müzik seviyeleri, ekran sarsıntısı ve onaylı tüm veri silme seçeneklerini içeren ayarlar ekranı
- Android geri tuşunun menü, ayarlar, öğretici, sonuç ve duraklatma katmanlarına uygun davranması
- Android 9 (API 28) alt sınırı, API 35 hedefi ve ARMv7/ARM64 Gradle export preseti
- Assetlerle uyumlu prosedürel hasar halkası ve blok kırılma parçacıkları
- Brief paletine uyumlu ortak maden arka planı, yuvarlatılmış panel ve düğme sistemi
- Ana menü, oyun HUD'ı, rota, sonuç, duraklatma, ayarlar ve öğreticide tutarlı UI dili
- CC0 lisanslı darbe, kırılma, arayüz ve sonuç sesleri
- Her yaylımda sıfırlanan Re minör pentatonik melodik çarpışma dizisi
- Normal blok, cevher, sert kaya ve çekirdek için ayrı ses katmanları
- Kodla üretilen düşük seviyeli döngüsel maden atmosferi
- Kalıcı ve birbirinden bağımsız efekt/müzik açma-kapama ve seviye ayarları

Aktif koşu `user://deep_ricochet_active_run.json` konumuna yazılır; önceki geçerli kayıt `.bak` uzantısıyla korunur. Geçerli ve bitmemiş bir kayıt uygulama açılışında ana menüde `Devam` düğmesini etkinleştirir. Kesilmiş atışta canlı top konumları yüklenmez; atış öncesindeki kararlı oda geri gelir. Oda sonuç geçmişini ekleyen snapshot şeması sürüm 2'dir; eski geliştirme kayıtları profil ve rekor korunarak kontrollü yeni oyun davranışına gider.

Duraklatma menüsünden ana menüye dönüldüğünde kararlı koşu korunur. Bir yaylım sürüyorsa diskteki atış öncesi snapshot kullanılır; böylece yarım simülasyon kaydedilmez. Uygulama arka plana geçtiğinde oyun otomatik durur, fakat öne döndüğünde kendiliğinden devam etmez.

Profil `user://deep_ricochet_profile.json`; dil, ses ve ekran sarsıntısı tercihleri `user://deep_ricochet_settings.json` konumunda aktif koşudan bağımsız tutulur. Her ikisi de geçici dosya ve son geçerli yedek kullanır. Yeni oyun aktif koşuyu değiştirirken rekor ve ayarları korur; ayarlardaki açık onaylı `Tüm Verileri Sil` işlemi aktif koşuyu, profili ve ayarları birlikte temizler.

Ses sistemi `deep-ricochet/audio/audio_manager.gd` otomatik yüklemesi üzerinden çalışır. Aynı anda gelen çarpışmalar 45 ms aralıkla sınırlandırılır; böylece sekiz topluk yaylımda sesler üst üste yığılıp bozulmaz. Arka plan atmosferi çalışma anında kodla üretilir; kullanılan Kenney efektlerinin kaynak ve lisans bilgileri `deep-ricochet/audio/THIRD_PARTY_AUDIO.md` dosyasındadır.

UI renkleri, panel biçimleri, düğme türleri ve prosedürel maden arka planı `deep-ricochet/ui/ui_theme.gd` içinde ortaklaştırılmıştır. Hareketli oyun ekranında yeniden kullanılan stil kaynakları önbelleğe alınır; menü ekranları aynı dokunma alanlarını korurken ortak görsel dili paylaşır.

Şablonlardaki örnek açı dizileri otomatik simülasyonda çekirdeği kırmaktadır; gerçek Android cihaz arka plan/geri dönüş, dokunmatik geçişleri ve hoparlör ses dengesi ayrıca doğrulanacaktır.

## Android dışa aktarma

`deep-ricochet/export_presets.cfg` içindeki **Android** preseti Android 9 ve üzerini, API 35 hedefini, ARMv7/ARM64 mimarilerini ve çevrimdışı çalışma için sıfır ek izin ilkesini kullanır. Paket kimliği şimdilik `com.ysturan.deepricochet` değeridir.

Godot 4.7.2 ile ilk APK'yı üretmeden önce:

1. **Editor → Manage Export Templates** içinden tam olarak `4.7.2.stable` Android export şablonunu kurun.
2. **Editor Settings → Export → Android** altında Java SDK yolunu Android Studio'nun `jbr` klasörüne, Android SDK yolunu içinde `platform-tools/adb` bulunan SDK klasörüne ayarlayın.
3. **Project → Install Android Build Template** ile Gradle şablonunu projeye kurun. Oluşan `deep-ricochet/android/` dizini makine üretimi olduğu için Git'e alınmaz.
4. Debug APK için Godot'un Export ekranındaki **Export Project** düğmesini veya aşağıdaki komutu kullanın:

```text
godot --headless --path deep-ricochet --export-debug Android build/android/deep-ricochet-debug.apk
```

Google Play sürümünde AAB seçilmeli ve depoya eklenmeyen özel bir release keystore kullanılmalıdır.

## Otomatik test

Godot komut satırından proje kökünde şu sahne çalıştırılır:

```text
godot --headless --path deep-ricochet --scene res://tests/smoke_test.tscn
```

Test; profil ve ayar geçişlerini, eski ayar şeması göçünü, efekt/müzik bus'larını, melodik çarpışma hız sınırını, sessiz modu, profil yedeğinden kurtarmayı, iki dili, üç aşamalı ilk-oyun öğreticisini, tüm veri silme hata davranışını, ayrıntılı oda sonuç geçmişini, ana menü ve devam durumunu, nişan sırasında duraklatmayı, canlı yaylımın donmasını, odak kaybını, 12 oda şablonunu, örnek açı geçişlerini, 100 seed seçimini, dört oda/üç rota akışını, atış ortası kurtarmayı, bozuk kayıt reddini, fiziği ve puanı doğrular. Ayrıca 12 odanın örnek açı simülasyon süresini test çıktısında `[PERF]` satırıyla raporlar.
