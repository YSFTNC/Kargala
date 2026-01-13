// KOD BLOK BAŞLANGICI (sifre_degistir_ekrani.dart - YENİ DOSYA)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SifreDegistirEkrani extends StatefulWidget {
  const SifreDegistirEkrani({super.key});

  @override
  State<SifreDegistirEkrani> createState() => _SifreDegistirEkraniState();
}

class _SifreDegistirEkraniState extends State<SifreDegistirEkrani> {
  final _mevcutSifreController = TextEditingController();
  final _yeniSifreController = TextEditingController();
  final _yeniSifreTekrarController = TextEditingController();
  
  final _currentUser = FirebaseAuth.instance.currentUser;
  bool _isSaving = false;

  @override
  void dispose() {
    _mevcutSifreController.dispose();
    _yeniSifreController.dispose();
    _yeniSifreTekrarController.dispose();
    super.dispose();
  }

  Future<void> _sifreyiDegistir() async {
    if (_currentUser == null) return;

    if (mounted) setState(() => _isSaving = true);

    final mevcutSifre = _mevcutSifreController.text.trim();
    final yeniSifre = _yeniSifreController.text.trim();
    final yeniSifreTekrar = _yeniSifreTekrarController.text.trim();

    // 1. Girdi Kontrolleri
    if (mevcutSifre.isEmpty || yeniSifre.isEmpty || yeniSifreTekrar.isEmpty) {
      _hataGoster('Tüm alanlar doldurulmalıdır.');
      if (mounted) setState(() => _isSaving = false);
      return;
    }
    if (yeniSifre != yeniSifreTekrar) {
      _hataGoster('Yeni şifreler eşleşmiyor.');
      if (mounted) setState(() => _isSaving = false);
      return;
    }
    if (yeniSifre.length < 6) {
      _hataGoster('Yeni şifre en az 6 karakter olmalıdır.');
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    try {
      // 2. Yeniden Kimlik Doğrulama (Güvenlik Adımı)
      // Firebase, şifre gibi hassas bir işlemi değiştirmeden önce
      // kullanıcının kimliğini (mevcut şifresini girerek) doğrulamasını ister.
      final cred = EmailAuthProvider.credential(
        email: _currentUser!.email!, 
        password: mevcutSifre,
      );
      
      await _currentUser!.reauthenticateWithCredential(cred);

      // 3. Kimlik doğrulandıysa, şifreyi değiştir
      await _currentUser!.updatePassword(yeniSifre);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şifreniz başarıyla güncellendi!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(); // Ayarlar ekranına geri dön
      }

    } on FirebaseAuthException catch (e) {
      // Hata koduna göre kullanıcıya net mesaj ver
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _hataGoster('Mevcut şifreniz hatalı!');
      } else if (e.code == 'weak-password') {
        _hataGoster('Yeni şifre çok zayıf.');
      } else {
        _hataGoster('Bir hata oluştu: ${e.message}');
      }
    } catch (e) {
      _hataGoster('Beklenmedik bir hata oluştu: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _hataGoster(String mesaj) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mesaj), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Eğer kullanıcı Google ile giriş yapmışsa, şifresi yoktur.
    // Bu ekranı göstermenin bir anlamı yok.
    final bool isEmailUser = _currentUser?.providerData
        .any((info) => info.providerId == 'password') ?? false;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF212121),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Şifre Değiştir', style: TextStyle(color: Colors.white)),
      ),
      body: !isEmailUser
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Google ile giriş yaptığınız için şifre değiştirme işlemi yapamazsınız.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _mevcutSifreController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Mevcut Şifreniz',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _yeniSifreController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Yeni Şifreniz',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _yeniSifreTekrarController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Yeni Şifreniz (Tekrar)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _sifreyiDegistir,
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          )
                        : const Text('ŞİFREYİ GÜNCELLE'),
                  ),
                ],
              ),
            ),
    );
  }
}
// KOD BLOK SONU