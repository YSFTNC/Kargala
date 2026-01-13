// KOD BLOK BAŞLANGICI (ilan_ozet_ekrani.dart - GÜNCELLEME MODU EKLENDİ)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Artık 'geoflutterfire_plus' paketiyle işimiz yok, o yüzden basit GeoPoint kullanıyoruz

class IlanOzetEkrani extends StatelessWidget {
  // 1. ADIM: Tüm veriler (Mevcuttu)
  final String alinacakAdres;
  final String teslimAdres;
  final String paketIcerigi;
  final String paketBoyutu;
  final double teklif;
  final double alinacakAdresLat;
  final double alinacakAdresLng;
  final double teslimAdresLat;
  final double teslimAdresLng;

  // --- YENİ EKLENDİ (DÜZENLEME MODU İÇİN) ---
  final String? mevcutIlanId;
  // --- YENİ EKLEME SONU ---

  // 2. ADIM: Constructor güncellendi
  const IlanOzetEkrani({
    super.key,
    required this.alinacakAdres,
    required this.teslimAdres,
    required this.paketIcerigi,
    required this.paketBoyutu,
    required this.teklif,
    required this.alinacakAdresLat,
    required this.alinacakAdresLng,
    required this.teslimAdresLat,
    required this.teslimAdresLng,
    
    // --- YENİ EKLENDİ ---
    this.mevcutIlanId, // Opsiyonel
  });

  @override
  Widget build(BuildContext context) {
    // --- YENİ EKLENDİ: Mod kontrolü ---
    final bool isEditMode = (mevcutIlanId != null);
    // --- YENİ EKLEME SONU ---

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF212121),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          // --- GÜNCELLENDİ (MODA GÖRE BAŞLIK) ---
          isEditMode ? 'Özeti Onayla (Düzenle)' : '3/3: Özet ve Onay',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... (Tüm ListTile'larınız aynı kalıyor)
            const Text(
              'Lütfen İlan Bilgilerini Kontrol Edin:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.location_on_outlined, color: Colors.red),
              title: Text('Alınacak Adres'),
              subtitle: Text(alinacakAdres), 
            ),
            ListTile(
              leading: Icon(Icons.flag_outlined, color: Colors.green),
              title: Text('Teslim Edilecek Adres'),
              subtitle: Text(teslimAdres), 
            ),
            ListTile(
              leading: Icon(Icons.inventory_2_outlined, color: Colors.blue),
              title: Text('Paket İçeriği'),
              subtitle: Text('$paketIcerigi ($paketBoyutu)'), 
            ),
            ListTile(
              leading: Icon(Icons.paid_outlined, color: Color(0xFF212121)),
              title: Text('Teklif Ettiğiniz Ücret'),
              subtitle: Text('${teklif.toStringAsFixed(0)} TL'), 
            ),
            
            const Spacer(),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF32D74B),
                minimumSize: const Size(double.infinity, 50),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  // ... (hata gösterme kodunuz aynı)
                  return; 
                }

                // --- GÜNCELLENDİ (Veritabanı haritası) ---
                Map<String, dynamic> ilanVerisi = {
                  'alinacakAdres': alinacakAdres,
                  'teslimAdres': teslimAdres,
                  'paketIcerigi': paketIcerigi,
                  'paketBoyutu': paketBoyutu,
                  'teklif': teklif,
                  'durum': 'Aktif', // Düzenlense bile durumu 'Aktif' kalır
                  'kullaniciId': user.uid, 
                  
                  // Basit GeoPoint kaydı (Mevcuttu)
                  'alinacakKonumGeoPoint': GeoPoint(alinacakAdresLat, alinacakAdresLng),
                  'teslimKonumGeoPoint': GeoPoint(teslimAdresLat, teslimAdresLng),
                  
                  // 'yayinlanmaTarihi' sadece yeni ilanda eklenir
                  // Eğer düzenleme modundaysak, bu tarihi güncellememeliyiz.
                  if (!isEditMode)
                    'yayinlanmaTarihi': FieldValue.serverTimestamp(),
                    
                  // Teklif verenler listesi (düzenleme modunda bu listeyi sıfırlamamalıyız)
                  if (!isEditMode)
                    'teklifVerenler': [],
                };
                // --- GÜNCELLEME SONU ---

                try {
                  // --- GÜNCELLENDİ (MODA GÖRE KAYDETME) ---
                  if (isEditMode) {
                    // Düzenleme Modu: .update() kullan
                    await FirebaseFirestore.instance
                        .collection('aktifIlanlar')
                        .doc(mevcutIlanId)
                        .update(ilanVerisi);
                        
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ İlan Başarıyla Güncellendi!')),
                      );
                      // Önce özet ekranını, sonra detay ekranını kapat
                      Navigator.of(context).popUntil((route) => route.isFirst); 
                    }
                    
                  } else {
                    // Yeni İlan Modu: .add() kullan
                    await FirebaseFirestore.instance.collection('aktifIlanlar').add(ilanVerisi);
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ İlanınız Başarıyla Yayınlandı!')),
                      );
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  }
                  // --- GÜNCELLEME SONU ---
                  
                } catch (e) {
                   if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Hata oluştu: İlan yayınlanamadı/güncellenemedi.')),
                      );
                  }
                }
              },
              // --- GÜNCELLENDİ (MODA GÖRE BUTON YAZISI) ---
              child: Text(isEditMode ? 'İLANI GÜNCELLE' : 'İLANI YAYINLA'),
            ),
          ],
        ),
      ),
    );
  }
}
// KOD BLOK SONU