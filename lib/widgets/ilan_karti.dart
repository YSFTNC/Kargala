// KOD BLOK BAŞLANGICI (ilan_karti.dart - YENİDEN TASARLANDI)
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // <<< YENİ İMPORT: SVG kullanımı için
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kargala/ilan_detay_tasiyici_ekrani.dart';
import '../ilan_detay_tasiyici_ekrani.dart'; // <<< '..' ekleyerek bir üst klasöre çıkın

class IlanKarti extends StatelessWidget {
  final Map<String, dynamic> ilanVerisi;
  final String ilanId;

  const IlanKarti({
    super.key,
    required this.ilanVerisi,
    required this.ilanId,
  });

  @override
  Widget build(BuildContext context) {
    // Verileri okuma (önceki gibi)
    final String alinacakAdres = ilanVerisi['alinacakAdres'] as String? ?? 'Adres bilinmiyor';
    final String teslimAdres = ilanVerisi['teslimAdres'] as String? ?? 'Adres bilinmiyor';
    final String paketIcerigi = ilanVerisi['paketIcerigi'] as String? ?? 'Bilinmiyor';
    final String paketBoyutu = ilanVerisi['paketBoyutu'] as String? ?? 'Bilinmiyor';
    final String teklif = (ilanVerisi['teklif'] as num? ?? 0).toStringAsFixed(0);
    final String gondericiId = ilanVerisi['kullaniciId'] as String? ?? '';

    // Geçici olarak varsayılan foto URL'si
    final String defaultProfilePic = "https://firebasestorage.googleapis.com/v0/b/kargala-65983.appspot.com/o/default_profile_pic.png?alt=media&token=e9f4a0c8-662f-4886-9a2c-9d6e409b691d";

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // İlan detay ekranına git
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IlanDetayTasiyiciEkrani(
                ilanId: ilanId,
                ilanVerisi: ilanVerisi,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. Satır: Gönderici Bilgisi ---
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('kullanicilar').doc(gondericiId).get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Row(
                      children: [
                        CircleAvatar(radius: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('Yükleniyor...', style: TextStyle(fontSize: 14)),
                      ],
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                    return Row(
                      children: [
                        CircleAvatar(radius: 18, backgroundImage: NetworkImage(defaultProfilePic)),
                        const SizedBox(width: 10),
                        const Text('Gönderici Bilinmiyor', style: TextStyle(fontSize: 14, color: Colors.grey)),
                      ],
                    );
                  }

                  final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                  final gondericiAdi = ("${data['ad'] ?? ''} ${data['soyad'] ?? ''}").trim();
                  final fotoUrl = data['profilFotoUrl'];

                  return Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty) ? NetworkImage(fotoUrl) : NetworkImage(defaultProfilePic),
                        child: (fotoUrl == null || fotoUrl.isEmpty) ? Icon(Icons.person, size: 18, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          gondericiAdi.isNotEmpty ? gondericiAdi : (data['email'] ?? 'Gönderici'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const Divider(height: 24, thickness: 0.5, color: Colors.grey),

              // --- 2. Satır: Rota (YENİ GÖRÜNÜM) ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SvgPicture.asset() yerine SvgPicture.string() kullanıyoruz
                  SvgPicture.string(
                    _getPinSvg(Colors.blue), // Başlangıç pini mavi
                    height: 20,
                    width: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      alinacakAdres,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 4, bottom: 4),
                child: Icon(Icons.more_vert, size: 16, color: Colors.grey[400]),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SvgPicture.string(
                    _getPinSvg(Colors.red), // Bitiş pini kırmızı
                    height: 20,
                    width: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      teslimAdres,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- 3. Satır: Paket İçeriği ve Boyutu ---
              Row(
                children: [
                  const Icon(Icons.category_outlined, size: 20, color: Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$paketIcerigi ($paketBoyutu)',
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- 4. Satır: Teklif ---
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  '$teklif TL',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF32D74B), // Tema rengi
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- YARDIMCI FONKSİYON: DİNAMİK RENKLİ SVG PIN ---
  // https://fonts.google.com/icons?selected=Material%20Icons%3Alocation_on&icon.platform=flutter&icon.query=pin
  String _getPinSvg(Color color) {
    String hexColor = '#${color.value.toRadixString(16).substring(2)}';
    return '''
<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 -960 960 960" width="24">
  <path fill="${hexColor}" d="M480-120q-150 0-255-105T120-480q0-150 105-255T480-840q150 0 255 105T840-480q0 150-105 255T480-120Zm0-360q33 0 56.5-23.5T560-560q0-33-23.5-56.5T480-640q-33 0-56.5 23.5T400-560q0 33 23.5 56.5T480-480Zm0 280q83 0 141.5-58.5T680-480q0-83-58.5-141.5T480-680q-83 0-141.5 58.5T280-480q0 83 58.5 141.5T480-200Zm0-280Z"/>
</svg>
    ''';
  }
}
// KOD BLOK SONU