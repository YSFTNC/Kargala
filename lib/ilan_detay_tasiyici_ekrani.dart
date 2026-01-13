// KOD BLOK BAŞLANGICI (ilan_detay_tasiyici_ekrani.dart - ROTA GÜNCELLEMESİ)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class IlanDetayTasiyiciEkrani extends StatefulWidget {
  // ... (Tüm dosyanın üst kısmı ve _IlanDetayTasiyiciEkraniState sınıfı aynı)
  final Map<String, dynamic> ilanVerisi;
  final String ilanId;

  const IlanDetayTasiyiciEkrani({
    super.key,
    required this.ilanVerisi,
    required this.ilanId,
  });

  @override
  State<IlanDetayTasiyiciEkrani> createState() => _IlanDetayTasiyiciEkraniState();
}

class _IlanDetayTasiyiciEkraniState extends State<IlanDetayTasiyiciEkrani> {
  // ... (Tüm fonksiyonlarınız _teklifVerPopupGoster, dispose vb. aynı)
  final _teklifFiyatController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = false; 
  
  @override
  void dispose() {
    _teklifFiyatController.dispose();
    super.dispose();
  }
  
  Future<void> _teklifVerPopupGoster() async {
    // ... (Bu fonksiyonun içi bir önceki adımdaki gibi aynı)
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teklif vermek için giriş yapmalısınız.')));
      return;
    }
    _teklifFiyatController.clear(); 

