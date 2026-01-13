// KOD BLOK BAŞLANGICI
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sohbet_ekrani.dart'; 

class TumSohbetlerEkrani extends StatelessWidget {
  const TumSohbetlerEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(appBar: AppBar(title: Text('Sohbetler')), body: Center(child: Text("Giriş yapmalısınız.")));
    }

    return Scaffold(
      appBar: AppBar(
        // Tema'dan alacak
        title: const Text('Tüm Sohbetler'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 'sohbetler' koleksiyonunu dinle
        stream: FirebaseFirestore.instance
            .collection('sohbetler')
            .where('katilimcilar', arrayContains: currentUser.uid)
            .orderBy('sonMesajZamani', descending: true) // En yeni sohbetler en üstte
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Hata: ${snapshot.error}'));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Henüz aktif bir sohbetiniz yok.'));

          final sohbetler = snapshot.data!.docs;

          // --- YENİ PREMIUM LİSTE ---
          return ListView.builder(
            itemCount: sohbetler.length,
            itemBuilder: (context, index) {
              final sohbet = sohbetler[index].data() as Map<String, dynamic>;
              
              // --- ZENGİN VERİYİ ÇEK ---
              final ilanRotasi = sohbet['ilanRotasi'] as String? ?? 'İlan Bilgisi Yok';
              final katilimcilar = sohbet['katilimcilar'] as List<dynamic>? ?? [];
              final katilimciBilgileri = sohbet['katilimciBilgileri'] as Map<String, dynamic>? ?? {};
              
              // Konuştuğum diğer kişinin ID'sini ve bilgilerini bul
              final digerKullaniciId = katilimcilar.firstWhere((id) => id != currentUser.uid, orElse: () => null);
              if (digerKullaniciId == null) return const SizedBox.shrink(); // Hatalı sohbeti atla
              
              final digerKullaniciVerisi = katilimciBilgileri[digerKullaniciId] as Map<String, dynamic>? ?? {};
              final konusulanKisiAdi = digerKullaniciVerisi['ad'] as String? ?? 'Bilinmeyen Kullanıcı';
              final konusulanKisiFotoUrl = digerKullaniciVerisi['fotoUrl'] as String?;

              // Son mesajı ve okunma durumunu al
              final sonMesaj = sohbet['sonMesajMetni'] as String? ?? '...';
              final okunduMu = sohbet['okundu_${currentUser.uid}'] as bool? ?? true;
              
              // Sohbet ekranına yollanacak ID'leri de alalım
              final ilanId = sohbet['ilanId'] as String? ?? '';
              
              // --- HATA DÜZELTMESİ BURADA ---
              // Değişken adları 'final...' DEĞİL, sadece 'gondericiId' ve 'tasiyiciId'
              final gondericiId = sohbet['gondericiId'] as String?;
              final tasiyiciId = sohbet['tasiyiciId'] as String?;

              // Güvenlik kontrolü (DOĞRU DEĞİŞKEN ADLARIYLA)
              if (gondericiId == null || tasiyiciId == null || gondericiId.isEmpty || tasiyiciId.isEmpty) {
                 return ListTile(title: Text("Hata: Sohbet verisi eksik (ID'ler bulunamadı)."), subtitle: Text(ilanRotasi));
              }
              // --- HATA DÜZELTMESİ SONU ---

              return Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundImage: (konusulanKisiFotoUrl != null && konusulanKisiFotoUrl.isNotEmpty) 
                                     ? NetworkImage(konusulanKisiFotoUrl) 
                                     : null,
                    child: (konusulanKisiFotoUrl == null || konusulanKisiFotoUrl.isEmpty) 
                           ? const Icon(Icons.person, size: 28) 
                           : null,
                  ),
                  title: Text(
                    konusulanKisiAdi, 
                    style: TextStyle(fontWeight: !okunduMu ? FontWeight.bold : FontWeight.normal, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ilanRotasi, // İLAN BİLGİSİ EKLENDİ
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sonMesaj, // SON MESAJ EKLENDİ
                        style: TextStyle(
                          fontWeight: !okunduMu ? FontWeight.bold : FontWeight.normal, 
                          color: !okunduMu ? Colors.black : Colors.grey[600]
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  trailing: !okunduMu ? // Okunmadıysa
                    Container( // Kırmızı nokta
                       width: 12, height: 12,
                       decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ) : null,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SohbetEkrani(
                          ilanId: ilanId, // 'ilanId'yi de kullanalım
                          gondericiId: gondericiId, // <<< DÜZELTİLDİ
                          tasiyiciId: tasiyiciId,   // <<< DÜZELTİLDİ
                          konusulanKisiAdi: konusulanKisiAdi,
                        ),
                      ),
                    );
                  },
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