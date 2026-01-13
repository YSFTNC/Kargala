// KOD BLOK BAŞLANGICI (profil_duzenle_ekrani.dart - YENİ DOSYA)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilDuzenleEkrani extends StatefulWidget {
  const ProfilDuzenleEkrani({super.key});

  @override
  State<ProfilDuzenleEkrani> createState() => _ProfilDuzenleEkraniState();
}

class _ProfilDuzenleEkraniState extends State<ProfilDuzenleEkrani> {
  final _adController = TextEditingController();
  final _soyadController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;

  bool _isLoading = true; // Veri yüklenirken
  bool _isSaving = false; // Kaydederken

  @override
  void initState() {
    super.initState();
    _profilBilgileriniYukle();
  }

  @override
  void dispose() {
    _adController.dispose();
    _soyadController.dispose();
    super.dispose();
  }

  // 1. Ekran açıldığında mevcut Ad/Soyad'ı Firestore'dan çek
  Future<void> _profilBilgileriniYukle() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('kullanicilar')
          .doc(_currentUser!.uid)
          .get();
          
      if (mounted && userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        // 'kayit_ol_ekrani.dart' dosyasında kullandığımız 'ad' ve 'soyad' alanlarını okuyoruz
        _adController.text = data['ad'] ?? '';
        _soyadController.text = data['soyad'] ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil bilgileri yüklenemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. "Kaydet" butonuna basıldığında Firestore'u güncelle
  Future<void> _profiliGuncelle() async {
    if (_currentUser == null) return;

    final ad = _adController.text.trim();
    final soyad = _soyadController.text.trim();

    if (ad.isEmpty || soyad.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad ve Soyad boş bırakılamaz.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (mounted) setState(() => _isSaving = true);

    try {
      // 'kullanicilar' koleksiyonundaki belgeyi güncelle
      await FirebaseFirestore.instance
          .collection('kullanicilar')
          .doc(_currentUser!.uid)
          .update({
            'ad': ad,
            'soyad': soyad,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil başarıyla güncellendi!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(); // Ayarlar ekranına geri dön
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: Profil güncellenemedi. $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF212121),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Profili Düzenle', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _adController,
                    decoration: InputDecoration(
                      labelText: 'Adınız',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _soyadController,
                    decoration: InputDecoration(
                      labelText: 'Soyadınız',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _profiliGuncelle,
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          )
                        : const Text('KAYDET'),
                  ),
                ],
              ),
            ),
    );
  }
}
// KOD BLOK SONU