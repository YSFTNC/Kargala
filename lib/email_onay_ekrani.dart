// KOD BLOK BAŞLANGICI (email_onay_ekrani.dart)
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'ana_ekran.dart';

class EmailOnayEkrani extends StatefulWidget {
  const EmailOnayEkrani({super.key});

  @override
  State<EmailOnayEkrani> createState() => _EmailOnayEkraniState();
}

class _EmailOnayEkraniState extends State<EmailOnayEkrani> {
  bool _isVerified = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 1. Kullanıcı e-postasını onayladı mı diye periyodik olarak kontrol et
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkEmailVerified();
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Ekran kapanırsa zamanlayıcıyı durdur
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Kullanıcı yoksa dur

    await user.reload(); // Kullanıcının en güncel durumunu Firebase'den çek
    if (user.emailVerified) {
      _timer?.cancel(); // Zamanlayıcıyı durdur
      if (mounted) {
        // E-posta onaylanmış! Ana Ekrana yönlendir.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => AnaEkran(currentUser: user)),
        );
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Yeni doğrulama e-postası gönderildi.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-posta Doğrulama'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'E-postanızı doğrulamanız gerekiyor.',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                '${FirebaseAuth.instance.currentUser?.email} adresine bir doğrulama linki gönderdik. Lütfen e-posta kutunuzu kontrol edin.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _checkEmailVerified, // Manuel kontrol
                child: const Text('Onayladım, Kontrol Et'),
              ),
              TextButton(
                onPressed: _resendVerificationEmail, // Tekrar gönder
                child: const Text('E-posta Gelmedi mi? Tekrar Gönder'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () {
                  FirebaseAuth.instance.signOut(); // Çıkış yap
                },
                child: const Text('İptal Et (Çıkış Yap)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// KOD BLOK SONU