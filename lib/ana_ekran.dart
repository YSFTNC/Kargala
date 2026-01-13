// KOD BLOK BAŞLANGICI (ana_ekran.dart - FCM TOKEN GÜNCELLEMESİ)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // <<< 1. YENİ İMPORT
import 'package:kargala/gorevlerim_ekrani.dart';
import 'package:kargala/yayinladigim_ilanlar_ekrani.dart';
import 'profil_ekrani.dart';
import 'ilan_listesi_ekrani.dart';
import 'ilan_olusturma_ekrani.dart';
import 'tum_sohbetler_ekrani.dart';
import 'ilan_harita_ekrani.dart'; // <<< YENİ İMPORT
class AnaEkran extends StatefulWidget {
  final User currentUser;
  
  AnaEkran({super.key, required this.currentUser});

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  String _kullaniciAdi = "...";
  bool _isLoading = true;

  Stream<QuerySnapshot>? _okunmamisMesajStream;
  Stream<QuerySnapshot>? _aktifGorevlerStream;
  Stream<QuerySnapshot>? _aktifIlanlarStream;

  @override
  void initState() {
    super.initState();
    _kullaniciAdiniGetir();
    _streamleriBaslat();
    
    // --- YENİ EKLENDİ: FCM TOKEN YÖNETİMİ ---
    _fcmTokenYonetimi();
    // --- YENİ EKLEME SONU ---
  }

  // --- YENİ EKLENEN FONKSİYON BAŞLANGICI ---
  Future<void> _fcmTokenYonetimi() async {
    // Bu fonksiyon, Cloud Function'ın size bildirim gönderebilmesi için
    // cihazınızın en güncel token'ını Firestore'a kaydeder.
    
    final fcm = FirebaseMessaging.instance;
    
    try {
      // 1. CİHAZIN TOKEN'INI AL
      final fcmToken = await fcm.getToken();
      
      if (fcmToken == null) {
        print("XXX FCM Token alınamadı.");
        return;
      }

      print(">>> Mevcut FCM Token: $fcmToken");

      // 2. TOKEN'I FIRESTORE'A KAYDET
      // (widget.currentUser.uid sayesinde bu ekranda kullanıcı ID'sine sahibiz)
      // Cloud Function'ınızın bu alandan okuduğundan emin olun ('fcmToken')
      await FirebaseFirestore.instance
          .collection('kullanicilar')
          .doc(widget.currentUser.uid)
          .update({
            'fcmToken': fcmToken,
            'fcmTokenSonGuncelleme': FieldValue.serverTimestamp(),
          });
      
      print(">>> FCM Token başarıyla Firestore'a kaydedildi.");

    } catch (e) {
      print("XXX FCM Token kaydetme hatası: $e");
    }

    // 3. TOKEN YENİLENMESİNİ DİNLE (APP ÇALIŞIRKEN)
    // Cihaz, token'ı (örn. app güncellemesi) yenilerse, anında Firestore'u da güncelle.
    fcm.onTokenRefresh.listen((yeniToken) {
      print(">>> YENİ TOKEN (onTokenRefresh): $yeniToken");
      FirebaseFirestore.instance
          .collection('kullanicilar')
          .doc(widget.currentUser.uid)
          .update({'fcmToken': yeniToken});
    });
  }
  // --- YENİ EKLENEN FONKSİYON SONU ---