    final teklifFiyati = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Teklif Ver'),
          content: TextField(
            controller: _teklifFiyatController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'Teklif ettiğiniz tutar',
              prefixText: 'TL ',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
              onPressed: () => Navigator.of(dialogContext).pop(null),
            ),
            TextButton(
              child: const Text('Teklifi Gönder'),
              onPressed: () {
                if (_teklifFiyatController.text.trim().isEmpty) {
                   ScaffoldMessenger.of(dialogContext).showSnackBar(
                     const SnackBar(content: Text('Lütfen bir fiyat girin.'), backgroundColor: Colors.red),
                   );
                } else {
                   Navigator.of(dialogContext).pop(_teklifFiyatController.text.trim());
                }
              },
            ),
          ],
        );
      },
    );

    if (teklifFiyati != null && mounted) {
      setState(() => _isLoading = true);
      try {
        final fiyatDouble = double.tryParse(teklifFiyati.replaceAll(',', '.'));
        if (fiyatDouble == null || fiyatDouble <= 0) {
          throw Exception("Geçersiz fiyat formatı. Lütfen sadece sayı girin.");
        }

        final userDoc = await FirebaseFirestore.instance.collection('kullanicilar').doc(_currentUser!.uid).get();
        final userData = userDoc.data() as Map<String, dynamic>? ?? {};
        final adSoyad = ("${userData['ad'] ?? ''} ${userData['soyad'] ?? ''}").trim();
        final profilFotoUrl = userData['profilFotoUrl'] as String?;
        final gorevSayisi = userData['tamamlananGorevSayisi'] as int? ?? 0;
        final puanSnapshot = await FirebaseFirestore.instance.collection('kullanicilar').doc(_currentUser!.uid).collection('aldigi_degerlendirmeler').get();
        final degerlendirmeSayisi = puanSnapshot.docs.length;
        double ortalamaPuan = 0.0;
        if (degerlendirmeSayisi > 0) {
           double toplamPuan = 0;
           for (var doc in puanSnapshot.docs) {
                toplamPuan += (doc.data()['puan'] as num? ?? 0);
           }
            ortalamaPuan = toplamPuan / degerlendirmeSayisi;
        }

        await FirebaseFirestore.instance
            .collection('aktifIlanlar')
            .doc(widget.ilanId)
            .collection('gelenTeklifler')
            .doc(_currentUser!.uid) 
            .set({
              'tasiyiciId': _currentUser!.uid,
              'teklifFiyati': fiyatDouble,
              'zaman': FieldValue.serverTimestamp(),
              'pazarlikDurumu': 'beklemede',
              'sonTeklifiYapan': 'tasiyici',
              'tasiyiciAdi': adSoyad.isNotEmpty ? adSoyad : (userData['email'] ?? 'Kullanıcı'),
              'tasiyiciFotoUrl': profilFotoUrl,
              'tasiyiciOrtalamaPuan': ortalamaPuan,
              'tasiyiciDegerlendirmeSayisi': degerlendirmeSayisi,
              'tasiyiciGorevSayisi': gorevSayisi,
            });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Teklifiniz başarıyla gönderildi!'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } catch (e) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: ${e.toString()}'), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // ... (verileri okuma kısmı aynı)
    final alinacakAdres = widget.ilanVerisi['alinacakAdres'] as String? ?? '...';
    final teslimAdres = widget.ilanVerisi['teslimAdres'] as String? ?? '...';
    final teklif = (widget.ilanVerisi['teklif'] as num? ?? 0).toStringAsFixed(0);
    final paketBoyutu = widget.ilanVerisi['paketBoyutu'] as String? ?? '-';
    final gondericiId = widget.ilanVerisi['kullaniciId'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('İlan Detayları'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Gönderici Bilgi Kartı (Aynı) ---
            if (gondericiId != null)
              FutureBuilder<DocumentSnapshot>(
                // ... (içerik aynı)
                future: FirebaseFirestore.instance.collection('kullanicilar').doc(gondericiId).get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const ListTile(leading: CircularProgressIndicator(), title: Text('Gönderici yükleniyor...'));
                  
                  final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                  final gondericiAdi = ("${data['ad'] ?? ''} ${data['soyad'] ?? ''}").trim();
                  final fotoUrl = data['profilFotoUrl'];
                  
                  return Row(children: [
                     CircleAvatar(
                       radius: 20, 
                       backgroundImage: (fotoUrl != null) ? NetworkImage(fotoUrl) : null, 
                       child: (fotoUrl == null) ? const Icon(Icons.person, size: 20) : null
                     ),
                     const SizedBox(width: 8),
                     Text(
                       gondericiAdi.isNotEmpty ? gondericiAdi : (data['email'] ?? 'Gönderici'), 
                       style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                     ),
                  ]);
                }
              )
            else
              const Text("Gönderici bilgisi bulunamadı."),
            
            const Divider(height: 30),

            // --- GÜNCELLENDİ: ROTA BÖLÜMÜ ---
            Text('Rota:', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
            const SizedBox(height: 8),
            // Alınacak Adres
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.trip_origin, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alinacakAdres, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 4, bottom: 4),
              child: Icon(Icons.more_vert, size: 16, color: Colors.grey[400]),
            ),
            // Teslim Adresi
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    teslimAdres, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            // --- GÜNCELLEME SONU ---

            const SizedBox(height: 20),
            
            // --- Paket Boyutu ve Fiyat (Aynı) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    paketBoyutu.toUpperCase(), 
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 12)
                  ),
                ),
                Text(
                  '$teklif TL (Önerilen Fiyat)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF32D74B))
                ),
            ]),
            
            const Spacer(), 

            // --- Buton (Aynı) ---
            if (_currentUser != null && _currentUser!.uid == gondericiId)
              Center(child: Text("Bu kendi ilanınız, teklif veremezsiniz.", style: TextStyle(color: Colors.grey[600])))
            else
              ElevatedButton.icon(
                icon: _isLoading 
                      ? Container(width: 24, height: 24, padding: const EdgeInsets.all(2), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                      : const Icon(Icons.local_offer, color: Colors.white),
                label: Text(_isLoading ? 'GÖNDERİLİYOR...' : 'BU İŞE TEKLİF VER'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isLoading ? Colors.grey : Theme.of(context).primaryColor, 
                ),
                onPressed: _isLoading ? null : _teklifVerPopupGoster,
              ),
          ],
        ),
      ),
    );
  }
}
// KOD BLOK SONU