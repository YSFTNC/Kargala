// KOD BLOK BAŞLANGICI (bildirim_ayarlari_ekrani.dart - YENİ DOSYA)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BildirimAyarlariEkrani extends StatefulWidget {
  const BildirimAyarlariEkrani({super.key});

  @override
  State<BildirimAyarlariEkrani> createState() => _BildirimAyarlariEkraniState();
}

class _BildirimAyarlariEkraniState extends State<BildirimAyarlariEkrani> {
  final _currentUser = FirebaseAuth.instance.currentUser;
  late final DocumentReference _userRef;

  bool _isLoading = true;
  // Ayarlar için varsayılan değerler (eğer veritabanında hiç ayarlanmamışsa)
  bool _yeniTeklifBildirimleri = true;
  bool _yeniMesajBildirimleri = true;
  bool _anlasmaBildirimleri = true;

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) {
      _userRef = FirebaseFirestore.instance.collection('kullanicilar').doc(_currentUser!.uid);
      _ayarlariYukle();
    } else {
      setState(() => _isLoading = false);
    }
  }

  // 1. Ekran açıldığında Firestore'dan mevcut ayarları çek
  Future<void> _ayarlariYukle() async {
    try {
      final doc = await _userRef.get();
      if (mounted && doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        
        // Firestore'da 'bildirim_ayarlari' haritasını ara
        final ayarlar = data?['bildirim_ayarlari'] as Map<String, dynamic>?;
        
        setState(() {
          // Eğer ayar bulunamazsa, varsayılan 'true' kullanılır
          _yeniTeklifBildirimleri = ayarlar?['yeni_teklif_bildirimleri'] ?? true;
          _yeniMesajBildirimleri = ayarlar?['yeni_mesaj_bildirimleri'] ?? true;
          _anlasmaBildirimleri = ayarlar?['anlasma_bildirimleri'] ?? true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ayarlar yüklenemedi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. Bir 'switch' değiştiğinde Firestore'u güncelle
  Future<void> _ayariGuncelle(String ayarAdi, bool yeniDeger) async {
    if (_currentUser == null) return;

    try {
      // SetOptions(merge: true) sayesinde, 'kullanicilar' belgesindeki
      // diğer verileri (ad, soyad vb.) silmeden, sadece 'bildirim_ayarlari'
      // haritasının içindeki ilgili alanı güncelleriz.
      await _userRef.set({
        'bildirim_ayarlari': {
          ayarAdi: yeniDeger,
        }
      }, SetOptions(merge: true));
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ayar güncellenemedi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF212121),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Bildirim Ayarları', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
              ? const Center(child: Text('Ayarları görmek için giriş yapmalısınız.'))
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  children: [
                    SwitchListTile(
                      title: const Text('Yeni Teklifler'),
                      subtitle: const Text('Bir ilanınıza yeni bir teklif geldiğinde bildirim alın.'),
                      value: _yeniTeklifBildirimleri,
                      onChanged: (bool newValue) {
                        setState(() => _yeniTeklifBildirimleri = newValue);
                        _ayariGuncelle('yeni_teklif_bildirimleri', newValue);
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Yeni Mesajlar'),
                      subtitle: const Text('Sohbet ekranından yeni bir mesaj aldığınızda bildirim alın.'),
                      value: _yeniMesajBildirimleri,
                      onChanged: (bool newValue) {
                        setState(() => _yeniMesajBildirimleri = newValue);
                        _ayariGuncelle('yeni_mesaj_bildirimleri', newValue);
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Anlaşma ve Görev Durumları'),
                      subtitle: const Text('Bir anlaşma sağlandığında veya görev tamamlandığında bildirim alın.'),
                      value: _anlasmaBildirimleri,
                      onChanged: (bool newValue) {
                        setState(() => _anlasmaBildirimleri = newValue);
                        _ayariGuncelle('anlasma_bildirimleri', newValue);
                      },
                    ),
                  ],
                ),
    );
  }
}
// KOD BLOK SONU