  Future<void> _kullaniciAdiniGetir() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('kullanicilar')
          .doc(widget.currentUser.uid)
          .get();
      if (mounted && userDoc.exists) {
        setState(() {
          _kullaniciAdi = userDoc.data()?['ad'] ?? widget.currentUser.email?.split('@').first ?? 'Kullanıcı';
          _isLoading = false;
        });
      } else {
         if (mounted) setState(() {
            _kullaniciAdi = widget.currentUser.email?.split('@').first ?? 'Kullanıcı';
            _isLoading = false;
         });
      }
    } catch (e) {
       if(mounted) setState(() => _isLoading = false);
       print("Kullanıcı adı hatası: $e");
    }
  }

  void _streamleriBaslat() {
     _okunmamisMesajStream = FirebaseFirestore.instance
          .collection('sohbetler')
          .where('katilimcilar', arrayContains: widget.currentUser.uid)
          .where('okundu_${widget.currentUser.uid}', isEqualTo: false)
          .snapshots();
     _aktifGorevlerStream = FirebaseFirestore.instance 
          .collection('aktifIlanlar')
          .where('tasiyiciId', isEqualTo: widget.currentUser.uid)
          .where('durum', isEqualTo: 'Anlaşıldı')
          .snapshots();
     _aktifIlanlarStream = FirebaseFirestore.instance 
          .collection('aktifIlanlar')
          .where('kullaniciId', isEqualTo: widget.currentUser.uid)
          .where('durum', isEqualTo: 'Aktif')
          .snapshots();
  }

  Widget _buildDashboardCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap, {Stream<QuerySnapshot>? countStream}) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, size: 30, color: color),
                    if (countStream != null)
                      StreamBuilder<QuerySnapshot>(
                        stream: countStream,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Text("0", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold));
                          return Text(
                            snapshot.data!.docs.length.toString(),
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
                          );
                        }
                      )
                    else 
                      const SizedBox(height: 34),
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                  ],
                ),
              ),
              if (countStream != null)
                StreamBuilder<QuerySnapshot>(
                  stream: countStream,
                  builder: (context, snapshot) {
                    bool okunmamisVar = (snapshot.hasData && snapshot.data!.docs.isNotEmpty);
                    if (okunmamisVar) {
                      return Positioned(
                        right: 12, top: 12,
                        child: Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration( color: Colors.red, shape: BoxShape.circle ),
                          constraints: BoxConstraints( minWidth: 10, minHeight: 10 ),
                        ),
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  }
                ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // --- İSTEĞİNİZ ÜZERİNE DÜZELTİLDİ ---
        title: Row(
          mainAxisSize: MainAxisSize.min, // İçeriği kadar yer kaplasın
          children: [
            // --- İKON YERİNE LOGONUZU KULLANIYORUZ ---
            Image.asset(
              'assets/logo.png', // <<< SİZİN LOGO DOSYANIZIN YOLU
                                 // (Eğer adı farklıysa veya 'assets/images/logo.png' ise düzeltin)
              height: 30, // Yüksekliği 30 piksel yaptık, şık durur
              // Hata durumunda ne yapacağını da ekleyelim (Güvenlik için)
              errorBuilder: (context, error, stackTrace) {
                print("XXX AppBar Logo Hatası: $error");
                return const Icon(Icons.error_outline, color: Colors.red, size: 24); // Logo bulunamazsa hata ikonu
              },
            ),
            // --- DEĞİŞİKLİK SONU ---
            
            const SizedBox(width: 8), // Logo ile yazı arasına boşluk
            const Text('KARGALA'), // Temadan alacağı için style'a gerek yok
          ],
        ),
        automaticallyImplyLeading: false, // Geri tuşunu kaldır
        // --- DÜZELTME SONU ---
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Karşılama Mesajı
                Text( 'Tekrar hoş geldin,', style: TextStyle(fontSize: 22, color: Colors.grey[700])),
                Text( _kullaniciAdi, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 24),

                // 2. Kontrol Paneli Kartları (Üst Sıra)
                Row(
                  children: [
                    _buildDashboardCard(
                      context, 
                      "Okunmamış Mesajlar", 
                      Icons.message_rounded, 
                      Colors.blue,
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TumSohbetlerEkrani())),
                      countStream: _okunmamisMesajStream,
                    ),
                    const SizedBox(width: 16),
                    _buildDashboardCard(
                      context, 
                      "Aktif Görevlerim", 
                      Icons.delivery_dining_rounded, 
                      Colors.orange,
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GorevlerimEkrani())),
                      countStream: _aktifGorevlerStream,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // 3. Kontrol Paneli Kartları (Alt Sıra)
                Row(
                  children: [
                    _buildDashboardCard(
                      context, 
                      "Aktif İlanlarım", 
                      Icons.outbox_rounded, 
                      Colors.green,
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const YayinladigimIlanlarEkrani())),
                      countStream: _aktifIlanlarStream,
                    ),
                    const SizedBox(width: 16),
                    _buildDashboardCard(
                      context,
                      "Profilim", 
                      Icons.person_rounded, 
                      Colors.teal,
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilEkrani())),
                    ),
                  ],
                ),
                
                const Spacer(),

                // 4. Ana Eylem Butonları
                ElevatedButton(
                   onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const IlanOlusturmaEkrani())),
                   child: const Text('KARGO GÖNDER'),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
   onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const IlanHaritaEkrani())), // <<< GÜNCELLENDİ
   child: const Text('KARGO TAŞI'),
),
              ],
            ),
          ),
    );
  }
}
// KOD BLOK SONU