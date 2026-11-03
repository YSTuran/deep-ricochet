# Deep Ricochet

Deep Ricochet, dikey ekranda oynanan nişan alma ve sekme odaklı bir mobil oyun prototipidir. Oyuncu topları fırlatır; normal blokları, cevher bloklarını ve çekirdeği kırmaya çalışırken sert kayalardan ve duvarlardan yararlanır.

## Dizin yapısı

- `deep-ricochet/`: Godot projesi ve çalıştırılabilir oyun kaynakları.
- `assets/`: Orijinal görseller, üretim notları ve asset manifesti.

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
3. Projeyi açıp **F6** ile test odasını veya **F5** ile ana sahneyi çalıştırın.

Test odasında fareyle ya da dokunmatik ekranla basılı tutup yön seçilir; bırakıldığında top fırlatılır. Kesikli nişan çizgisi gerçek atışla aynı fizik simülatörünü kullanır.

## P0 mevcut durum

- Sabit zaman adımlı top hareketi ve duvar sekmesi
- Alt sınırda top toplama
- Kare normal, cevher ve sert kaya çarpışmaları
- Dairesel çekirdek çarpışması
- Normal, cevher ve çekirdek için can/hasar sistemi
- Aynı temas sırasında yinelenen hasarı engelleme
- Simülasyon tabanlı nişan önizlemesi

Ses, çoklu top salvosu, oda akışı ve kalıcı ilerleme sonraki P0 adımlarında eklenecektir.

## Otomatik test

Godot komut satırından proje kökünde şu sahne çalıştırılır:

```text
godot --headless --path deep-ricochet res://tests/smoke_test.tscn
```

Test; duvarları, toplayıcıyı, blok hasarını, sert kaya sekmesini, çekirdeğin dairesel çarpışmasını, temas korumasını ve nişan önizlemesini doğrular.
