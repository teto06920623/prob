{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();

    // إخفاء الشاشة بسلاسة بعد أن يكون فلاتر جاهزاً
    const splash = document.getElementById('splash-screen');
    if (splash) {
      splash.classList.add('fade-out');
      setTimeout(() => {
        splash.remove();
      }, 600); // يتوافق مع مدة الـ transition في الـ CSS
    }
  }
});