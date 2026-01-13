// KOD BLOK BAŞLANGICI
import 'dart:async'; // StreamSubscription için
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart'; // Konum kütüphanesi
import '../widgets/puanlama_dialog.dart';
import 'giris_ekrani.dart';
import 'map_takip_ekrani.dart'; // Harita ekranını import et
import 'odeme_ekrani.dart';
import 'odeme_ozet_ekrani.dart';

class SohbetEkrani extends StatefulWidget {
  final String ilanId;
  final String gondericiId;
  final String tasiyiciId;
  final String konusulanKisiAdi;

  const SohbetEkrani({
    super.key,
    required this.ilanId,
    required this.gondericiId,
    required this.tasiyiciId,
    required this.konusulanKisiAdi,
  });

  @override
  State<SohbetEkrani> createState() => _SohbetEkraniState();
}

class _SohbetEkraniState extends State<SohbetEkrani> {
  final _mesajController = TextEditingController();
  final _kodController = TextEditingController();
  final _teklifFiyatController = TextEditingController();
  User? _currentUser;

  String? _sohbetOdasiId;
  DocumentReference? _sohbetOdasiRef;
  DocumentReference? _ilanRef;
  DocumentReference? _teklifRef; 

  bool _isInitialized = false;
  final Location _locationService = Location();
  
