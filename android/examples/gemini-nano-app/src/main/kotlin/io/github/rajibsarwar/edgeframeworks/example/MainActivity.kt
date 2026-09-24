package io.github.rajibsarwar.edgeframeworks.example

import android.app.Activity
import android.os.Build
import android.os.Bundle
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import io.github.rajibsarwar.edgeframeworks.EdgeAgent
import io.github.rajibsarwar.edgeframeworks.EdgeBenchmarkRunner
import io.github.rajibsarwar.edgeframeworks.EdgeGenerationEvent
import io.github.rajibsarwar.edgeframeworks.EdgeGenerationRequest
import io.github.rajibsarwar.edgeframeworks.EdgeProviderRouter
import io.github.rajibsarwar.edgeframeworks.gemininano.GeminiNanoProvider
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import java.util.Locale

class MainActivity : Activity() {
    private val scope = MainScope()
    private val provider = GeminiNanoProvider()
    private val agent = EdgeAgent(
        EdgeProviderRouter(listOf(provider))
    )

    private lateinit var statusView: TextView
    private lateinit var promptView: EditText
    private lateinit var outputView: TextView
    private lateinit var benchmarkView: TextView
    private lateinit var runButton: Button
    private lateinit var benchmarkButton: Button

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

        benchmarkButton = Button(this).apply {
            text = "Run benchmark"
            setOnClickListener { benchmark() }
        }

        outputView = TextView(this).apply {
            text = "Response will appear here."
            textSize = 16f
            setPadding(0, padding, 0, 0)
        }

        benchmarkView = TextView(this).apply {
            textSize = 15f
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
        content.addView(benchmarkButton)
        content.addView(outputView)
        content.addView(benchmarkView)

        return ScrollView(this).apply {
            addView(content)
        }
    }

    private fun refreshAvailability() {
        scope.launch {
            val capabilities = provider.capabilities()
            val isAvailable = capabilities.isNotEmpty()

            statusView.text = if (isAvailable) {
                "Gemini Nano is ready · running locally."
            } else {
                "Gemini Nano is not ready on this device."
            }

            runButton.isEnabled = isAvailable
            benchmarkButton.isEnabled = isAvailable
        }
    }

    private fun generate() {
        val prompt = promptView.text.toString().trim()
        if (prompt.isEmpty()) return

        setBusy(true)
        outputView.text = ""
        benchmarkView.text = ""

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
                outputView.text =
                    error.message ?: error::class.java.simpleName
            } finally {
                setBusy(false)
            }
        }
    }

    private fun benchmark() {
        val prompt = promptView.text.toString().trim()
        if (prompt.isEmpty()) return

        setBusy(true)
        benchmarkView.text = ""
        statusView.text = "Warming up model…"

        scope.launch {
            try {
                val request = EdgeGenerationRequest(
                    prompt = prompt,
                    systemPrompt = "Answer clearly and concisely."
                )

                provider.generate(request)

                statusView.text = "Running 10 benchmark iterations…"

                val summary = EdgeBenchmarkRunner().run(
                    provider = provider,
                    request = request,
                    iterations = 10
                )

                benchmarkView.text = """
                    Device: ${Build.MANUFACTURER} ${Build.MODEL}
                    OS: Android ${Build.VERSION.RELEASE}
                    Provider: ${summary.providerId}
                    Iterations: ${summary.iterations}
                    Warm-up: 1 unmeasured request

                    Average latency: ${format(summary.averageLatencyMilliseconds)} ms
                    P50 latency: ${format(summary.p50LatencyMilliseconds)} ms
                    P95 latency: ${format(summary.p95LatencyMilliseconds)} ms
                    Average memory delta: ${format(summary.averageMemoryDeltaBytes / 1_048_576.0)} MB
                """.trimIndent()

                statusView.text = "Benchmark completed."
            } catch (error: Exception) {
                statusView.text = "Benchmark failed."
                benchmarkView.text =
                    error.message ?: error::class.java.simpleName
            } finally {
                setBusy(false)
            }
        }
    }

    private fun setBusy(isBusy: Boolean) {
        runButton.isEnabled = !isBusy
        benchmarkButton.isEnabled = !isBusy
    }

    private fun format(value: Double): String {
        return String.format(Locale.US, "%.1f", value)
    }
}
