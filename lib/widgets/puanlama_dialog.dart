// KOD BLOK BAŞLANGICI
import 'package:flutter/material.dart';

// Bu fonksiyon, puanlama diyalogunu göstermek için çağrılacak.
// Kimin kimi puanladığını ve hangi ilan için olduğunu bilmemiz gerekiyor.
Future<Map<String, dynamic>?> puanlamaDialogGoster(
    BuildContext context,
    String puanlananKullaniciAdi, // Örn: "Taşıyıcıyı Puanla: Yusuf Tunç"
) async {
  int _secilenPuan = 0; // Başlangıçta hiç yıldız seçili değil
  final _yorumController = TextEditingController();

  return showDialog<Map<String, dynamic>>( // Geriye puan ve yorumu bir Map olarak döndürecek
    context: context,
    barrierDismissible: false, // Dışarı tıklayarak kapatmayı engelle
    builder: (BuildContext dialogContext) {
      // StatefulBuilder, diyalogun içindeki yıldız seçimini anlık olarak güncelleyebilmemizi sağlar.
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('$puanlananKullaniciAdi Puanla'),
            content: SingleChildScrollView( // İçerik sığmazsa kaydırılabilir yapar
              child: Column(
                mainAxisSize: MainAxisSize.min, // İçeriğe göre boyutlan
                children: <Widget>[
                  // Yıldızları oluşturma
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _secilenPuan ? Icons.star : Icons.star_border, // Seçiliyse dolu, değilse boş yıldız
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          // Yıldız seçildiğinde puanı güncelle ve ekranı yeniden çiz
                          setState(() {
                            _secilenPuan = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  // Yorum kutusu
                  TextField(
                    controller: _yorumController,
                    maxLines: 3, // 3 satırlık bir alan
                    decoration: const InputDecoration(
                      hintText: 'Yorumunuzu buraya yazın (isteğe bağlı)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('İptal'),
                onPressed: () {
                  Navigator.of(dialogContext).pop(null); // Hiçbir şey döndürmeden kapat
                },
              ),
              TextButton(
                child: Text('Gönder'),
                onPressed: () {
                  // Eğer puan seçilmemişse göndermeyi engelle
                  if (_secilenPuan == 0) {
                     ScaffoldMessenger.of(dialogContext).showSnackBar(
                       const SnackBar(content: Text('Lütfen en az 1 yıldız seçin!'), backgroundColor: Colors.red),
                     );
                     return; // İşlemi durdur
                  }
                  // Seçilen puanı ve yorumu bir Map içinde geri döndür
                  Navigator.of(dialogContext).pop({
                    'puan': _secilenPuan,
                    'yorum': _yorumController.text.trim(),
                  });
                },
              ),
            ],
          );
        },
      );
    },
  );
}
// KOD BLOK SONU