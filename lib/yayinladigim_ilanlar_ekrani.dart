// KOD BLOK BAŞLANGICI (yayinladigim_ilanlar_ekrani.dart - QR KOD GÖSTERİMİ EKLENDİ)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart'; // <<< YENİ: QR KOD KÜTÜPHANESİ
import 'teklifleri_gor_ekrani.dart'; 
import 'sohbet_ekrani.dart'; 
import 'ilan_detay_ekrani.dart'; 

class YayinladigimIlanlarEkrani extends StatefulWidget {
  const YayinladigimIlanlarEkrani({super.key});

  @override
  State<YayinladigimIlanlarEkrani> createState() => _YayinladigimIlanlarEkraniState();
}

class _YayinladigimIlanlarEkraniState extends State<YayinladigimIlanlarEkrani> {
  late final User? user;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
  }

  // --- YENİ FONKSİYON: QR KOD PENCERESİ ---
  void _qrKoduGoster(BuildContext context, String teslimatKodu) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Teslimat Kodu", textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min, // Pencereyi içeriğe göre küçültür
            children: [
              const Text("Kuryeye bu kodu okutun veya söyleyin:", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              
              // 1. QR KOD
              SizedBox(
                width: 200,
                height: 200,
                child: QrImageView(
                  data: teslimatKodu, // QR'a dönüşecek kod
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 2. MANUEL KOD (Büyük Punto)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  teslimatKodu, 
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 5, color: Colors.black87),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Kapat"),
            ),
          ],
        );
      },
    );
  }
  // --- YENİ FONKSİYON SONU ---

  Future<void> _ilaniIptalEt(String ilanId) async {
    final bool? onay = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('İlanı İptal Et'),
          content: const Text('Bu ilanı iptal etmek istediğinize emin misiniz?'),
          actions: <Widget>[
            TextButton(child: const Text('Hayır'), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(child: const Text('Evet', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );

    if (onay == true) {
      await FirebaseFirestore.instance.collection('aktifIlanlar').doc(ilanId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İlan iptal edildi.')));
      }
    }
  }

  void _ilaniDuzenle(String ilanId, Map<String, dynamic> ilanVerisi) {
    // Adres verilerini ayrıştır (GeoPoint vb.)
    // Basitlik için sadece gerekli alanları gönderiyoruz
    final double alinacakLat = (ilanVerisi['alinacakKonumGeoPoint'] as GeoPoint).latitude;
    final double alinacakLng = (ilanVerisi['alinacakKonumGeoPoint'] as GeoPoint).longitude;
    final double teslimLat = (ilanVerisi['teslimKonumGeoPoint'] as GeoPoint).latitude;
    final double teslimLng = (ilanVerisi['teslimKonumGeoPoint'] as GeoPoint).longitude;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IlanDetayEkrani(
          alinacakAdres: ilanVerisi['alinacakAdres'],
          teslimAdres: ilanVerisi['teslimAdres'],
          alinacakAdresLat: alinacakLat,
          alinacakAdresLng: alinacakLng,
          teslimAdresLat: teslimLat,
          teslimAdresLng: teslimLng,
          mevcutIlanId: ilanId,       // Düzenleme modu için
          mevcutIlanVerisi: ilanVerisi, // Verileri doldurmak için
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text("Giriş yapmalısınız."));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yayınladığım İlanlar'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('aktifIlanlar')
            .where('kullaniciId', isEqualTo: user!.uid)
            .orderBy('yayinlanmaTarihi', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Henüz yayınladığınız bir ilan yok.'));
          }

          final ilanlar = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: ilanlar.length,
            itemBuilder: (context, index) {
              final ilanVerisi = ilanlar[index].data() as Map<String, dynamic>;
              final ilanId = ilanlar[index].id;
              
              final durum = ilanVerisi['durum'] as String? ?? 'Aktif';
              final alinacakAdres = ilanVerisi['alinacakAdres'] as String? ?? '...';
              final teslimAdres = ilanVerisi['teslimAdres'] as String? ?? '...';
              final teklif = (ilanVerisi['teklif'] as num? ?? 0).toStringAsFixed(0);
              final teklifSayisi = (ilanVerisi['teklifVerenler'] as List?)?.length ?? 0;
              final teslimatKodu = ilanVerisi['teslimatKodu'] as String? ?? '0000'; // Kod verisi

              // Duruma göre renk ve ikon seçimi
              Color durumRengi = Colors.green;
              IconData durumIkonu = Icons.check_circle_outline;
              
              if (durum == 'Aktif') {
                durumRengi = Colors.orange;
                durumIkonu = Icons.hourglass_empty;
              } else if (durum == 'Anlaşıldı') {
                durumRengi = Colors.blue;
                durumIkonu = Icons.handshake;
              } else if (durum == 'Tamamlandı') {
                durumRengi = Colors.grey;
                durumIkonu = Icons.check_circle;
              }

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Durum Başlığı
                      Row(
                        children: [
                          Icon(durumIkonu, color: durumRengi, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            durum.toUpperCase(), 
                            style: TextStyle(fontWeight: FontWeight.bold, color: durumRengi)
                          ),
                          const Spacer(),
                          if (durum == 'Aktif')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                              child: Text('$teklifSayisi Teklif', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const Divider(),

                      // 2. Rota
                      Text('$alinacakAdres ➔ $teslimAdres', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      
                      // 3. Alt Butonlar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // --- DURUMA GÖRE DEĞİŞEN BUTONLAR ---
                          if (durum == 'Aktif') ...[
                            // Aktifse: Teklifleri Gör veya Düzenle/İptal
                            if (teklifSayisi > 0)
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => TeklifleriGorEkrani(ilanId: ilanId, ilanVerisi: ilanVerisi)));
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                child: const Text("TEKLİFLERİ GÖR"),
                              )
                            else
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    label: const Text('Düzenle'),
                                    onPressed: () => _ilaniDuzenle(ilanId, ilanVerisi),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    label: const Text('İptal'),
                                    onPressed: () => _ilaniIptalEt(ilanId),
                                  ),
                                ],
                              ),
                          ] 
                          else if (durum == 'Anlaşıldı') ...[
                            // --- YENİ: ANLAŞILDIYSA QR KOD GÖSTER BUTONU ---
                            ElevatedButton.icon(
                              onPressed: () => _qrKoduGoster(context, teslimatKodu),
                              icon: const Icon(Icons.qr_code),
                              label: const Text("TESLİMAT KODUNU GÖSTER"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                            ),
                            
                            // Sohbet Butonu (Opsiyonel)
                            IconButton(
                              icon: const Icon(Icons.message, color: Colors.blue),
                              onPressed: () {
                                // Sohbet ekranına git
                                // Not: Karşı tarafın adını çekmek için burada ekstra işlem gerekebilir
                                // Şimdilik basitçe açıyoruz
                                Navigator.push(context, MaterialPageRoute(builder: (context) => SohbetEkrani(
                                  ilanId: ilanId, 
                                  gondericiId: user!.uid, 
                                  tasiyiciId: ilanVerisi['tasiyiciId'], 
                                  konusulanKisiAdi: "Taşıyıcı"
                                )));
                              },
                            )
                          ],

                          // Fiyat Bilgisi
                          Text(
                            '$teklif TL',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF32D74B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
// KOD BLOK SONU