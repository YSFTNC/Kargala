// KOD BLOK BAŞLANGICI (gorevlerim_ekrani.dart - SADECE AKTİF GÖREVLER)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sohbet_ekrani.dart'; 
import '../widgets/puanlama_dialog.dart'; 

class GorevlerimEkrani extends StatefulWidget {
  const GorevlerimEkrani({super.key});

  @override
  State<GorevlerimEkrani> createState() => _GorevlerimEkraniState();
}

class _GorevlerimEkraniState extends State<GorevlerimEkrani> {
  User? user;
  Stream<QuerySnapshot>? _gorevlerStream; 

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _gorevlerStream = FirebaseFirestore.instance
          .collection('aktifIlanlar')
          .where('tasiyiciId', isEqualTo: user!.uid)
 
          .where('durum', isEqualTo: 'Anlaşıldı') 
       
          .orderBy('yayinlanmaTarihi', descending: true)
          .snapshots();
    }
  }
  Future<void> _gondericiyiPuanla(
    BuildContext context, 
    String ilanId, 
    String gondericiId,
    String gondericiAdi,
  ) async {
    // ... (Bu fonksiyonun içi aynı kalıyor)
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || !context.mounted) return;
    try {
      final puanlamaSonucu = await puanlamaDialogGoster(context, "Göndericiyi Puanla: $gondericiAdi");
      if (puanlamaSonucu != null && context.mounted) {
        final verilenPuan = puanlamaSonucu['puan'] as int;
        final yapilanYorum = puanlamaSonucu['yorum'] as String;

        await FirebaseFirestore.instance
            .collection('kullanicilar')
            .doc(gondericiId)
            .collection('aldigi_degerlendirmeler')
            .add({
              'puan': verilenPuan,
              'yorum': yapilanYorum.isNotEmpty ? yapilanYorum : null,
              'degerlendirenId': currentUser.uid,
              'ilanId': ilanId,
              'zaman': FieldValue.serverTimestamp(),
            });

        await FirebaseFirestore.instance.collection('aktifIlanlar').doc(ilanId).update({
          'tasiyiciPuani': verilenPuan,
          'tasiyiciYorumu': yapilanYorum.isNotEmpty ? yapilanYorum : null,
        });

        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Puanınız kaydedildi!')));
      } else {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Puanlama iptal edildi.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Puan hatası: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text("Hata: Kullanıcı bulunamadı.")));

    return Scaffold(
      appBar: AppBar(
        // --- GÜNCELLEME: Başlık değişti ---
        title: const Text('Aktif Görevlerim'),
        // --- GÜNCELLEME SONU ---
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _gorevlerStream, // Hafızadaki stream'i kullan
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}"));
          // Sorgu artık sadece 'Anlaşıldı' olanları getirdiği için,
          // 'Tamamlandı' kartlarını gösterme mantığına artık gerek yok,
          // ancak kart tasarımı (içindeki switch-case) zaten
          // 'Anlaşıldı' durumunu doğru gösterdiği için kalan kodlar çalışmaya devam edebilir.
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Henüz kabul ettiğiniz aktif bir görev yok.'));
          }

          final gorevler = snapshot.data!.docs;

          // --- LİSTE GÜNCELLENDİ (YENİ KART TASARIMI) ---
          return ListView.builder(
            padding: const EdgeInsets.all(8), // Kenarlara boşluk
            itemCount: gorevler.length,
            itemBuilder: (context, index) {
              final gorev = gorevler[index].data() as Map<String, dynamic>;
              final gorevId = gorevler[index].id;
              final gondericiId = gorev['kullaniciId'] as String? ?? '';
              final alinacakAdres = gorev['alinacakAdres'] as String? ?? '...';
              final teslimAdres = gorev['teslimAdres'] as String? ?? '...';
              final teklif = (gorev['teklif'] as num? ?? 0).toStringAsFixed(0);

              // Sorgu artık sadece "Anlaşıldı" getirdiği için ikon ve renk sabit
              final IconData durumIkonu = Icons.delivery_dining;
              final Color durumRengi = Colors.blue;
              
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    // Tıklayınca sohbete git
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Satır: Gönderici Bilgisi (FutureBuilder ile)
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('kullanicilar').doc(gondericiId).get(),
                          builder: (context, userSnapshot) {
                            String gondericiAdi = 'Gönderici...';
                            String? gondericiFotoUrl;
                            if (userSnapshot.connectionState == ConnectionState.done && userSnapshot.hasData && userSnapshot.data!.exists) {
                              final gondericiVerisi = userSnapshot.data!.data() as Map<String, dynamic>;
                              gondericiAdi = '${gondericiVerisi['ad']} ${gondericiVerisi['soyad']}';
                              gondericiFotoUrl = gondericiVerisi['profilFotoUrl'] as String?;
                            }

                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SohbetEkrani(
                                      ilanId: gorevId,
                                      gondericiId: gondericiId,
                                      tasiyiciId: user!.uid,
                                      konusulanKisiAdi: gondericiAdi,
                                    ),
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: (gondericiFotoUrl != null) ? NetworkImage(gondericiFotoUrl) : null,
                                    child: (gondericiFotoUrl == null) ? const Icon(Icons.person, size: 20, color: Colors.grey) : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(gondericiAdi, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                            );
                          },
                        ),
                        
                        const Divider(height: 20),

                        // 2. Satır: Rota
                        Text('$alinacakAdres ➔ $teslimAdres', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 12),

                        // 3. Satır: Durum ve Fiyat
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: durumRengi.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(durumIkonu, color: durumRengi, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ANLAŞILDI', // Artık hep bu
                                    style: TextStyle(fontWeight: FontWeight.bold, color: durumRengi, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            
                            // "Puanla" butonu artık görünmeyecek, çünkü sorgu sadece "Anlaşıldı" olanları getiriyor.
                            
                            Text(
                              '$teklif TL',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF32D74B)),
                            ),
                          ],
                        ),
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



