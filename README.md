# مُيسّر — تطبيق iPhone و iPad

منصة أدوات ذكية عربية مستقلة تمامًا (معرّف الحزمة `com.muyassir.app`)، مكتوبة بـ **Swift / SwiftUI** وتعمل على iOS 17 فأحدث، بدعم كامل للعربية واتجاه RTL.

## المبادئ
- **المعالجة على الجهاز**: PDFKit و Vision و VisionKit و Core Image و Speech — لا تُرفع ملفات المستخدم لأي خادم.
- **دون إنترنت** لكل الأدوات عدا "محوّل العملات" (يجلب الأسعار فقط عند ضغط الزر من open.er-api.com المجانية) و"تحويل الكلام إلى نص" إن لم يدعم الجهاز التعرف المحلي (يطلب موافقة صريحة).
- **الملفات المؤقتة**: تُنسخ المدخلات إلى `tmp/in` وتُحذف بعد كل عملية، والنتائج في `Documents/out/<وقت>` وتُحذف تلقائيًا بعد 24 ساعة ما لم يحفظها المستخدم.
- **مكتبات**: لا توجد أي مكتبة خارجية؛ فقط أُطر Apple. الخط IBM Plex Sans Arabic برخصة OFL (انظر `docs/`).
- لا اشتراكات ولا إعلانات ولا تتبع.

## البناء
```bash
brew install xcodegen
xcodegen generate
open Muyassir.xcodeproj
```
الاختبارات: `xcodebuild -scheme Muyassir -destination 'platform=iOS Simulator,name=iPhone 16' test`

يُبنى المشروع ويُختبر تلقائيًا على GitHub Actions (macOS)، ويفتح كل أداة على محاكي iPhone و iPad ويحفظ لقطاتها في فرع `ci-shots`.

## البنية
| المجلد | المحتوى |
|---|---|
| `Muyassir/Engine` | المحركات: الحاسبات، PDF، الصور، OCR، Office (DOCX/XLSX/PPTX)، ZIP، التاريخ الهجري، منشئ PDF عربي |
| `Muyassir/App` | نقطة الدخول، التخزين المحلي، سجل الأدوات الـ74 |
| `Muyassir/UI` | المكونات، الرئيسية، شاشة الملفات العامة |
| `Muyassir/Tools` | شاشات الأدوات حسب الأقسام الثمانية |
| `MuyassirTests` | اختبارات الوحدة والمحركات |

التوثيق: [قائمة الأدوات وحالتها](docs/TOOLS.md) • [الخصوصية والأداء والتراخيص](docs/PRIVACY.md) • [نتائج الاختبارات](docs/TESTING.md)

فتح أداة مباشرة (للاختبار): تشغيل التطبيق بالوسيط `-tool <id>` مثل `-tool vat`.
