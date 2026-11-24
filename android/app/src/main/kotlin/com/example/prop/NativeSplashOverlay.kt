package com.example.prop

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.AnimatorSet
import android.animation.Keyframe
import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Outline
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PathMeasure
import android.graphics.RectF
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.LinearLayout
import kotlin.math.min

class NativeSplashOverlay(
    context: Context,
    private val svgPathsData: List<String>,
    private val onAnimationComplete: () -> Unit
) : FrameLayout(context) {

    private val density = resources.displayMetrics.density
    private val screenWidth = resources.displayMetrics.widthPixels
    private val activeAnimators = mutableListOf<Animator>()
    private val loadedBitmaps = mutableListOf<Bitmap>()

    private data class AvatarLayerSpec(
        val drawableResId: Int,
        val leftPercent: Float,
        val targetScale: Float,
        val delayMs: Long,
        val elevationDp: Float
    )

    init {
        setBackgroundColor(Color.parseColor("#111111"))
        elevation = 100f * density
        isClickable = true
        isFocusable = true

        val rootColumn = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        }

        // 1. حاوية الأفاتارات الخمسة المتراكبة
        val containerWidth = min((480f * density).toInt(), (screenWidth * 0.92f).toInt())
        val scaleFactor = containerWidth / (480f * density)
        val avatarSizePx = (100f * density * scaleFactor).toInt()
        val containerHeight = (150f * density * scaleFactor).toInt()

        val avatarsContainer = FrameLayout(context).apply {
            clipChildren = false
            clipToPadding = false
            layoutParams = LinearLayout.LayoutParams(containerWidth, containerHeight).apply {
                bottomMargin = (25f * density).toInt()
            }
        }

        // ترتيب الإضافة للتحكم في العمق (Z-Index): الخلفية (1, 5) ثم الوسطى (2, 4) وأخيراً الأمامية (3)
        val orderedLayers = listOf(
            AvatarLayerSpec(R.drawable.avatar_1, 0.15f, 0.85f, 150L, 6f),
            AvatarLayerSpec(R.drawable.avatar_5, 0.85f, 0.85f, 150L, 6f),
            AvatarLayerSpec(R.drawable.avatar_2, 0.32f, 0.95f, 350L, 11f),
            AvatarLayerSpec(R.drawable.avatar_4, 0.68f, 0.95f, 350L, 11f),
            AvatarLayerSpec(R.drawable.avatar_3, 0.50f, 1.15f, 550L, 16f)
        )

        orderedLayers.forEach { spec ->
            val bitmap = decodeSampledBitmap(spec.drawableResId, 256, 256)
            if (bitmap != null) loadedBitmaps.add(bitmap)

            val avatarView = AvatarBadgeView(context, bitmap, 4f * density).apply {
                val centerX = (containerWidth * spec.leftPercent) - (avatarSizePx / 2f)
                val centerY = (containerHeight - avatarSizePx) / 2f
                layoutParams = LayoutParams(avatarSizePx, avatarSizePx).apply {
                    leftMargin = centerX.toInt()
                    topMargin = centerY.toInt()
                }
                elevation = spec.elevationDp * density

                // الحالة الابتدائية قبل السقوط
                alpha = 0f
                translationY = -220f * density
                scaleX = 0.6f
                scaleY = 0.6f
            }

            avatarsContainer.addView(avatarView)
            scheduleAvatarDrop(avatarView, spec)
        }

        rootColumn.addView(avatarsContainer)

        // 2. حاوية الرسم اليدوي للنص (SVG Path Stroke)
        val strokeView = StrokeLogoView(context, svgPathsData).apply {
            val targetWidth = min((420f * density).toInt(), (screenWidth * 0.82f).toInt())
            val targetHeight = (110f * density).toInt()
            layoutParams = LinearLayout.LayoutParams(targetWidth, targetHeight)
        }
        rootColumn.addView(strokeView)

        addView(rootColumn)

        // 3. تشغيل أنيميشن الكتابة المرسومة فور استقرار الأفاتار الرئيسي
        val strokeAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            startDelay = 1200L
            duration = 2600L
            interpolator = AccelerateDecelerateInterpolator()
            addUpdateListener { anim ->
                strokeView.setProgress(anim.animatedValue as Float)
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    postDelayed({ onAnimationComplete() }, 750L)
                }
            })
        }
        activeAnimators.add(strokeAnimator)
        strokeAnimator.start()
    }

    private fun scheduleAvatarDrop(view: View, spec: AvatarLayerSpec) {
        val dropHeight = -220f * density

        val transYHolder = PropertyValuesHolder.ofKeyframe(
            View.TRANSLATION_Y,
            Keyframe.ofFloat(0.00f, dropHeight),
            Keyframe.ofFloat(0.55f, 0f),              // لحظة الاصطدام
            Keyframe.ofFloat(0.75f, -22f * density),  // ارتداد أول
            Keyframe.ofFloat(0.90f, 0f),              // هبوط ثانٍ
            Keyframe.ofFloat(0.96f, -6f * density),   // ارتداد خفيف
            Keyframe.ofFloat(1.00f, 0f)               // استقرار نهائي
        )

        val alphaHolder = PropertyValuesHolder.ofKeyframe(
            View.ALPHA,
            Keyframe.ofFloat(0.00f, 0f),
            Keyframe.ofFloat(0.35f, 1f),
            Keyframe.ofFloat(1.00f, 1f)
        )

        val dropAnim = ObjectAnimator.ofPropertyValuesHolder(view, transYHolder, alphaHolder)
        val scaleXAnim = ObjectAnimator.ofFloat(view, View.SCALE_X, 0.6f, spec.targetScale)
        val scaleYAnim = ObjectAnimator.ofFloat(view, View.SCALE_Y, 0.6f, spec.targetScale)

        val set = AnimatorSet().apply {
            playTogether(dropAnim, scaleXAnim, scaleYAnim)
            startDelay = spec.delayMs
            duration = 800L
        }
        activeAnimators.add(set)
        set.start()
    }

    fun fadeOutAndDestroy(onDestroyed: () -> Unit) {
        animate()
            .alpha(0f)
            .setDuration(450L)
            .setInterpolator(DecelerateInterpolator())
            .withEndAction {
                activeAnimators.forEach { it.cancel() }
                activeAnimators.clear()
                (parent as? ViewGroup)?.removeView(this)
                loadedBitmaps.forEach { if (!it.isRecycled) it.recycle() }
                loadedBitmaps.clear()
                onDestroyed()
            }
            .start()
    }

    private fun decodeSampledBitmap(resId: Int, reqWidth: Int, reqHeight: Int): Bitmap? {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeResource(resources, resId, options)

        var inSampleSize = 1
        if (options.outHeight > reqHeight || options.outWidth > reqWidth) {
            val halfHeight = options.outHeight / 2
            val halfWidth = options.outWidth / 2
            while (halfHeight / inSampleSize >= reqHeight && halfWidth / inSampleSize >= reqWidth) {
                inSampleSize *= 2
            }
        }
        options.inJustDecodeBounds = false
        options.inSampleSize = inSampleSize
        return BitmapFactory.decodeResource(resources, resId, options)
    }

    /**
     * عنصر دائري يرسم الصورة بصيغة Center-Crop مع إطار أبيض وظل ساقط حقيقي
     */
    private class AvatarBadgeView(
        context: Context,
        private val bitmap: Bitmap?,
        private val borderWidthPx: Float
    ) : View(context) {

        private val clipPath = Path()
        private val destRect = RectF()
        private val bitmapPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#E0E0E0")
            style = Paint.Style.FILL
        }
        private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.STROKE
            strokeWidth = borderWidthPx
        }

        init {
            outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(view: View, outline: Outline) {
                    outline.setOval(0, 0, view.width, view.height)
                }
            }
            clipToOutline = true
        }

        override fun onDraw(canvas: Canvas) {
            val cx = width / 2f
            val cy = height / 2f
            val radius = min(cx, cy)

            clipPath.reset()
            clipPath.addCircle(cx, cy, radius, Path.Direction.CW)

            canvas.save()
            canvas.clipPath(clipPath)
            canvas.drawCircle(cx, cy, radius, bgPaint)

            bitmap?.let { bmp ->
                val scale = maxOf(width.toFloat() / bmp.width, height.toFloat() / bmp.height)
                val scaledW = bmp.width * scale
                val scaledH = bmp.height * scale
                val left = (width - scaledW) / 2f
                val top = (height - scaledH) / 2f
                destRect.set(left, top, left + scaledW, top + scaledH)
                canvas.drawBitmap(bmp, null, destRect, bitmapPaint)
            }
            canvas.restore()

            canvas.drawCircle(cx, cy, radius - (borderWidthPx / 2f), borderPaint)
        }
    }

    /**
     * عنصر يرسم جميع المسارات الفرعية (Contours) داخل ملف الـ SVG بالترتيب
     */
    private class StrokeLogoView(
        context: Context,
        pathsData: List<String>
    ) : View(context) {

        private data class ContourItem(val measure: PathMeasure, val length: Float)

        private val rawPaths: List<Path> = pathsData.map { SvgPathParser.parse(it) }
        private val contourItems = mutableListOf<ContourItem>()
        private val animatedSegment = Path()
        private var totalLength = 0f
        private var progress = 0f

        private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#00FF88")
            style = Paint.Style.STROKE
            strokeWidth = 2.5f * resources.displayMetrics.density
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }

        fun setProgress(value: Float) {
            progress = value.coerceIn(0f, 1f)
            invalidate()
        }

        override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
            super.onSizeChanged(w, h, oldw, oldh)
            if (w == 0 || h == 0 || rawPaths.isEmpty()) return

            val totalBounds = RectF()
            val tempBounds = RectF()
            rawPaths.forEachIndexed { i, p ->
                p.computeBounds(tempBounds, true)
                if (i == 0) totalBounds.set(tempBounds) else totalBounds.union(tempBounds)
            }

            if (totalBounds.width() <= 0f || totalBounds.height() <= 0f) return

            val padding = strokePaint.strokeWidth * 2f
            val availW = w - padding * 2f
            val availH = h - padding * 2f
            val scale = min(availW / totalBounds.width(), availH / totalBounds.height())

            val matrix = Matrix().apply {
                postTranslate(-totalBounds.centerX(), -totalBounds.centerY())
                postScale(scale, scale)
                postTranslate(w / 2f, h / 2f)
            }

            contourItems.clear()
            totalLength = 0f

            rawPaths.forEach { raw ->
                val transformed = Path(raw).apply { transform(matrix) }
                val pm = PathMeasure(transformed, false)
                do {
                    val len = pm.length
                    if (len > 0f) {
                        val subPath = Path()
                        pm.getSegment(0f, len, subPath, true)
                        contourItems.add(ContourItem(PathMeasure(subPath, pm.isClosed), len))
                        totalLength += len
                    }
                } while (pm.nextContour())
            }
        }

        override fun onDraw(canvas: Canvas) {
            if (progress <= 0f || totalLength <= 0f) return

            var remaining = totalLength * progress
            for (item in contourItems) {
                if (remaining <= 0f) break
                animatedSegment.reset()
                if (remaining >= item.length) {
                    item.measure.getSegment(0f, item.length, animatedSegment, true)
                    remaining -= item.length
                } else {
                    item.measure.getSegment(0f, remaining, animatedSegment, true)
                    remaining = 0f
                }
                canvas.drawPath(animatedSegment, strokePaint)
            }
        }
    }
}