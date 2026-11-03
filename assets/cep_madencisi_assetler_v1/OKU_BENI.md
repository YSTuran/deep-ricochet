# Cep Madencisi - Başlangıç asset seti v1

Bu set, ürün briefindeki ortak görsel dile göre hazırlanmış üç ayrı oyun parçasıdır. PDF ekran görüntüsünden kırpılmamıştır; aynı görsel referans kullanılarak Imagegen ile ayrı ayrı üretilmiştir.

## Dosyalar

- `blok_normal.png`: Mavi, yazısız normal blok.
- `blok_cevher.png`: Altın renkli, küçük elmas simgeli, yazısız cevher bloğu.
- `cekirdek.png`: Mint renkli, yazısız çekirdek.
- `stil_referansi.png`: Yalnızca ortak görünümü anlatan tasarım referansı; oyun sprite’ı değildir.
- `asset_manifest.json`: Gerçek dosya boyutları, şeffaflık ve yerleşim bilgileri.
- `uretim_promptlari.json`: Üretim yöntemi, referans ve kullanılan promptlar.

## Yazılımcıya kullanım notları

1. Bunlar durağan PNG görsellerdir. Dayanıklılık değerini görsele işleme; ayrı metin olarak oyun içinde göster.
2. Her dosyayı tek sprite olarak içe aktar. PNG şeffaflığını koru. Arka plana beyaz veya siyah dikdörtgen ekleme.
3. Blokları aynı hücre boyuna yerleştir; şeffaf kenar boşluğunu hesaba kat. Canvas boyutu ile görünen nesnenin boyutu aynı değildir. Dosyaların gerçek sınırları manifestte bulunur.
4. Görüntü başlangıç noktası merkezdir. Sayının yeri her dosya için değişebilir: normal blok merkez; cevher bloğunda elmasın altı; çekirdekte merkez.
5. Çarpışma şeklini resimdeki doku veya parıltıdan otomatik türetme. Oyun kurallarındaki kare blok ve daire çekirdek geometrisini ayrı kur.
6. Çekirdeğin dış parıltısı çarpışma alanı değildir. Topun hedefle temasını yalnızca çekirdeğin gövdesi üzerinden hesapla.
7. Gerçek telefon boyutunda özellikle 48-96 piksellik kullanımda okunurluğu kontrol et. Bu set henüz oyun motoruna alınmış veya cihazda test edilmiş değildir.
8. Hasar/kırılma animasyonu, efektler ve sesler bu başlangıç setinde bulunmaz. Işık yönünü ve renklerini sonraki assetlerde aynı tut.

## Ortak görsel dil

- Normal blok: arduvaz mavisi.
- Cevher: sıcak altın ve küçük elmas simgesi.
- Çekirdek: mint/teal, yuvarlak, dar parıltı.
- Işık: sol üst; alt sağ kenarda gölge.
- Stil: cepheden, hafif kabartılı, büyük ve sade kaya yüzeyleri.
- Bütün sayılar ve arayüz yazıları oyun içinde üretilir.

Bu dosyalar düzenlenebilir vektör veya katmanlı çizim değildir. Şeffaf raster başlangıç görselleridir; motor entegrasyonu ve gerçek boyutta son kontrol gerektirir.
