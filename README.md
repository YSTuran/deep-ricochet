# Deep Ricochet

Deep Ricochet, dikey ekranda oynanan nişan alma ve sekme odaklı bir mobil oyun prototipidir. Oyuncu topları fırlatır; normal blokları, cevher bloklarını ve çekirdeği kırmaya çalışırken sert kayalardan ve duvarlardan yararlanır.

## Dizin yapısı

- `deep-ricochet/`: Godot projesi ve çalıştırılabilir oyun kaynakları.
- `assets/`: Orijinal görseller, üretim notları ve asset manifesti.

Etkin oda içerikleri `deep-ricochet/content/mines/rooms/` altındaki JSON şablonlarında, üç madenin sırası ve kilit koşulları ise `deep-ricochet/content/mines/mines.json` içinde tutulur. Oynanış sahnesi bu şablonlardan blok dizilimini, blok canlarını ve oda çarpanını yükler; kaynak şablonu değiştirmeden her başlangıçta yeni bir tahta üretir. Şablon paketi `deep-ricochet/tools/generate_mine_rooms.gd` ile deterministik olarak yeniden üretilebilir.

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
- Birbirinin ardından açılan üç maden/seviye ve maden seçim ekranı
- Her madende 2 başlangıç, 6 geniş geçit ve 6 dar damar olmak üzere 14; toplam 42 doğrulanan oda şablonu
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
- Dil, ayrı efekt/müzik seviyeleri, titreşim, ekran sarsıntısı, grafik/performans modu ve onaylı tüm veri silme seçeneklerini içeren ayarlar ekranı
- Android geri tuşunun menü, ayarlar, öğretici, sonuç ve duraklatma katmanlarına uygun davranması
- Android 9 (API 28) alt sınırı ve API 35 hedefi için ARMv7 Gradle export preseti
- Assetlerle uyumlu prosedürel hasar halkası ve blok kırılma parçacıkları
- Brief paletine uyumlu ortak maden arka planı, yuvarlatılmış panel ve düğme sistemi
- Ana menü, oyun HUD'ı, rota, sonuç, duraklatma, ayarlar ve öğreticide tutarlı UI dili
- CC0 lisanslı darbe, kırılma, arayüz ve sonuç sesleri
- Her yaylımda sıfırlanan Re minör pentatonik melodik çarpışma dizisi
- Normal blok, cevher, sert kaya ve çekirdek için ayrı ses katmanları
- Kodla üretilen düşük seviyeli döngüsel maden atmosferi
- Kalıcı ve birbirinden bağımsız efekt/müzik açma-kapama ve seviye ayarları

## P1 ilk aşama

- Sonuç ekranında biten koşunun seed'i ve ilk oda seçimi korunarak **Aynı Madeni Dene** seçeneği
- Aynı seed tekrarında istatistik kaydının yeni koşu olarak işlenmesini sağlayan benzersiz koşu kimliği
- Oynanış sırasında 1× ve 2× arasında değiştirilebilen, sabit fizik adımını koruyan simülasyon hızı
- Normal blok, cevher ve çekirdek için renk ve şiddeti ayrışan; aynı anda en fazla 16 darbe animasyonu tutan hafif görsel efektler
- Cevher ve çekirdek vuruşlarında ayrışan ses tonu; mevcut ses yığılma sınırı korunarak düşük maliyetli ses cilası
- Android'de blok kırılması ve çekirdeğin kırılması için kısa, farklı şiddette ve 90 ms aralıkla sınırlanan titreşim
- Ayarlar ekranında kalıcı titreşim açma-kapama seçeneği ve eski ayar kayıtları için şema geçişi
- Üç madenin her biri için dört odalık koşu; ilk oda başlangıç havuzundan, sonraki üç oda geniş geçit/dar damar rota çiftlerinden seçilir
- Her maden için yedi temel düzenin yatay aynalarıyla oluşturulan 14 şablon; toplam 42 seed tabanlı şablon
- Bir madeni başarıyla bitirince sıradakini açan seviye ilerlemesi, maden bazında en iyi skor ve tamamlanma sayısı
- Her gün aynı yerel tarih için aynı seed'i kullanan, ilerleme kilitlerini etkilemeyen günlük maden
- Düşük maliyetli efekt sınırı ve azaltılmış sarsıntı kullanan **Performans** modu ile daha yoğun görsel cila sunan **Grafik** modu

2× seçeneği topların fizik hızını veya çarpışma sonuçlarını değiştirmez; her çizim karesinde iki sabit simülasyon adımı çalıştırır. Yeni koşu ve aynı seed tekrarı 1× hızda başlar. Titreşim yalnızca Android özelliği algılandığında çağrılır; masaüstü testleri ve diğer platformlarda devre dışı kalır.

Aktif koşu `user://deep_ricochet_active_run.json` konumuna yazılır; önceki geçerli kayıt `.bak` uzantısıyla korunur. Geçerli ve bitmemiş bir kayıt uygulama açılışında ana menüde `Devam` düğmesini etkinleştirir. Kesilmiş atışta canlı top konumları yüklenmez; atış öncesindeki kararlı oda geri gelir. Maden kimliği, normal/günlük koşu türü ve günlük tarih anahtarını taşıyan aktif snapshot şeması sürüm 4'tür. İçerik sürümüyle uyuşmayan eski geliştirme koşuları güvenli biçimde reddedilir; profil ve ayarlar kendi şema geçişleriyle korunur.

