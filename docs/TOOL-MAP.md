# الخريطة المركزية للأدوات

كل أداة: التصنيف، المعرف، المسار، المكون المسؤول في كل منصة، والاختبار الآلي الذي يغطيها.

المسارات: Android `tool/<id>` و `cat/<id>` (وأيضا عبر Intent extra `tool` / `cat`). iOS: قيمة `Tool` في NavigationStack (وأيضا وسيط التشغيل `-tool <id>` / `-cat <id>`).

| التصنيف | المعرف | الأداة | مكون Android | مكون iOS | اختبار وظيفي Android | اختبار وظيفي iOS |
|---|---|---|---|---|---|---|
| files | `pdf_word` | PDF إلى Word | `PdfToWord` | `PdfToWord` | `pdfToWord` | `testPdfToWord` |
| files | `word_pdf` | Word إلى PDF | `WordToPdf` | `WordToPdf` | `wordToPdf` | `testWordToPdf` |
| files | `pdf_excel` | PDF إلى Excel | `PdfToExcel` | `PdfToExcel` | `pdfToExcel` | `testPdfToExcel` |
| files | `excel_pdf` | Excel إلى PDF | `ExcelToPdf` | `ExcelToPdf` | `excelToPdf` | `testExcelToPdf` |
| files | `pdf_ppt` | PDF إلى PowerPoint | `PdfToPpt` | `PdfToPpt` | `pdfToPpt` | `testPdfToPpt` |
| files | `ppt_pdf` | PowerPoint إلى PDF | `PptToPdf` | `PptToPdf` | `pptToPdf` | `testPptToPdf` |
| files, images | `pdf_img` | PDF إلى صور | `PdfToImages` | `PdfToImages` | `pdfToImages` | `testPdfToImages` |
| files, images | `img_pdf` | صور إلى PDF | `ImagesToPdf` | `ImagesToPdf` | `imagesToPdf` | `testImagesToPdf` |
| files | `pdf_merge` | دمج PDF | `PdfMerge` | `PdfMerge` | `pdfMerge` | `testPdfMerge` |
| files | `pdf_split` | تقسيم PDF | `PdfSplit` | `PdfSplit` | `pdfSplit` | `testPdfSplit` |
| files | `pdf_compress` | ضغط PDF | `PdfCompress` | `PdfCompress` | `pdfCompress` | `testPdfCompress` |
| files | `pdf_reorder` | ترتيب صفحات PDF | `PdfReorder` | `PdfPages` | `pdfReorder` | `testPdfReorder` |
| files | `pdf_delete` | حذف صفحات PDF | `PdfDelete` | `PdfPages` | `pdfDelete` | `testPdfDelete` |
| files | `pdf_extract` | استخراج صفحات PDF | `PdfExtract` | `PdfPages` | `pdfExtract` | `testPdfExtract` |
| files | `pdf_rotate` | تدوير صفحات PDF | `PdfRotate` | `PdfPages` | `pdfRotate` | `testPdfRotate` |
| files, images, smart | `ocr` | استخراج النص (OCR) | `OcrTool` | `OcrTool` | `ocrImage` | `testOcr` |
| files | `scan` | مسح المستندات بالكاميرا | `ScanTool` | `ScanTool` | التنقل | التنقل |
| files | `pdf_protect` | حماية PDF بكلمة مرور | `PdfProtect` | `PdfProtect` | `pdfProtect` | `testPdfProtect` |
| files | `pdf_unlock` | إزالة حماية PDF | `PdfUnlock` | `PdfUnlock` | التنقل | `testPdfUnlock` |
| files | `zip` | ضغط ZIP | `ZipTool` | `ZipTool` | `zip` | `testZip` |
| files | `unzip` | فك ضغط ZIP | `UnzipTool` | `UnzipTool` | `unzip` | `testUnzip` |
| files, images | `img_convert` | تحويل صيغ الصور | `ImgConvert` | `ImgConvert` | `imgConvert` | `testImgConvert` |
| images | `img_compress` | ضغط الصور | `ImgCompress` | `ImgCompress` | `imgCompress` | `testImgCompress` |
| images | `img_resize` | تغيير الأبعاد | `ImgResize` | `ImgResize` | `imgResize` | `testImgResize` |
| images | `img_crop` | قص الصور | `ImgCrop` | `ImgCrop` | `imgCrop` | `testImgCrop` |
| images | `img_rotate` | تدوير وقلب | `ImgRotate` | `ImgRotate` | `imgRotate` | `testImgRotate` |
| images | `img_enhance` | تحسين الصور | `ImgEnhance` | `ImgEnhance` | `imgEnhance` | `testImgEnhance` |
| images | `img_bg` | إزالة الخلفية | `ImgBackground` | `ImgBackground` | `imgBackground` | التنقل |
| images | `img_batch` | معالجة دفعة واحدة | `ImgBatch` | `ImgBatch` | `imgBatch` | `testImgBatch` |
| images | `id_photo` | صور الوثائق | `IdPhoto` | `IdPhoto` | `idPhoto` | `testIdPhoto` |
| study | `gpa` | حاسبة المعدل | `GpaTool` | `GpaTool` | `gpaCalculates` | التنقل |
| study, calc | `percent` | النسب والدرجات | `PercentTool` | `PercentTool` | `percentCalculates` | `testPercent` |
| study | `timetable` | الجدول الدراسي | `TimetableTool` | `TimetableTool` | التنقل | التنقل |
| study | `exams` | جدول الاختبارات | `ExamsTool` | `ExamsTool` | التنقل | التنقل |
| study | `homework` | تنظيم الواجبات | `HomeworkTool` | `HomeworkTool` | التنقل | التنقل |
| study | `attendance` | متابعة الحضور | `AttendanceTool` | `AttendanceTool` | التنقل | التنقل |
| study | `quiz_maker` | إنشاء الاختبارات | `QuizMaker` | `QuizMaker` | التنقل | التنقل |
| study | `worksheet` | أوراق العمل | `WorksheetTool` | `WorksheetTool` | التنقل | التنقل |
| study | `flashcards` | بطاقات المراجعة | `FlashcardsTool` | `FlashcardsTool` | التنقل | التنقل |
| study | `study_timer` | مؤقت المذاكرة | `StudyTimer` | `StudyTimer` | التنقل | التنقل |
| study, docs | `certificate` | شهادات الإنجاز | `CertificateTool` | `CertificateTool` | التنقل | التنقل |
| saudi, calc | `vat` | ضريبة القيمة المضافة | `VatTool` | `VatTool` | `vatCalculates` | `testVat` |
| saudi | `salary` | حاسبة الراتب | `SalaryTool` | `SalaryTool` | `salaryCalculates` | `testSalary` |
| saudi | `eos` | مكافأة نهاية الخدمة | `EosTool` | `EosTool` | `endOfServiceCalculates` | `testEndOfService` |
| saudi | `leave` | حاسبة الإجازات | `LeaveTool` | `LeaveTool` | التنقل | التنقل |
| saudi, calc | `finance` | التمويل والأقساط | `FinanceTool` | `FinanceTool` | `financeCalculates` | `testFinance` |
| saudi, calc | `discount` | حاسبة الخصومات | `DiscountTool` | `DiscountTool` | `discountCalculates` | `testDiscount` |
| saudi, calc | `hijri` | التاريخ الهجري والميلادي | `HijriTool` | `HijriTool` | `hijriConverts` | التنقل |
| saudi | `gov_dir` | دليل المنصات الحكومية | `GovDirectory` | `GovDirectory` | التنقل | التنقل |
| saudi | `emergency` | أرقام الطوارئ | `EmergencyTool` | `EmergencyTool` | التنقل | التنقل |
| saudi, productivity | `documents` | الوثائق والمواعيد | `DocumentsTool` | `DocumentsTool` | التنقل | التنقل |
| productivity | `notes` | المفكرة | `NotesTool` | `NotesTool` | التنقل | التنقل |
| productivity | `tasks` | المهام | `TasksTool` | `TasksTool` | التنقل | التنقل |
| productivity | `calendar` | التقويم | `CalendarTool` | `CalendarTool` | التنقل | التنقل |
| productivity | `reminders` | التذكيرات | `RemindersTool` | `RemindersTool` | التنقل | التنقل |
| productivity | `budget` | الميزانية الشخصية | `BudgetTool` | `BudgetTool` | التنقل | التنقل |
| productivity | `expenses` | إدارة المصروفات | `ExpensesTool` | `ExpensesTool` | التنقل | التنقل |
| docs | `cv` | السيرة الذاتية | `CvTool` | `CvTool` | التنقل | التنقل |
| docs | `invoice` | إنشاء الفواتير | `InvoiceTool` | `InvoiceTool` | التنقل | التنقل |
| docs | `quote` | عروض الأسعار | `QuoteTool` | `QuoteTool` | التنقل | التنقل |
| docs | `letter` | التقارير والخطابات | `LetterTool` | `LetterTool` | التنقل | التنقل |
| docs | `sign_pdf` | توقيع المستندات | `SignPdfTool` | `SignPdfTool` | التنقل | التنقل |
| docs | `text_pdf` | إنشاء PDF | `TextPdfTool` | `TextPdfTool` | التنقل | التنقل |
| calc | `scientific` | الحاسبة العلمية | `ScientificCalc` | `ScientificCalc` | التنقل | التنقل |
| calc | `units` | محول الوحدات | `UnitsTool` | `UnitsTool` | `unitsConvert` | `testUnits` |
| calc | `currency` | محول العملات | `CurrencyTool` | `CurrencyTool` | `currencyWorksOfflineWithPeggedRate` | `testCurrencyOfflinePeggedRate` |
| calc | `area_volume` | المساحات والأحجام | `AreaVolume` | `AreaVolume` | التنقل | التنقل |
| smart | `qr_make` | إنشاء رمز QR | `QrMake` | `QrMake` | `qrMakes` | `testQrMake` |
| smart | `qr_read` | قراءة QR والباركود | `QrRead` | `QrRead` | التنقل | التنقل |
| smart | `text_compare` | مقارنة النصوص | `TextCompare` | `TextCompare` | التنقل | التنقل |
| smart | `word_count` | عداد الكلمات والحروف | `WordCount` | `WordCount` | `wordCountCounts` | `testWordCount` |
| smart | `dedupe` | إزالة التكرار | `Dedupe` | `Dedupe` | `dedupeRemoves` | التنقل |
| smart | `tts` | تحويل النص إلى صوت | `TtsTool` | `TtsTool` | التنقل | التنقل |
| smart | `stt` | تحويل الصوت إلى نص | `SttTool` | `SttTool` | التنقل | التنقل |

الأدوات: 74 — غير مربوطة بمكون: 0 

«التنقل» = الاختبار `everyCategoryShowsItsToolsAndEveryToolOpens` / `testEveryCategoryShowsItsToolsAndEveryToolOpens` الذي يفتح الأداة من تصنيفها ويتحقق من ظهور شاشتها ومن زر الرجوع، إضافة إلى اختبارات المحركات.
