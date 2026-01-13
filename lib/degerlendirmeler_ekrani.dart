// KOD BLOK BAŞLANGICI
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Bu ekran, bir kullanıcının aldığı tüm değerlendirmeleri listeler.
class DegerlendirmelerEkrani extends StatelessWidget {
  // Hangi kullanıcının değerlendirmelerini göstereceğimizi bilmemiz gerek.
  final String kullaniciId;
  final double ortalamaPuan;
  final int degerlendirmeSayisi;

  const DegerlendirmelerEkrani({
    super.key,
    required this.kullaniciId,
    required this.ortalamaPuan,
    required this.degerlendirmeSayisi,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF212121),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Tüm Değerlendirmeler', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // İlgili kullanıcının 'aldigi_degerlendirmeler' alt koleksiyonunu dinle
        stream: FirebaseFirestore.instance
            .collection('kullanicilar')
            .doc(kullaniciId)
            .collection('aldigi_degerlendirmeler')
            .orderBy('zaman', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Henüz hiç değerlendirme yapılmamış.'));
          }

          final degerlendirmeler = snapshot.data!.docs;

          // Yorumları ve en üstteki Puan özetini göstermek için ListView
          return ListView.builder(
            itemCount: degerlendirmeler.length + 1, // +1, en üstteki özet satırı için
            itemBuilder: (context, index) {
              // İlk öğe (index 0) ise, puan özetini göster
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 30),
                      const SizedBox(width: 8),
                      Text(
                        ortalamaPuan.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '($degerlendirmeSayisi değerlendirme)',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              // Diğer öğeler (yorum kartları)
              final yorumData = degerlendirmeler[index - 1].data() as Map<String, dynamic>;
              final yorumMetni = yorumData['yorum'] as String? ?? '';
              final verilenPuan = yorumData['puan'] as int? ?? 0;
              // TODO: Yorum yapanın adını çekmek için FutureBuilder eklenebilir.

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(child: Icon(Icons.person_outline)),
                  title: Row(
                    children: List.generate(5, (i) => Icon(
                      i < verilenPuan ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 16,
                    )),
                  ),
                  subtitle: yorumMetni.isNotEmpty
                      ? Text('"$yorumMetni"', style: const TextStyle(fontStyle: FontStyle.italic))
                      : const Text('Yorum yapılmamış', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
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