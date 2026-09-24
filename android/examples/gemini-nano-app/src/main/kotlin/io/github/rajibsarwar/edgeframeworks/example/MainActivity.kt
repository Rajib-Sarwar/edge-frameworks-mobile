package io.github.rajibsarwar.edgeframeworks.example

import android.app.Activity
import android.os.Bundle
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import io.github.rajibsarwar.edgeframeworks.EdgeAgent
import io.github.rajibsarwar.edgeframeworks.EdgeGenerationEvent
import io.github.rajibsarwar.edgeframeworks.EdgeGenerationRequest
import io.github.rajibsarwar.edgeframeworks.EdgeProviderRouter
import io.github.rajibsarwar.edgeframeworks.gemininano.GeminiNanoProvider
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

class MainActivity : Activity() {
    private val scope = MainScope()
    private val provider = GeminiNanoProvider()
    private val agent = EdgeAgent(
        EdgeProviderRouter(listOf(provider))
    )

    private lateinit var statusView: TextView
    private lateinit var promptView: EditText
    private lateinit var outputView: TextView
    private lateinit var runButton: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(buildContentView())
        refreshAvailability()
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    private fun buildContentView(): ScrollView {
        val padding = (20 * resources.displayMetrics.density).toInt()

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(padding, padding, padding, padding)
        }

        val title = TextView(this).apply {
            text = "Edge Frameworks · Gemini Nano"
            textSize = 22f
        }

        statusView = TextView(this).apply {
            text = "Checking on-device model…"
        }

        promptView = EditText(this).apply {
            hint = "Ask something"
            setText("Explain on-device AI in three short bullets.")
            minLines = 3
        }

        runButton = Button(this).apply {
            text = "Run on device"
            setOnClickListener { generate() }
        }

        outputView = TextView(this).apply {
            text = "Response will appear here."
            textSize = 16f
            setPadding(0, padding, 0, 0)
        }

        content.addView(title)
        content.addView(statusView)
        content.addView(
            promptView,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        )
        content.addView(runButton)
        content.addView(outputView)

        return ScrollView(this).apply {
            addView(content)
        }
    }

    private fun refreshAvailability() {
        scope.launch {
            val capabilities = provider.capabilities()

            statusView.text = if (capabilities.isEmpty()) {
                "Gemini Nano is not ready on this device."
            } else {
                "Gemini Nano is ready · running locally."
            }

            runButton.isEnabled = capabilities.isNotEmpty()
        }
    }

    private fun generate() {
        val prompt = promptView.text.toString().trim()
        if (prompt.isEmpty()) return

        runButton.isEnabled = false
        outputView.text = ""

        scope.launch {
            try {
                agent.stream(
                    EdgeGenerationRequest(
                        prompt = prompt,
                        systemPrompt = "Answer clearly and concisely."
                    )
                ).collect { event ->
                    when (event) {
                        EdgeGenerationEvent.Started -> {
                            statusView.text = "Generating on device…"
                        }

                        is EdgeGenerationEvent.Token -> {
                            outputView.append(event.value)
                        }

                        is EdgeGenerationEvent.Completed -> {
                            statusView.text = "Completed locally."
                        }
                    }
                }
            } catch (error: Exception) {
                statusView.text = "Generation failed."
                outputView.text = error.message ?: error::class.java.simpleName
            } finally {
                runButton.isEnabled = true
            }
        }
    }
}
