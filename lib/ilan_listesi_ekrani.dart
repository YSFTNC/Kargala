// KOD BLOK BAŞLANGICI
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/ilan_karti.dart'; // <<< Akıllı kartımızı import ediyoruz
import 'ilan_detay_tasiyici_ekrani.dart'; // Tıklayınca detaylara gitmek için

class IlanListesiEkrani extends StatelessWidget {
  const IlanListesiEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Tema'dan alacak
        title: const Text('Yakındaki Aktif İlanlar'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Sadece durumu "Aktif" olan ilanları dinle
        stream: FirebaseFirestore.instance
            .collection('aktifIlanlar')
            .where('durum', isEqualTo: 'Aktif')
            .orderBy('yayinlanmaTarihi', descending: true) // En yeniler üste
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Şu anda aktif ilan bulunmamaktadır.'));
          }

          final ilanlar = snapshot.data!.docs;

          // --- LİSTE GÜNCELLENDİ ---
          return ListView.builder(
            padding: const EdgeInsets.all(8), // Kenarlara boşluk
            itemCount: ilanlar.length,
            itemBuilder: (context, index) {
              final ilanVerisi = ilanlar[index].data() as Map<String, dynamic>;
              final ilanId = ilanlar[index].id;
              
              // Kartı tıklanabilir yap
              return IlanKarti(
  ilanVerisi: ilanVerisi,
  ilanId: ilanId, // <<< EKSİK OLAN PARAMETREYİ BURAYA EKLEYİN
);
            },
          );
          // --- LİSTE GÜNCELLENDİ SON ---
        },
      ),
    );
  }
}
// KOD BLOK SONU