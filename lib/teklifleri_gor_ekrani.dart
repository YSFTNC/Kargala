// KOD BLOK BAŞLANGICI (teklifleri_gor_ekrani.dart - PUANLAMA LİNKİ EKLENDİ)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sohbet_ekrani.dart';
import 'degerlendirmeler_ekrani.dart'; //

class TeklifleriGorEkrani extends StatefulWidget {
  final String ilanId;
  final Map<String, dynamic> ilanVerisi;
  const TeklifleriGorEkrani({super.key, required this.ilanId, required this.ilanVerisi});
  @override
  State<TeklifleriGorEkrani> createState() => _TeklifleriGorEkraniState();
}

class _TeklifleriGorEkraniState extends State<TeklifleriGorEkrani> {
  User? _gondericiUser; 

  @override
  void initState() {
    super.initState();
    _gondericiUser = FirebaseAuth.instance.currentUser;
  }
  
  // Ana karta tıklandığında sohbete gider
  Future<void> _sohbeteGit(Map<String, dynamic> teklifVerisi, String tasiyiciId) async {
    // ... (Bu fonksiyonun içi aynı)
    if (_gondericiUser == null || !mounted) return;
    final String tasiyiciAdi = teklifVerisi['tasiyiciAdi'] as String? ?? 'Taşıyıcı';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SohbetEkrani(
          ilanId: widget.ilanId,
          gondericiId: _gondericiUser!.uid,
          tasiyiciId: tasiyiciId,
          konusulanKisiAdi: tasiyiciAdi,
        ),
      ),
    );
  }

  // Profil/değerlendirme geçmişine gider
  Future<void> _profiliGor(
    String tasiyiciId,
    num ortalamaPuan,
    int degerlendirmeSayisi,
  ) async {
    // ... (Bu fonksiyonun içi aynı ve düzeltilmiş hali)
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DegerlendirmelerEkrani(
          kullaniciId: tasiyiciId,
          ortalamaPuan: ortalamaPuan.toDouble(), // .toDouble() düzeltmesi
          degerlendirmeSayisi: degerlendirmeSayisi,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Gelen Teklifler')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('aktifIlanlar')
            .doc(widget.ilanId)
            .collection('gelenTeklifler')
            .orderBy('zaman', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error.toString()}"));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Henüz teklif gelmemiş."));

          final teklifler = snapshot.data!.docs;
          
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: teklifler.length,
            itemBuilder: (context, index) {
              final teklifBelgesi = teklifler[index];
              final teklifVerisi = teklifBelgesi.data() as Map<String, dynamic>? ?? {};
              final tasiyiciId = teklifBelgesi.id; 

              // Gerekli tüm verileri direkt okuyoruz
              final fotoUrl = teklifVerisi['tasiyiciFotoUrl'] as String?;
              final adSoyad = teklifVerisi['tasiyiciAdi'] as String? ?? 'Bilinmeyen';
              final sonTeklifFiyati = (teklifVerisi['teklifFiyati'] as num? ?? 0).toStringAsFixed(0);
              final sonTeklifiYapan = teklifVerisi['sonTeklifiYapan'] as String?;
              final ortalamaPuan = (teklifVerisi['tasiyiciOrtalamaPuan'] as num? ?? 0.0);
              final degerlendirmeSayisi = (teklifVerisi['tasiyiciDegerlendirmeSayisi'] as int? ?? 0);
              final gorevSayisi = (teklifVerisi['tasiyiciGorevSayisi'] as int? ?? 0);

              // ... (Pazarlık durumu yazısı aynı)
              String durumYazisi; 
              Color durumRengi;
              if (sonTeklifiYapan == 'gonderici') {
                durumYazisi = 'YANIT BEKLİYORSUNUZ';
                durumRengi = Colors.orange;
              } else {
                durumYazisi = 'YANITINIZ BEKLENİYOR';
                durumRengi = Colors.blue;
              }
              
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  // Ana kartın tıklaması sohbete gider
                  onTap: () => _sohbeteGit(teklifVerisi, tasiyiciId),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        // Fotoğraf tıklaması
                        InkWell(
                          onTap: () => _profiliGor(tasiyiciId, ortalamaPuan, degerlendirmeSayisi),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty) ? NetworkImage(fotoUrl) : null,
                            child: (fotoUrl == null || fotoUrl.isEmpty) ? const Icon(Icons.person, size: 30, color: Colors.grey) : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // İsim tıklaması
                              InkWell(
                                onTap: () => _profiliGor(tasiyiciId, ortalamaPuan, degerlendirmeSayisi),
                                child: Text(adSoyad, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                              const SizedBox(height: 4),

                              // --- YENİ: PUANLAMA BÖLÜMÜ TIKLANABİLİR YAPILDI ---
                              InkWell(
                                onTap: () => _profiliGor(tasiyiciId, ortalamaPuan, degerlendirmeSayisi),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min, // Sadece içerik kadar yer kapla
                                  children: [
                                    Icon(Icons.star, color: Colors.amber, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      ortalamaPuan.toStringAsFixed(1), 
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
                                    ),
                                    Text(
                                      ' ($degerlendirmeSayisi) · $gorevSayisi Görev', 
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600])
                                    ),
                                  ],
                                ),
                              ),
                              // --- YENİ EKLEME SONU ---

                              const SizedBox(height: 4),
                              
                              // Pazarlık durumu (Mevcuttu)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: durumRengi.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$durumYazisi · ${sonTeklifFiyati} TL',
                                  style: TextStyle(color: durumRengi, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Sohbete gitmek için yönlendirme oku
                        const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                      ],
                    ),
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