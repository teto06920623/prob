lib/
├── core/
│   ├── math/
│   │   ├── normal_dist.dart       # لحساب قيم Z و Phi(z) والمساحة تحت المنحنى
│   │   ├── student_t_dist.dart    # جداول ومعادلات توزيع T
│   │   └── chi_square_dist.dart   # جداول ومعادلات توزيع Chi-Square
│   └── models/
│       └── ci_result.dart         # كلاس موحد للنتائج (LCL, UCL, Critical Values, Curve Points)
├── features/
│   ├── mean_ci/                   # شاشة ومنطق حساب فترة الثقة للمتوسط (Z & T)
│   ├── variance_ci/               # شاشة ومنطق حساب التباين والانحراف المعياري (Chi-Square)
│   ├── proportion_ci/             # شاشة ومنطق حساب النسبة (Proportion)
│   ├── hypothesis_test/           # (إضافة اختيارية من محاضرة 6) لاختبار الفروض
│   └── chart_visualizer/          # Widget مخصص لرسم المنحنيات وتظليل مناطق القبول والرفض
└── main.dart