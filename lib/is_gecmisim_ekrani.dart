// KOD BLOK BAŞLANGICI (is_gecmisim_ekrani.dart - YENİ DOSYA)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sohbet_ekrani.dart'; 
import '../widgets/puanlama_dialog.dart'; 

class IsGecmisimEkrani extends StatefulWidget {
  const IsGecmisimEkrani({super.key});

  @override
  State<IsGecmisimEkrani> createState() => _IsGecmisimEkraniState();
}

class _IsGecmisimEkraniState extends State<IsGecmisimEkrani> {
  User? user;
  // --- GÜNCELLEME: Stream yerine Future kullanacağız ---
  // İş geçmişi anlık değişen bir veri olmadığı için,
  // ekran açıldığında bir kere yüklemek daha performanslıdır.
  Future<QuerySnapshot>? _isGecmisiFuture; 
  double _toplamKazanc = 0.0;
  // --- GÜNCELLEME SONU ---

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // --- GÜNCELLEME: Sorgu 'Future' oldu ve 'Tamamlandı' olanları çekiyor ---
      _isGecmisiFuture = FirebaseFirestore.instance
          .collection('aktifIlanlar')
          .where('tasiyiciId', isEqualTo: user!.uid)
          .where('durum', isEqualTo: 'Tamamlandı') // Sadece bitenler
          .orderBy('yayinlanmaTarihi', descending: true)
          .get(); // .get() = Bir kere al / .snapshots() = Dinle
      // --- GÜNCELLEME SONU ---
    }
  }

  // Puanlama fonksiyonu (gorevlerim_ekrani.dart'tan kopyalandı)
  Future<void> _gondericiyiPuanla(
    BuildContext context, 
    String ilanId, 
    String gondericiId,
    String gondericiAdi,
  ) async {
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
        
        // --- YENİ EKLENDİ: Puanlama yapınca ekranı yenile ---
        // (Böylece "PUANLA" butonu kaybolur)
        setState(() {
          _isGecmisiFuture = FirebaseFirestore.instance
              .collection('aktifIlanlar')
              .where('tasiyiciId', isEqualTo: user!.uid)
              .where('durum', isEqualTo: 'Tamamlandı')
              .orderBy('yayinlanmaTarihi', descending: true)
              .get();
        });
        // --- YENİ EKLEME SONU ---
        
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
        title: const Text('İş Geçmişim'),
      ),
      // --- GÜNCELLEME: StreamBuilder -> FutureBuilder ---
      body: FutureBuilder<QuerySnapshot>(
        future: _isGecmisiFuture, 
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}"));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Henüz tamamladığınız bir görev yok.'));

          final gorevler = snapshot.data!.docs;

          // --- YENİ EKLENDİ: Toplam Kazancı Hesapla ---
          _toplamKazanc = 0.0;
          for (var gorev in gorevler) {
             final data = gorev.data() as Map<String, dynamic>? ?? {};
             _toplamKazanc += (data['teklif'] as num? ?? 0.0);
          }
          // --- YENİ EKLEME SONU ---

          // --- ListView.builder'ı Column içine alıp başlık ekliyoruz ---
          return Column(
            children: [
              // --- YENİ EKLENEN KAZANÇ KARTI ---
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: Color(0xFF32D74B).withOpacity(0.1),
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, color: Colors.green[800], size: 28),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Toplam Kazanç", style: TextStyle(color: Colors.green[800], fontSize: 14)),
                            Text(
                              '${_toplamKazanc.toStringAsFixed(2)} TL', 
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.green[900])
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: gorevler.length,
                  itemBuilder: (context, index) {
                    final gorev = gorevler[index].data() as Map<String, dynamic>;
                    final gorevId = gorevler[index].id;
                    final gondericiId = gorev['kullaniciId'] as String? ?? '';
                    
                    // --- PUANLAMA İÇİN YENİ VERİLER ---
                    final ilanDurumu = gorev['durum'] as String? ?? ''; // "Tamamlandı"
                    final tasiyiciPuanlamisMi = (gorev['tasiyiciPuani'] as num? ?? 0) > 0; //
                    // --- BİTİŞ ---

                    final alinacakAdres = gorev['alinacakAdres'] as String? ?? '...'; //
                    final teslimAdres = gorev['teslimAdres'] as String? ?? '...'; //
                    final teklif = (gorev['teklif'] as num? ?? 0).toStringAsFixed(0); //

                    final IconData durumIkonu = Icons.check_circle; //
                    final Color durumRengi = const Color.fromARGB(255, 141, 138, 153); //
                    
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

                              // 3. Satır: Durum ve Fiyat/Puanla Butonu
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
                                          ilanDurumu.toUpperCase(),
                                          style: TextStyle(fontWeight: FontWeight.bold, color: durumRengi, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // --- YENİ PUANLAMA BUTONU LOGIĞI ---
                                  // (gorevlerim_ekrani.dart'tan kopyalandı)
                                  if (ilanDurumu == 'Tamamlandı' && !tasiyiciPuanlamisMi)
                                    TextButton( 
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.amber[100],
                                        foregroundColor: Colors.black87,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                      onPressed: () {
                                         // Göndericinin adını alıp puanlama fonksiyonuna yolla
                                         FirebaseFirestore.instance.collection('kullanicilar').doc(gondericiId).get().then((doc) {
                                            String ad = "Gönderici";
                                            if(doc.exists) ad = (doc.data()?['ad'] ?? '') + ' ' + (doc.data()?['soyad'] ?? '');
                                            _gondericiyiPuanla(context, gorevId, gondericiId, ad);
                                         });
                                      },
                                      child: const Text('GÖNDERİCİYİ PUANLA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    )
                                  else
                                    // Puanlamışsa veya durum farklıysa (ki değil) Fiyatı Göster
                                    Text(
                                      '$teklif TL',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF32D74B)),
                                    ),
                                  // --- PUANLAMA LOGIĞI SONU ---
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
// KOD BLOK SONU