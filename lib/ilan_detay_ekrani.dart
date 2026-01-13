// KOD BLOK BAŞLANGICI (ilan_detay_ekrani.dart - DİNAMİK FİYAT VE DÜZENLEME MODU GÜNCELLEMESİ)
import 'package:flutter/material.dart';
import 'ilan_ozet_ekrani.dart';

class IlanDetayEkrani extends StatefulWidget {
  // Bu ekrana dışarıdan gelen veriler (Adım 1'den)
  final String alinacakAdres;
  final String teslimAdres;
  final double alinacakAdresLat;
  final double alinacakAdresLng;
  final double teslimAdresLat;
  final double teslimAdresLng;

  // --- YENİ EKLENDİ (DÜZENLEME MODU İÇİN) ---
  // Eğer bu ekran "Düzenleme" için açılırsa, bu veriler dolu gelecek.
  // Eğer "Yeni İlan" için açılırsa, 'null' gelecekler.
  final String? mevcutIlanId; // Düzenlenecek ilanın ID'si
  final Map<String, dynamic>? mevcutIlanVerisi; // Düzenlenecek ilanın verisi
  // --- YENİ EKLEME SONU ---

  const IlanDetayEkrani({
    super.key,
    // Zorunlu alanlar (Adım 1'den)
    required this.alinacakAdres,
    required this.teslimAdres,
    required this.alinacakAdresLat,
    required this.alinacakAdresLng,
    required this.teslimAdresLat,
    required this.teslimAdresLng,
    
    // Opsiyonel alanlar (Düzenleme modu için)
    this.mevcutIlanId,
    this.mevcutIlanVerisi,
  });

  @override
  State<IlanDetayEkrani> createState() => _IlanDetayEkraniState();
}

class _IlanDetayEkraniState extends State<IlanDetayEkrani> {
  final _paketIcerikController = TextEditingController();
  // Varsayılan seçim "Küçük" [true, false, false]
  final List<bool> _secimler = [true, false, false];

  // --- GÜNCELLENDİ (DİNAMİK FİYAT İÇİN) ---
  // Varsayılan değerler "Küçük" pakete göre ayarlandı
  double _teklifEdilenUcret = 40.0;
  double _minUcret = 25.0;
  double _maxUcret = 100.0;

  // Ekranın "Düzenleme Modunda" olup olmadığını tutar
  bool _isEditMode = false;
  // --- GÜNCELLEME SONU ---

  @override
  void initState() {
    super.initState();
    
    // --- YENİ EKLENDİ (DÜZENLEME MODU KONTROLÜ) ---
    // Ekran açılırken 'mevcutIlanVerisi' dolu geldiyse,
    // bu "Düzenleme Modu" demektir. Alanları doldur.
    if (widget.mevcutIlanId != null && widget.mevcutIlanVerisi != null) {
      _isEditMode = true;
      final data = widget.mevcutIlanVerisi!;
      
      // 1. Paket içeriğini doldur
      _paketIcerikController.text = data['paketIcerigi'] ?? '';
      
      // 2. Paket boyutunu seç
      final String paketBoyutu = data['paketBoyutu'] ?? 'Küçük';
      int seciliIndex = 0;
      if (paketBoyutu == 'Orta') {
        seciliIndex = 1;
      } else if (paketBoyutu == 'Büyük') {
        seciliIndex = 2;
      }
      
      // 3. Fiyatı ve Slider'ı ayarla
      // (ToggleButtons'ı programatik olarak tetikliyoruz)
      _fiyatBaremGuncelle(seciliIndex); 
      _teklifEdilenUcret = (data['teklif'] as num? ?? _teklifEdilenUcret).toDouble();

    } else {
      // Yeni ilan modu, varsayılan değerler zaten ayarlı
      // (Küçük paket: 40 TL, Min: 25, Max: 100)
    }
    // --- YENİ EKLEME SONU ---
  }


