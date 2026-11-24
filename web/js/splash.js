document.addEventListener("DOMContentLoaded", async () => {
  const svgContainer = document.getElementById("splash-svg-container");
  
  try {
    // 1. جلب ملف الـ SVG من مجلد الأصول
    const response = await fetch('assets/svg/logo.svg');
    const svgText = await response.text();
    
    // 2. حقن الـ SVG داخل الـ HTML
    svgContainer.innerHTML = svgText;

    // 3. إعداد أنيميشن الكتابة
    const path = document.querySelector("#splash-path");
    if (path) {
      const length = path.getTotalLength();

      // إعدادات البداية
      path.style.strokeDasharray = length;
      path.style.strokeDashoffset = length;

      // تشغيل الأنيميشن بعد 2.2 ثانية (بعد اكتمال نزول الأفاتارات)
      setTimeout(() => {
        path.animate(
          [
            { strokeDashoffset: length },
            { strokeDashoffset: 0 }
          ],
          {
            duration: 5000, // 5 ثوانٍ للكتابة (أبطأ وأكثر احترافية)
            easing: "ease-in-out",
            fill: "forwards"
          }
        );
      }, 2200);
    }
  } catch (error) {
    console.error("خطأ في تحميل ملف الـ SVG:", error);
  }
});