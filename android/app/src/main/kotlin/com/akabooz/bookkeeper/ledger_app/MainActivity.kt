package com.akabooz.bookkeeper.ledger_app

import android.app.Dialog
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.text.InputType
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.view.Window
import android.view.WindowManager
import android.view.ViewTreeObserver
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.view.setPadding
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val noteEditorChannel = "ledger_app/native_note_editor"
    private val shareImageChannelName = "ledger_app/share_image"
    private val windowChannelName = "ledger_app/window"
    private var shareImageChannel: MethodChannel? = null
    private var pendingSharedImagePath: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        consumeIncomingIntent(intent, notifyFlutter = false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            noteEditorChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "editNote" -> {
                    val initialText = call.argument<String>("text").orEmpty()
                    showNativeNoteEditor(initialText, result)
                }

                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            windowChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSoftInputAdjustNothing" -> {
                    setSoftInputAdjustMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING)
                    result.success(null)
                }

                "setSoftInputAdjustResize" -> {
                    setSoftInputAdjustMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
        shareImageChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            shareImageChannelName,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialSharedImage" -> {
                        result.success(pendingSharedImagePath)
                        pendingSharedImagePath = null
                    }

                    else -> result.notImplemented()
                }
            }
        }
        consumeIncomingIntent(intent, notifyFlutter = false)
    }

    private fun setSoftInputAdjustMode(adjustMode: Int) {
        val currentMode = window.attributes.softInputMode
        val preservedFlags =
            currentMode and WindowManager.LayoutParams.SOFT_INPUT_MASK_STATE
        window.setSoftInputMode(preservedFlags or adjustMode)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeIncomingIntent(intent, notifyFlutter = true)
    }

    private fun consumeIncomingIntent(intent: Intent?, notifyFlutter: Boolean) {
        if (intent == null) return
        val path = when (intent.action) {
            Intent.ACTION_SEND -> {
                val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, android.net.Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM) as? android.net.Uri
                }
                val type = intent.type.orEmpty()
                if (!type.startsWith("image/")) {
                    null
                } else {
                    LedgerImageStore.copyUriToCache(
                        context = this,
                        uri = uri,
                        filePrefix = "shared_ledger",
                    )
                }
            }

            Intent.ACTION_SEND_MULTIPLE -> {
                val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableArrayListExtra(
                        Intent.EXTRA_STREAM,
                        android.net.Uri::class.java,
                    )?.firstOrNull()
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableArrayListExtra<android.net.Uri>(Intent.EXTRA_STREAM)?.firstOrNull()
                }
                val type = intent.type.orEmpty()
                if (!type.startsWith("image/")) {
                    null
                } else {
                    LedgerImageStore.copyUriToCache(
                        context = this,
                        uri = uri,
                        filePrefix = "shared_ledger",
                    )
                }
            }
            else -> null
        } ?: return
        pendingSharedImagePath = path
        if (notifyFlutter) {
            shareImageChannel?.invokeMethod("onSharedImage", path)
            pendingSharedImagePath = null
        }
    }

    private fun showNativeNoteEditor(
        initialText: String,
        result: MethodChannel.Result,
    ) {
        val dialog = Dialog(this)
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE)
        var resolved = false
        var cancelPressed = false
        var keyboardWasVisible = false
        var layoutListener: ViewTreeObserver.OnGlobalLayoutListener? = null

        fun resolveOnce(value: String?) {
            if (resolved) return
            resolved = true
            result.success(value)
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadii = floatArrayOf(
                    dp(24).toFloat(), dp(24).toFloat(),
                    dp(24).toFloat(), dp(24).toFloat(),
                    0f, 0f,
                    0f, 0f,
                )
                setColor(Color.parseColor("#F8FAF6"))
            }
            setPadding(dp(16))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            alpha = 0f
            translationY = 0f
        }

        val title = TextView(this).apply {
            text = "编辑备注"
            setTextColor(Color.parseColor("#1D1D1F"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }
        root.addView(
            title,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )

        val input = EditText(this).apply {
            setText(initialText)
            setSelection(text.length)
            minLines = 3
            maxLines = 3
            gravity = Gravity.TOP or Gravity.START
            inputType = InputType.TYPE_CLASS_TEXT or
                InputType.TYPE_TEXT_FLAG_MULTI_LINE or
                InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(18).toFloat()
                setColor(Color.WHITE)
                setStroke(dp(1), Color.parseColor("#DDE5E0"))
            }
            setPadding(dp(14))
        }
        val inputParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply {
            topMargin = dp(14)
        }
        root.addView(input, inputParams)

        val buttonRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
        }
        val buttonRowParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply {
            topMargin = dp(18)
        }

        val cancelButton = buildActionButton(
            text = "取消",
            backgroundColor = Color.WHITE,
            foreground = Color.parseColor("#1D1D1F"),
        ) {
            cancelPressed = true
            resolveOnce(null)
            dialog.dismiss()
        }
        val confirmButton = buildActionButton(
            text = "确定",
            backgroundColor = Color.parseColor("#069B9B"),
            foreground = Color.WHITE,
        ) {
            resolveOnce(input.text.toString())
            dialog.dismiss()
        }

        buttonRow.addView(
            cancelButton,
            LinearLayout.LayoutParams(0, dp(48), 1f).apply {
                marginEnd = dp(6)
            },
        )
        buttonRow.addView(
            confirmButton,
            LinearLayout.LayoutParams(0, dp(48), 1f).apply {
                marginStart = dp(6)
            },
        )
        root.addView(buttonRow, buttonRowParams)

        dialog.setContentView(root)
        dialog.setCancelable(true)
        dialog.setCanceledOnTouchOutside(true)
        dialog.window?.apply {
            setLayout(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            setGravity(Gravity.BOTTOM)
            val attributes = attributes
            attributes.dimAmount = 0f
            attributes.width = WindowManager.LayoutParams.MATCH_PARENT
            attributes.height = WindowManager.LayoutParams.WRAP_CONTENT
            attributes.windowAnimations = 0
            this.attributes = attributes
            setSoftInputMode(
                WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE or
                    WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE,
            )
            setBackgroundDrawableResource(android.R.color.transparent)
        }
        dialog.setOnCancelListener {
            resolveOnce(input.text.toString())
        }
        dialog.setOnDismissListener {
            layoutListener?.let { listener ->
                dialog.window?.decorView?.viewTreeObserver?.removeOnGlobalLayoutListener(listener)
            }
            if (!cancelPressed) {
                resolveOnce(input.text.toString())
            } else {
                resolveOnce(null)
            }
        }
        dialog.setOnShowListener {
            dialog.window?.let { window ->
                val animatedAttrs = window.attributes
                animatedAttrs.dimAmount = 0.5f
                window.attributes = animatedAttrs
            }
            root.post {
                val startOffset =
                    ((dialog.window?.decorView?.height ?: root.height) + dp(24)).toFloat()
                root.translationY = startOffset
                root.alpha = 1f
                input.requestFocus()
                input.requestFocusFromTouch()
                val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                imm?.showSoftInput(input, InputMethodManager.SHOW_IMPLICIT)
                input.postDelayed({
                    imm?.showSoftInput(input, InputMethodManager.SHOW_IMPLICIT)
                }, 32)
                val decorView = dialog.window?.decorView
                layoutListener = ViewTreeObserver.OnGlobalLayoutListener {
                    val view = decorView ?: return@OnGlobalLayoutListener
                    val visibleFrame = Rect()
                    view.getWindowVisibleDisplayFrame(visibleFrame)
                    val height = view.rootView.height
                    val hiddenHeight = height - visibleFrame.bottom
                    val keyboardVisible = hiddenHeight > height * 0.15f
                    if (keyboardVisible) {
                        keyboardWasVisible = true
                    } else if (keyboardWasVisible && dialog.isShowing && !resolved) {
                        resolveOnce(input.text.toString())
                        dialog.dismiss()
                    }
                }
                decorView?.viewTreeObserver?.addOnGlobalLayoutListener(layoutListener)
                root.postDelayed({
                    if (!dialog.isShowing) return@postDelayed
                    root.animate()
                        .alpha(1f)
                        .translationY(0f)
                        .setDuration(180)
                        .start()
                }, 210)
            }
        }
        dialog.show()
    }

    private fun buildActionButton(
        text: String,
        backgroundColor: Int,
        foreground: Int,
        onClick: () -> Unit,
    ): TextView {
        return TextView(this).apply {
            this.text = text
            gravity = Gravity.CENTER
            setTextColor(foreground)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(18).toFloat()
                setColor(backgroundColor)
            }
            setOnClickListener { onClick() }
        }
    }

    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics,
        ).toInt()
    }
}