  // Konum dinleyicisini hafızada tutmak için
  StreamSubscription<LocationData>? _locationSubscription; 
  bool _konumPaylasimiAktif = false; 

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser == null || widget.ilanId.isEmpty || widget.gondericiId.isEmpty || widget.tasiyiciId.isEmpty) {
      if (mounted) setState(() => _isInitialized = false); return;
    }
    List<String> ids = [widget.gondericiId, widget.tasiyiciId];
    ids.sort();
    _sohbetOdasiId = '${widget.ilanId}_${ids[0]}_${ids[1]}';
    _sohbetOdasiRef = FirebaseFirestore.instance.collection('sohbetler').doc(_sohbetOdasiId);
    _ilanRef = FirebaseFirestore.instance.collection('aktifIlanlar').doc(widget.ilanId);
    _teklifRef = _ilanRef!.collection('gelenTeklifler').doc(widget.tasiyiciId);
    if (mounted) setState(() => _isInitialized = true);
    _okunduIsaretle();
  }

  @override
  void dispose() {
    // --- GÜNCELLENDİ: Ekran kapanırsa konum dinlemeyi de durdur ---
    _locationSubscription?.cancel(); // Dinleyiciyi iptal et
    // --- GÜNCELLEME SONU ---
    _mesajController.dispose();
    _kodController.dispose();
    _teklifFiyatController.dispose();
    super.dispose();
  }

  Future<void> _okunduIsaretle() async {
    if (_currentUser == null || !mounted || _sohbetOdasiRef == null) return;
    try {
      await _sohbetOdasiRef!.set({'okundu_${_currentUser!.uid}': true}, SetOptions(merge: true));
    } catch (e) { print("XXX Okundu işaretleme hatası: $e"); }
  }

  void _mesajGonder() async {
    final girilenMesaj = _mesajController.text.trim();
    if (girilenMesaj.isEmpty || _currentUser == null || !mounted || _sohbetOdasiRef == null || _ilanRef == null) return;
    final gonderenId = _currentUser!.uid;
    _mesajController.clear();
    final katilimciListesi = [widget.gondericiId, widget.tasiyiciId];
    if (katilimciListesi.any((id) => id.isEmpty)) return;

    try {
      final mesajVerisi = {
        'mesajMetni': girilenMesaj,
        'gonderenId': gonderenId,
        'zaman': FieldValue.serverTimestamp(),
      };
      String ilanRotasi = "Bilinmeyen İlan";
      final ilanDoc = await _ilanRef!.get();
      if (ilanDoc.exists) {
         final ilanVerisi = ilanDoc.data() as Map<String, dynamic>?;
         ilanRotasi = (ilanVerisi != null) ? "${ilanVerisi['alinacakAdres']} -> ${ilanVerisi['teslimAdres']}" : "İlan Bilgisi Yok";
      }
      final gondericiDoc = await FirebaseFirestore.instance.collection('kullanicilar').doc(widget.gondericiId).get();
      final tasiyiciDoc = await FirebaseFirestore.instance.collection('kullanicilar').doc(widget.tasiyiciId).get();
      final gondericiData = gondericiDoc.data() as Map<String, dynamic>? ?? {};
      final tasiyiciData = tasiyiciDoc.data() as Map<String, dynamic>? ?? {};
      final Map<String, dynamic> katilimciBilgileri = {
         widget.gondericiId: {'ad': (gondericiData['ad'] ?? '') + ' ' + (gondericiData['soyad'] ?? ''), 'fotoUrl': gondericiData['profilFotoUrl']},
         widget.tasiyiciId: {'ad': (tasiyiciData['ad'] ?? '') + ' ' + (tasiyiciData['soyad'] ?? ''), 'fotoUrl': tasiyiciData['profilFotoUrl']},
      };
      final aliciId = katilimciListesi.firstWhere((id) => id != gonderenId);
      await _sohbetOdasiRef!.set({
        'ilanId': widget.ilanId, 'ilanRotasi': ilanRotasi, 'katilimcilar': katilimciListesi,
        'katilimciBilgileri': katilimciBilgileri, 'sonMesajZamani': FieldValue.serverTimestamp(),
        'sonMesajMetni': girilenMesaj, 'sonMesajGonderenId': gonderenId,
        'gondericiId': widget.gondericiId, 'tasiyiciId': widget.tasiyiciId,
        'okundu_$aliciId': false,
      }, SetOptions(merge: true));
      await _sohbetOdasiRef!.collection('mesajlar').add(mesajVerisi);
    } catch (e, s) {
       print("XXX Mesaj gönderme hatası: $e\n$s");
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mesaj gönderilemedi: ${e.toString()}')));
    }
  }

  // --- TAŞIYICI KOD DOĞRULAMA (GÜNCELLENDİ: Konumu Durdurur) ---
  Future<void> _teslimatKoduDogrulaPopup(String dogruKod) async {
    if (_ilanRef == null) return;
    _kodController.clear();
    final girilenKod = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Teslimat Doğrulama Kodu'),
          content: TextField(controller: _kodController, keyboardType: TextInputType.number,maxLength: 6, decoration: const InputDecoration(hintText: 'Alıcıdan kodu girin')),
          actions: <Widget>[
            TextButton(child: const Text('İptal'),onPressed: () => Navigator.of(dialogContext).pop(null)),
            TextButton(child: const Text('Doğrula'),onPressed: () => Navigator.of(dialogContext).pop(_kodController.text.trim())),
          ],
        );
      },
    );
    if (girilenKod != null && girilenKod.isNotEmpty) {
      if (girilenKod == dogruKod) {
        try { 
          // 1. İlanı güncelle
          await _ilanRef!.update({'tasiyiciTeslimEttiMi': true});
          
          // --- YENİ EKLENEN KISIM: KONUMU DURDUR ---
          // Kod doğrulandıysa, artık konum paylaşmaya gerek yok.
          if (_locationSubscription != null) {
            await _locationSubscription!.cancel(); // Dinleyiciyi iptal et
            _locationSubscription = null;
            if (mounted) setState(() => _konumPaylasimiAktif = false);
            print(">>> Kod doğrulandı, konum paylaşımı OTOMATİK DURDURULDU.");
          }
          // --- YENİ KISIM SONU ---

          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Kod doğrulandı!'))); 
        }
        catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: ${e.toString()}'))); }
      } else { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Hatalı kod!'))); }
    }
  }

  // --- GÖNDERİCİ GÖREV TAMAMLAMA (GÜNCELLENDİ: Konumu Durdurur) ---
  Future<void> _goreviTamamlaOnayla() async {
      if (_ilanRef == null) return;
      final bool? onay = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Görevi Tamamla'),
            content: const Text('Kargoyu teslim aldığınızı onaylıyor musunuz?'),
            actions: <Widget>[
              TextButton(child: const Text('Hayır'), onPressed: () => Navigator.of(dialogContext).pop(false)),
              TextButton(child: const Text('Evet, Tamamla'), onPressed: () => Navigator.of(dialogContext).pop(true)),
            ],
          );
        },
      );
      if (onay == true && mounted) {
        try {
          await _ilanRef!.update({'durum': 'Tamamlandı','gorevTamamlandiMi': true});
          
          // --- YENİ EKLENEN KISIM: KONUMU DURDUR (GARANTİ) ---
          // Görev tamamlanınca konum paylaşımını da durdur
          if (_locationSubscription != null) {
            await _locationSubscription!.cancel();
            _locationSubscription = null;
            if (mounted) setState(() => _konumPaylasimiAktif = false);
            print(">>> Görev tamamlandı, konum paylaşımı OTOMATİK DURDURULDU.");
          }
          // --- YENİ KISIM SONU ---
          
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Görev tamamlandı! Taşıyıcıyı puanlayın.')));
          final puanlananAdi = widget.konusulanKisiAdi;
          Map<String, dynamic>? puanlamaSonucu = null;
          if (mounted) { puanlamaSonucu = await puanlamaDialogGoster(context, puanlananAdi); }
          if (puanlamaSonucu != null && mounted) {
            final verilenPuan = puanlamaSonucu['puan'] as int;
            final yapilanYorum = puanlamaSonucu['yorum'] as String;
            try {
              await FirebaseFirestore.instance.collection('kullanicilar').doc(widget.tasiyiciId).collection('aldigi_degerlendirmeler').add({
                'puan': verilenPuan, 'yorum': yapilanYorum.isNotEmpty ? yapilanYorum : null,
                'degerlendirenId': _currentUser!.uid, 'ilanId': widget.ilanId,
                'zaman': FieldValue.serverTimestamp(),
              });
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Puanınız kaydedildi.')));
            } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Puan hatası: ${e.toString()}'))); }
          } else { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Puanlama iptal edildi.'))); }
        } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tamamlama hatası: ${e.toString()}'))); }
      }
  }

  // --- GÖREV İPTAL ETME (GÜNCELLENDİ: Konumu Durdurur) ---
  Future<void> _goreviIptalEtOnayla() async {
    if (_ilanRef == null || !mounted) return; 
    final bool? onay = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Görevi İptal Et'),
          content: const Text('Bu anlaşmayı iptal etmek istediğinize emin misiniz? İlan tekrar "Aktif" hale gelecek.'),
          actions: <Widget>[
            TextButton(child: const Text('Vazgeç'), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(child: const Text('Evet, İptal Et', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );
    if (onay == true && mounted) {
      try {
        await _ilanRef!.update({
          'durum': 'Aktif', 'tasiyiciId': FieldValue.delete(),
          'teslimatKodu': FieldValue.delete(), 'tasiyiciTeslimEttiMi': FieldValue.delete(),
        });
        
        // --- YENİ EKLENEN KISIM: KONUMU DURDUR ---
        // İptal edince de konumu durdur
        if (_locationSubscription != null) {
          await _locationSubscription!.cancel();
          _locationSubscription = null;
          if (mounted) setState(() => _konumPaylasimiAktif = false);
          print(">>> Görev iptal edildi, konum paylaşımı OTOMATİK DURDURULDU.");
        }
        // --- YENİ KISIM SONU ---
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Görev iptal edildi. İlan tekrar listeleniyor.')));
          Navigator.of(context).pop(); 
        }
      } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: ${e.toString()}'))); }
    }
  }

  // --- CANLI KONUM FONKSİYONU (NİHAİ SÜRÜM: "İLK KONUM" EKLENDİ) ---
  Future<void> _konumPaylasmayiBaslat() async {
    if (_ilanRef == null || !mounted) return;
    
    if (_konumPaylasimiAktif) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konum paylaşımı zaten aktif.'), backgroundColor: Colors.orange));
      return;
    }

    print(">>> Konum paylaşma süreci başlatılıyor...");

    // 1. GPS Kontrolü
    bool serviceEnabled = await _locationService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationService.requestService();
      if (!serviceEnabled) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen konum servislerini (GPS) açın.')));
        return; 
      }
    }

    // 2. İzin Kontrolü (ÖN PLAN)
    PermissionStatus permissionGranted = await _locationService.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _locationService.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konum izni reddedildi.')));
        return;
      }
    }
    print(">>> Ön plan konum izni alındı.");

    // 3. Arka Plan İzni
    bool backgroundEnabled = await _locationService.isBackgroundModeEnabled();
    if (!backgroundEnabled) {
      print(">>> Arka plan izni yok, isteniyor...");
      if (mounted) {
         await showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text("Arka Plan Konum İzni Gerekli"),
              content: Text("Canlı takip için, uygulama arka plandayken de konumunuzun alınmasına izin vermeniz gerekiyor. Lütfen bir sonraki ekranda 'Her zaman izin ver' seçeneğini seçin."),
              actions: [ TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text("Anladım")), ],
            )
         );
      }
      try {
        backgroundEnabled = await _locationService.enableBackgroundMode(enable: true);
      } catch (e) { print("XXX Arka plan modu etkinleştirme hatası: $e"); }
    }
    
    if (!backgroundEnabled) {
       print("XXX Kullanıcı arka plan iznini vermedi.");
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Canlı takip için arka plan izni şarttır.')));
       return;
    }
    print(">>> Arka plan konum izni alındı.");

    // 4. İzinler tamamsa, ÖNCE İLK KONUMU GÖNDER
    print(">>> İzinler tamam. İlk konum alınıyor...");
    try {
      await _locationService.changeSettings(accuracy: LocationAccuracy.high); 
      LocationData ilkKonum = await _locationService.getLocation();
      
      if (ilkKonum.latitude != null && ilkKonum.longitude != null) {
        print(">>> İlk konum alındı: ${ilkKonum.latitude}, ${ilkKonum.longitude}");
        await _ilanRef!.update({
          'tasiyiciAnlikKonum': {
            'latitude': ilkKonum.latitude,
            'longitude': ilkKonum.longitude,
            'sonGuncelleme': FieldValue.serverTimestamp(),
          }
        });
        print(">>> İlk konum Firebase'e başarıyla yazıldı!");
      } else {
        throw Exception("İlk konum verisi (lat/lng) null geldi.");
      }
    } catch (e) {
       print("XXX İlk konum alma hatası: $e");
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: İlk konum alınamadı. $e')));
       return;
    }

    // 5. Optimize ayarları yap (SİZİN MANTIĞINIZ)
    await _locationService.changeSettings(
      accuracy: LocationAccuracy.balanced,
      interval: 0,
      distanceFilter: 50 // SADECE 50 metre hareket edince
    );
    print(">>> Konum ayarları güncellendi: SADECE 50m hareket edince güncellenecek.");

    // 6. Dinlemeye başla ve dinleyiciyi kaydet
    print(">>> Konum dinleniyor (50m filtreli)...");
    
    await _locationSubscription?.cancel(); // Eski (varsa) dinleyiciyi iptal et
    _locationSubscription = _locationService.onLocationChanged.listen(
      (LocationData currentLocation) {
        if (currentLocation.latitude != null && currentLocation.longitude != null) {
          print(">>> YENİ OPTİMİZE KONUM ALINDI: ${currentLocation.latitude}, ${currentLocation.longitude}");
          _ilanRef?.update({
            'tasiyiciAnlikKonum': {
              'latitude': currentLocation.latitude,
              'longitude': currentLocation.longitude,
              'sonGuncelleme': FieldValue.serverTimestamp(),
            }
          }).catchError((e) { print("XXX Firebase'e konum yazma hatası: $e"); });
        }
      },
      onError: (error) { 
        print("XXX Konum dinleme hatası: $error");
        if (mounted) setState(() => _konumPaylasimiAktif = false);
      }
    );
    
    if (mounted) {
        setState(() => _konumPaylasimiAktif = true); // Butonu güncellemek için
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('✅ Canlı konum paylaşımı başladı!'), backgroundColor: Colors.green)
        );
    }
  }
  // --- CANLI KONUM FONKSİYONU SONU ---

  // --- PAZARLIK FONKSİYONLARI (TAM HALİ) ---
  Future<void> _yeniTeklifPopupGoster(double sonTeklif, String? sonTeklifiYapan) async {
    _teklifFiyatController.clear();
    
    final yeniTeklifFiyati = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Karşı Teklif Yap'),
          content: TextField(
            controller: _teklifFiyatController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(hintText: 'Yeni teklifiniz (TL)', prefixText: 'TL '),
          ),
          actions: [
            TextButton(child: const Text('İptal'), onPressed: () => Navigator.of(dialogContext).pop(null)),
            TextButton(child: const Text('Gönder'), onPressed: () => Navigator.of(dialogContext).pop(_teklifFiyatController.text.trim())),
          ],
        );
      },
    );

    if (yeniTeklifFiyati != null && yeniTeklifFiyati.isNotEmpty && mounted) {
      if (_teklifRef == null || _sohbetOdasiRef == null) return;
      try {
        final fiyatDouble = double.tryParse(yeniTeklifFiyati.replaceAll(',', '.'));
        if (fiyatDouble == null || fiyatDouble <= 0) throw Exception("Geçersiz fiyat.");
        
        final teklifiYapanRol = (_currentUser!.uid == widget.gondericiId) ? 'gonderici' : 'tasiyici';
        final aliciId = (teklifiYapanRol == 'gonderici') ? widget.tasiyiciId : widget.gondericiId;

        // 1. Pazarlık belgesini güncelle
        await _teklifRef!.update({
          'teklifFiyati': fiyatDouble,
          'sonTeklifiYapan': teklifiYapanRol,
          'zaman': FieldValue.serverTimestamp(),
        });

        // 2. ANA SOHBET BELGESİNİ GÜNCELLE
        await _sohbetOdasiRef!.update({
          'sonMesajMetni': "[Karşı Teklif: ${fiyatDouble.toStringAsFixed(0)} TL]",
          'sonMesajZamani': FieldValue.serverTimestamp(),
          'sonMesajGonderenId': _currentUser!.uid,
          'okundu_$aliciId': false,
        });
        
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Karşı teklifiniz gönderildi!'), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _anlasmayiOnayla(double sonTeklifFiyati) async {
    if (_ilanRef == null || _teklifRef == null || _sohbetOdasiRef == null || !mounted) return;

    try {
      final kod = (100000 + Random().nextInt(900000)).toString();
      
      // 1. Ana ilanı güncelle
      await _ilanRef!.update({
        'durum': 'Anlaşıldı',
        'tasiyiciId': widget.tasiyiciId,
        'teklif': sonTeklifFiyati,
        'teslimatKodu': kod,
        'tasiyiciTeslimEttiMi': false,
        'gorevTamamlandiMi': false,
      });

      // 2. Pazarlık belgesini de "anlaşıldı" olarak güncelle
      await _teklifRef!.update({'pazarlikDurumu': 'anlasildi'});

      // 3. ANA SOHBET BELGESİNİ GÜNCELLE
      final aliciId = (_currentUser!.uid == widget.gondericiId) ? widget.tasiyiciId : widget.gondericiId;
      await _sohbetOdasiRef!.update({
        'sonMesajMetni': "[Anlaşma Sağlandı: ${sonTeklifFiyati.toStringAsFixed(0)} TL]",
        'sonMesajZamani': FieldValue.serverTimestamp(),
        'sonMesajGonderenId': _currentUser!.uid,
        'okundu_$aliciId': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Anlaşma sağlandı! Teslimat Kodu oluşturuldu.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: ${e.toString()}')));
    }
  }
  // --- PAZARLIK FONKSİYONLARI SONU ---


  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.konusulanKisiAdi)),
        body: const Center(
          child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Sohbet yükleniyor..."),
            ],
          ),
        ),
      );
    }

    final benGondericiyim = _currentUser!.uid == widget.gondericiId;
    final benTasiyiciyim = _currentUser!.uid == widget.tasiyiciId;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF212121),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.konusulanKisiAdi, style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // MESAJ LİSTESİ
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _sohbetOdasiRef!.collection('mesajlar').orderBy('zaman', descending: true).snapshots(),
              builder: (context, snapshot) {
                 if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                 if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Görüşmeyi başlatın...'));
                 final mesajlar = snapshot.data!.docs;
                 return ListView.builder(
                    reverse: true,
                    itemCount: mesajlar.length,
                    itemBuilder: (context, index) {
                        final mesaj = mesajlar[index].data() as Map<String, dynamic>;
                        final gonderenId = mesaj['gonderenId'] as String?;
                        if (gonderenId == null) return const SizedBox.shrink();
                        final mesajBanaMiAit = gonderenId == _currentUser!.uid;
                        return Align(
                           alignment: mesajBanaMiAit ? Alignment.centerRight : Alignment.centerLeft,
                           child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              decoration: BoxDecoration( color: mesajBanaMiAit ? Color(0xFF32D74B) : Colors.grey[300], borderRadius: BorderRadius.circular(12)),
                              child: Text(mesaj['mesajMetni'] ?? '', style: TextStyle(color: mesajBanaMiAit ? Colors.white : Colors.black)),
                           ),
                        );
                    },
                 );
              },
            ),
          ),
          
          // --- BUTONLAR / BİLGİ ALANI (NİHAİ PAZARLIK SİSTEMLİ) ---
          StreamBuilder<DocumentSnapshot>(
            stream: _ilanRef!.snapshots(), // 1. Ana ilanın durumunu dinle
            builder: (context, ilanSnapshot) {
                if (!ilanSnapshot.hasData || !ilanSnapshot.data!.exists) return const SizedBox.shrink();
                final ilanVerisi = ilanSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                final ilanDurumu = (ilanVerisi['durum'] as String? ?? '').trim();
                
                // --- PAZARLIK AŞAMASI (İlan durumu "Aktif") ---
                if (ilanDurumu == 'Aktif') {
                   return StreamBuilder<DocumentSnapshot>(
                     stream: _teklifRef!.snapshots(),
                     builder: (context, teklifSnapshot) {
                        if (!teklifSnapshot.hasData || !teklifSnapshot.data!.exists) {
                           return Padding(
                             padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                             child: TextButton(
                               child: Text("Teklif artık geçerli değil.", style: TextStyle(color: Colors.red)),
                               onPressed: () => Navigator.of(context).pop(),
                             ),
                           );
                        }
                        final teklifVerisi = teklifSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                        final sonTeklif = (teklifVerisi['teklifFiyati'] as num? ?? 0);
                        final sonTeklifiYapan = teklifVerisi['sonTeklifiYapan'] as String?;

                        String teklifYazisi = "Teklif: ${sonTeklif.toStringAsFixed(0)} TL";
                        bool benimSiram = false;

                        if (sonTeklifiYapan == 'gonderici' && benTasiyiciyim) {
                           teklifYazisi = "Karşı Teklif: ${sonTeklif.toStringAsFixed(0)} TL";
                           benimSiram = true;
                        } else if (sonTeklifiYapan == 'tasiyici' && benGondericiyim) {
                           teklifYazisi = "Teklif: ${sonTeklif.toStringAsFixed(0)} TL";
                           benimSiram = true;
                        } else if (sonTeklifiYapan == null) {
                           return const Padding(padding: EdgeInsets.all(8.0), child: Text("Teklif hatası."));
                        } else {
                           teklifYazisi = "Teklif Gönderildi: ${sonTeklif.toStringAsFixed(0)} TL (Yanıt bekleniyor)";
                        }

                        return Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                             color: Colors.grey[100],
                             border: Border(top: BorderSide(color: Colors.grey[300]!)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min, 
                            children: [
                              Text(teklifYazisi, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              if (benimSiram)
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        child: const Text('Yeni Teklif Yap'),
                                        onPressed: () => _yeniTeklifPopupGoster(sonTeklif.toDouble(), sonTeklifiYapan),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // ...
// ...
Expanded(
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF32D74B)),
    child: const Text('KABUL ET'),
    onPressed: () {
      // Direkt ödemeye değil, önce ÖZET ekranına git
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OdemeOzetEkrani(
            tutar: sonTeklif.toDouble(),
            ilanAdi: "Kargo Taşıma Hizmeti", // Dinamik yapmak istersen: ilanRotasi
            tasiyiciAdi: widget.konusulanKisiAdi,
            onOdemeBasarili: () {
              // Eğer ödeme başarılı olursa burası çalışacak
              _anlasmayiOnayla(sonTeklif.toDouble());
            },
          ),
        ),
      );
    },
  ),
),

                                  ],
                                ),
                            ],
                          ),
                        );
                     }
                   );
                } 
                // --- GÖREV AŞAMASI (İlan durumu "Anlaşıldı" veya "Tamamlandı") ---
                else {
                  final gorevTamamlandiMi = ilanVerisi['gorevTamamlandiMi'] as bool? ?? false;
                  final tasiyiciTeslimEttiMi = ilanVerisi['tasiyiciTeslimEttiMi'] as bool? ?? false;
                  final teslimatKodu = ilanVerisi['teslimatKodu'] as String?;

                  if (benGondericiyim) {
                      if (ilanDurumu == 'Anlaşıldı' && tasiyiciTeslimEttiMi && !gorevTamamlandiMi) {
                         return Padding(
                           padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                           child: ElevatedButton(
                             style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF32D74B), minimumSize: const Size(double.infinity, 50), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                             onPressed: _goreviTamamlaOnayla,
                             child: const Text('TESLİM ALDIM, GÖREVİ TAMAMLA'),
                           ),
                         );
                      } else if (ilanDurumu == 'Anlaşıldı' && !tasiyiciTeslimEttiMi && !gorevTamamlandiMi) {
                         return Padding(
                           padding: const EdgeInsets.all(16.0),
                           child: Column(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               ElevatedButton.icon(
                                 icon: const Icon(Icons.map_outlined, color: Colors.white),
                                 label: const Text('Kargoyu Canlı Takip Et'),
                                 style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, minimumSize: const Size(double.infinity, 50), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                 onPressed: () {
                                   final ilanRotasi = (ilanVerisi['alinacakAdres'] ?? '...') + ' -> ' + (ilanVerisi['teslimAdres'] ?? '...');
                                   Navigator.push(
                                     context,
                                     MaterialPageRoute(
                                       builder: (context) => MapTakipEkrani(
                                         ilanId: widget.ilanId,
                                         ilanRotasi: ilanRotasi,
                                       ),
                                     ),
                                   );
                                 },
                               ),
                               const SizedBox(height: 24),
                               const Text('Taşıyıcı teslimatı onaylamak için aşağıdaki koda ihtiyaç duyacak. Lütfen bu kodu kargoyu teslim alacak kişiye iletin:', textAlign: TextAlign.center),
                               const SizedBox(height: 10),
                               SelectableText(teslimatKodu ?? '--- ---', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.blue)),
                               const SizedBox(height: 20),
                               TextButton(
                                 onPressed: _goreviIptalEtOnayla,
                                 child: const Text('Görevi İptal Et', style: TextStyle(color: Colors.red)),
                               ),
                             ],
                           ),
                         );
                      }
                  } else if (benTasiyiciyim) {
                      if (ilanDurumu == 'Anlaşıldı' && !tasiyiciTeslimEttiMi && !gorevTamamlandiMi) {
                         return Padding(
                           padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                           child: Column(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               ElevatedButton.icon(
                                 icon: Icon(_konumPaylasimiAktif ? Icons.location_off : Icons.my_location, color: Colors.white),
                                 label: Text(_konumPaylasimiAktif ? 'Konum Paylaşımı Aktif' : 'Canlı Konum Paylaşmayı Başlat'),
                                 style: ElevatedButton.styleFrom(
                                    backgroundColor: _konumPaylasimiAktif ? Colors.grey : Color(0xFF32D74B),
                                    minimumSize: const Size(double.infinity, 50), 
                                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                                 ),
                                 onPressed: _konumPaylasimiAktif ? null : _konumPaylasmayiBaslat, // Aktifse butonu kilitle
                               ),
                               const SizedBox(height: 8),
                               ElevatedButton(
                                 style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size(double.infinity, 50), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                 onPressed: () { if (teslimatKodu != null) _teslimatKoduDogrulaPopup(teslimatKodu); },
                                 child: const Text('Teslimatı Kod ile Doğrula'),
                               ),
                               const SizedBox(height: 8),
                               TextButton(
                                 onPressed: _goreviIptalEtOnayla,
                                 child: const Text('Görevi İptal Et', style: TextStyle(color: Colors.red)),
                               ),
                             ],
                           ),
                         );
                      }
                       else if (ilanDurumu == 'Anlaşıldı' && tasiyiciTeslimEttiMi && !gorevTamamlandiMi) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Gönderici onayı bekleniyor...', textAlign: TextAlign.center, style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                          );
                       }
                  }
                  return const SizedBox.shrink(); // Diğer durumlar
                }
            },
          ),
          
          // MESAJ YAZMA ALANI
          Padding(
            padding: const EdgeInsets.all(8.0).copyWith(bottom: MediaQuery.of(context).padding.bottom + 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mesajController,
                    decoration: InputDecoration(
                      hintText: 'Mesajınızı yazın...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _mesajGonder(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF32D74B)),
                  onPressed: _mesajGonder,
                  style: IconButton.styleFrom(backgroundColor: Colors.grey[200]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// KOD BLOK SONU