  void _fiyatBaremGuncelle(int index) {
    setState(() {
      // 1. Seçimi güncelle
      for (int i = 0; i < _secimler.length; i++) {
        _secimler[i] = (i == index);
      }

      // 2. Fiyat baremini ve varsayılan teklifi güncelle
      if (index == 0) { // Küçük
        _minUcret = 25.0;
        _maxUcret = 100.0;
        _teklifEdilenUcret = 40.0;
      } else if (index == 1) { // Orta
        _minUcret = 50.0;
        _maxUcret = 250.0;
        _teklifEdilenUcret = 80.0;
      } else if (index == 2) { // Büyük
        _minUcret = 100.0;
        _maxUcret = 500.0;
        _teklifEdilenUcret = 150.0;
      }

      // Eğer mevcut teklif yeni baremin dışındaysa, onu bareme geri çek
      if (_teklifEdilenUcret < _minUcret) _teklifEdilenUcret = _minUcret;
      if (_teklifEdilenUcret > _maxUcret) _teklifEdilenUcret = _maxUcret;
    });
  }
  // --- YENİ EKLEME SONU ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF212121),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          // --- GÜNCELLENDİ (MODA GÖRE BAŞLIK) ---
          _isEditMode ? 'İlanı Düzenle' : '2/3: Detaylar ve Fiyat',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _paketIcerikController,
              decoration: InputDecoration(
                labelText: 'Paket İçeriği',
                hintText: 'Örn: Kitap, Doğum Günü Hediyesi',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Paket Boyutunu Seçin:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            
            // --- GÜNCELLENDİ (DİNAMİK FİYAT İÇİN) ---
            ToggleButtons(
              isSelected: _secimler,
              onPressed: (int index) {
                // Toggle'a basıldığında yeni yardımcı fonksiyonu çağır
                _fiyatBaremGuncelle(index);
              },
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              selectedBorderColor: Color(0xFF32D74B),
              selectedColor: Colors.white,
              fillColor: Color(0xFF32D74B),
              color: Color(0xFF212121),
              children: const [
                Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Küçük')),
                Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Orta')),
                Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Büyük')),
              ],
            ),
            // --- GÜNCELLEME SONU ---
            
            const SizedBox(height: 24),
            Text(
              'Teklif Ettiğiniz Ücret: ${_teklifEdilenUcret.toStringAsFixed(0)} TL',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
            ),

            // --- GÜNCELLENDİ (DİNAMİK FİYAT İÇİN) ---
            Slider(
              value: _teklifEdilenUcret,
              min: _minUcret, // Artık dinamik
              max: _maxUcret, // Artık dinamik
              // Bölüm sayısını 5 TL'lik artışlara göre ayarla
              divisions: (_maxUcret - _minUcret) ~/ 5, 
              label: '${_teklifEdilenUcret.round()} TL',
              activeColor: Color(0xFF32D74B),
              onChanged: (double newValue) {
                setState(() {
                  _teklifEdilenUcret = newValue;
                });
              },
            ),
            // --- GÜNCELLEME SONU ---
            
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF32D74B),
                minimumSize: const Size(double.infinity, 50),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                // BUTONA BASILDIĞINDA: Tüm verileri topla
                final paketIcerigi = _paketIcerikController.text;
                final teklif = _teklifEdilenUcret;
                final seciliIndex = _secimler.indexWhere((element) => element == true);
                final paketBoyutu = ['Küçük', 'Orta', 'Büyük'][seciliIndex];

                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => IlanOzetEkrani(
                        // Mevcut veriler (Adım 1'den)
                        alinacakAdres: widget.alinacakAdres,
                        teslimAdres: widget.teslimAdres,
                        alinacakAdresLat: widget.alinacakAdresLat,
                        alinacakAdresLng: widget.alinacakAdresLng,
                        teslimAdresLat: widget.teslimAdresLat,
                        teslimAdresLng: widget.teslimAdresLng,

                        // Bu ekranda seçilen veriler
                        paketIcerigi: paketIcerigi,
                        paketBoyutu: paketBoyutu,
                        teklif: teklif,

                        // --- YENİ EKLENDİ (DÜZENLEME MODU İÇİN) ---
                        // Eğer düzenleme modundaysak, ilan ID'sini de özet ekranına taşı
                        mevcutIlanId: widget.mevcutIlanId,
                        // --- YENİ EKLEME SONU ---
                      ),
                    ),
                  );
                }
              },
              // --- GÜNCELLENDİ (MODA GÖRE BUTON YAZISI) ---
              child: Text(_isEditMode ? 'GÜNCELLEMEYİ GÖZDEN GEÇİR' : 'İlANI GÖZDEN GEÇİR'),
            ),
          ],
        ),
      ),
    );
  } 
}
// KOD BLOK SONU