Duraklatma menüsünden ana menüye dönüldüğünde kararlı koşu korunur. Bir yaylım sürüyorsa diskteki atış öncesi snapshot kullanılır; böylece yarım simülasyon kaydedilmez. Uygulama arka plana geçtiğinde oyun otomatik durur, fakat öne döndüğünde kendiliğinden devam etmez.

Profil `user://deep_ricochet_profile.json`; dil, ses, titreşim, ekran sarsıntısı ve kalite modu tercihleri `user://deep_ricochet_settings.json` konumunda aktif koşudan bağımsız tutulur. Profil şeması maden kilitlerini, maden bazındaki istatistikleri ve o günün günlük maden sonucunu da saklar. Her iki dosya geçici dosya ve son geçerli yedek kullanır. Yeni oyun aktif koşuyu değiştirirken rekor ve ayarları korur; ayarlardaki açık onaylı `Tüm Verileri Sil` işlemi aktif koşuyu, profili ve ayarları birlikte temizler.

Ses sistemi `deep-ricochet/audio/audio_manager.gd` otomatik yüklemesi üzerinden çalışır. Aynı anda gelen çarpışmalar 45 ms aralıkla sınırlandırılır; böylece sekiz topluk yaylımda sesler üst üste yığılıp bozulmaz. Arka plan atmosferi çalışma anında kodla üretilir; kullanılan Kenney efektlerinin kaynak ve lisans bilgileri `deep-ricochet/audio/THIRD_PARTY_AUDIO.md` dosyasındadır.

UI renkleri, panel biçimleri, düğme türleri ve prosedürel maden arka planı `deep-ricochet/ui/ui_theme.gd` içinde ortaklaştırılmıştır. Hareketli oyun ekranında yeniden kullanılan stil kaynakları önbelleğe alınır; menü ekranları aynı dokunma alanlarını korurken ortak görsel dili paylaşır.

Şablonlardaki örnek açı dizileri otomatik simülasyonda çekirdeği kırmaktadır; gerçek Android cihaz arka plan/geri dönüş, dokunmatik geçişleri ve hoparlör ses dengesi ayrıca doğrulanacaktır.

## Android dışa aktarma

`deep-ricochet/export_presets.cfg` içindeki **Android** preseti Android 9 ve üzerini, API 35 hedefini ve Galaxy A10 için ARMv7 mimarisini kullanır. Çevrimdışı çalışan uygulamanın tek ek Android izni titreşim geri bildirimi için `VIBRATE` iznidir; kullanıcıdan çalışma anında izin penceresi istemez. P0/P1 dağıtım hedefi Google Play değil, cihaza doğrudan yüklenen debug APK prototipidir. Paket kimliği şimdilik `com.ysturan.deepricochet` değeridir.

Godot 4.7.2 ile ilk APK'yı üretmeden önce:

1. **Editor → Manage Export Templates** içinden tam olarak `4.7.2.stable` Android export şablonunu kurun.
2. **Editor Settings → Export → Android** altında Java SDK yolunu Android Studio'nun `jbr` klasörüne, Android SDK yolunu içinde `platform-tools/adb` bulunan SDK klasörüne ayarlayın.
3. **Project → Install Android Build Template** ile Gradle şablonunu projeye kurun. Oluşan `deep-ricochet/android/` dizini makine üretimi olduğu için Git'e alınmaz.
4. Debug APK için Godot'un Export ekranındaki **Export Project** düğmesini veya aşağıdaki komutu kullanın:

```text
godot --headless --path deep-ricochet --export-debug Android build/android/deep-ricochet-debug.apk
```

Temiz bir checkout'ta aynı akışı doğrulayan PowerShell betiği de kullanılabilir. Betik Godot sürümünü denetler, eksikse Android Gradle build şablonunu kurar, kaynakları içe aktarır ve ARMv7 debug APK'yı üretir:

```powershell
.\deep-ricochet\tools\build_android_debug.ps1 `
  -GodotPath "C:\path\to\Godot_v4.7.2-stable_win64.exe"
```

Google Play sürümü P0 kapsamı dışındadır. İleride mağaza dağıtımına geçilirse AAB, güncel hedef API, ARM64 ve depoya eklenmeyen özel bir release keystore ayrıca yapılandırılmalıdır.

## Otomatik test

Godot komut satırından proje kökünde şu sahne çalıştırılır:

```text
godot --headless --path deep-ricochet --scene res://tests/smoke_test.tscn
```

Test; profil ve ayar geçişlerini, maden kilitleri ile günlük maden istatistiklerini, grafik/performans tercihini, titreşim ayarı ile eski ayar şeması göçünü, efekt/müzik bus'larını, melodik çarpışma hız sınırını, sessiz modu, profil yedeğinden kurtarmayı, iki dili, üç aşamalı ilk-oyun öğreticisini, tüm veri silme hata davranışını, ayrıntılı oda sonuç geçmişini, aynı seed tekrarını, 1×/2× sabit adımlı simülasyonu, ana menü ve devam durumunu, nişan sırasında duraklatmayı, canlı yaylımın donmasını, odak kaybını, üç madendeki 42 oda şablonunu, örnek açı geçişlerini, maden başına 100 seed seçimini, dört oda/üç rota akışını, atış ortası kurtarmayı, bozuk kayıt reddini, fiziği ve puanı doğrular. Ayrıca 42 odanın örnek açı simülasyon süresini test çıktısında `[PERF]` satırıyla raporlar.
