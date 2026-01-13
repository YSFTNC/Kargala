// KOD BLOK BAŞLANGICI
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'kayit_ol_ekrani.dart';
import 'ana_ekran.dart';

class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});
  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  

  final _resetEmailController = TextEditingController();


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  Future<void> girisYap() async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (userCredential.user == null) return;
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => AnaEkran(currentUser: userCredential.user!)),
          (Route<dynamic> route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
       if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Giriş Hatası: ${e.message}'))); }
    }
  }

  Future<void> googleIleGirisYap() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      if (userCredential.user == null) return;
      final user = userCredential.user!;
      final userDocRef = FirebaseFirestore.instance.collection('kullanicilar').doc(user.uid);
      final doc = await userDocRef.get();
      if (!doc.exists) { /* Firestore'a yeni kullanıcı kaydı */ }
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => AnaEkran(currentUser: user)),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) { /* Hata yönetimi */ }
  }

  // --- YENİ EKLENEN FONKSİYON: ŞİFRE SIFIRLAMA POPUP'I ---
  Future<void> _sifreSifirlaPopupGoster() async {
    // Popup'ı açmadan önce, ana e-posta kutusundaki metni al (kullanıcıya kolaylık)
    _resetEmailController.text = _emailController.text.trim();

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Şifre Sıfırlama'),
          content: TextField(
            controller: _resetEmailController, // Yeni controller'ı kullan
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: "Sıfırlama için e-postanızı girin"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Popup'ı kapat
              },
            ),
            TextButton(
              child: const Text('Gönder'),
              onPressed: () async {
                final email = _resetEmailController.text.trim();
                if (email.isEmpty) {
                  // Hata (Bu mesajı göstermek yerine popup içinde de yapabiliriz)
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir e-posta adresi girin.')));
                  return;
                }
                
                try {
                  // Firebase'e sıfırlama e-postası gönderme komutu
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                  
                  if (context.mounted) {
                    Navigator.of(dialogContext).pop(); // Popup'ı kapat
                    // Kullanıcıyı bilgilendir
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Şifre sıfırlama e-postası gönderildi. Lütfen kutunuzu kontrol edin.')),
                    );
                  }
                } on FirebaseAuthException catch (e) {
                   if (context.mounted) {
                      Navigator.of(dialogContext).pop(); // Hata olsa bile popup'ı kapat
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Hata: ${e.message}')),
                      );
                   }
                }
              },
            ),
          ],
        );
      },
    );
  }
  // --- YENİ FONKSİYON SONU ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giriş Yap'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView( // Ekran küçükse taşmasın diye kaydırma ekledik
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40), // Üstten biraz boşluk
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'E-posta'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Şifre'),
              ),
              
              // --- YENİ EKLENEN LİNK ---
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _sifreSifirlaPopupGoster, // Popup'ı açan fonksiyonu bağladık
                    child: const Text('Şifreni mi unuttun?'),
                  ),
                ],
              ),
              // --- YENİ LİNK SONU ---
              
              const SizedBox(height: 12), // Boşluğu azalttık
              ElevatedButton(
                onPressed: girisYap,
                child: const Text('GİRİŞ YAP'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const KayitOlEkrani()),
                    );
                  }
                },
                child: const Text('Hesabın yok mu? Kayıt Ol'),
              ),
              const SizedBox(height: 24),
              const Row(children: <Widget>[ Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text("VEYA")), Expanded(child: Divider()) ]),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black54, elevation: 2),
                icon: const Text('G', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                label: const Text('Google ile Giriş Yap', style: TextStyle(fontSize: 16)),
                onPressed: googleIleGirisYap, 
              ),
              const SizedBox(height: 40), // Alttan biraz boşluk
            ],
          ),
        ),
      ),
    );
  }
}
// KOD BLOK SONU