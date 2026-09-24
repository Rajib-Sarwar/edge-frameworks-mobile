package io.github.rajibsarwar.edgeframeworks.example

import android.app.Activity
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView
import io.github.rajibsarwar.edgeframeworks.EdgeAgent
import io.github.rajibsarwar.edgeframeworks.EdgeBenchmarkRunner
import io.github.rajibsarwar.edgeframeworks.EdgeGenerationEvent
import io.github.rajibsarwar.edgeframeworks.EdgeChunk
import io.github.rajibsarwar.edgeframeworks.EdgeGenerationRequest
import io.github.rajibsarwar.edgeframeworks.EdgeInMemoryVectorStore
import io.github.rajibsarwar.edgeframeworks.EdgeProviderRouter
import io.github.rajibsarwar.edgeframeworks.EdgeRetriever
import io.github.rajibsarwar.edgeframeworks.gemininano.GeminiNanoAvailability
import io.github.rajibsarwar.edgeframeworks.gemininano.GeminiNanoDownloadState
import io.github.rajibsarwar.edgeframeworks.gemininano.GeminiNanoProvider
import io.github.rajibsarwar.edgeframeworks.mediapipe.MediaPipeTextEmbeddingProvider
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
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
    private lateinit var downloadStatusView: TextView
    private lateinit var promptView: EditText
    private lateinit var outputView: TextView
    private lateinit var benchmarkView: TextView
    private lateinit var runButton: Button
    private lateinit var benchmarkButton: Button
    private lateinit var downloadButton: Button
    private lateinit var downloadProgress: ProgressBar
    private lateinit var ragQuestionView: EditText
    private lateinit var ragStatusView: TextView
    private lateinit var ragRetrievedView: TextView
    private lateinit var ragAnswerView: TextView
    private lateinit var ragButton: Button

    private var totalDownloadBytes: Long = 0
    private var generationReady = false
    private var ragReady = false
    private var embeddingProvider: MediaPipeTextEmbeddingProvider? = null
    private var ragRetriever: EdgeRetriever? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        actionBar?.hide()
        setContentView(buildContentView())
        prepareLocalRag()
        refreshAvailability()
    }

    override fun onDestroy() {
        embeddingProvider?.close()
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

        val statusLabel = TextView(this).apply {
            text = "Model status"
            textSize = 14f
        }

        statusView = TextView(this).apply {
            text = "Checking on-device model…"
            textSize = 16f
            setPadding(0, padding / 4, 0, padding / 2)
        }

        downloadProgress = ProgressBar(
            this,
            null,
            android.R.attr.progressBarStyleHorizontal
        ).apply {
            max = 100
            progress = 0
            visibility = View.GONE
        }

        downloadStatusView = TextView(this).apply {
            visibility = View.GONE
            setPadding(0, padding / 4, 0, padding / 2)
        }

        downloadButton = Button(this).apply {
            text = "Download model"
            visibility = View.GONE
            setOnClickListener { downloadModel() }
        }

        promptView = EditText(this).apply {
            hint = "Ask something"
            setText("Explain on-device AI in three short bullets.")
            minLines = 3
        }

        runButton = Button(this).apply {
            text = "Run on device"
            isEnabled = false
            setOnClickListener { generate() }
        }

        benchmarkButton = Button(this).apply {
            text = "Run benchmark"
            isEnabled = false
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

        val ragLabel = TextView(this).apply {
            text = "Local RAG"
            textSize = 18f
            setPadding(0, padding, 0, padding / 4)
        }

        ragStatusView = TextView(this).apply {
            text = "Preparing on-device embeddings…"
            textSize = 15f
        }

        ragQuestionView = EditText(this).apply {
            hint = "Ask local knowledge"
            setText("When does my Tokyo flight leave?")
            minLines = 2
        }

        ragButton = Button(this).apply {
            text = "Ask local knowledge"
            isEnabled = false
            setOnClickListener { runLocalRag() }
        }

        ragRetrievedView = TextView(this).apply {
            textSize = 14f
            setPadding(0, padding / 2, 0, 0)
        }

        ragAnswerView = TextView(this).apply {
            textSize = 16f
            setPadding(0, padding / 2, 0, 0)
        }

        content.addView(title)
        content.addView(statusLabel)
        content.addView(statusView)
        content.addView(downloadProgress)
        content.addView(downloadStatusView)
        content.addView(downloadButton)
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
        content.addView(ragLabel)
        content.addView(ragStatusView)
        content.addView(
            ragQuestionView,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        )
        content.addView(ragButton)
        content.addView(ragRetrievedView)
        content.addView(ragAnswerView)

        return ScrollView(this).apply {
            clipToPadding = false
            addView(content)
            setOnApplyWindowInsetsListener { view, insets ->
                view.setPadding(
                    0,
                    insets.systemWindowInsetTop,
                    0,
                    insets.systemWindowInsetBottom
                )
                insets
            }
        }
    }

    private fun refreshAvailability() {
        scope.launch {
            when (provider.availability()) {
                GeminiNanoAvailability.AVAILABLE -> showReady()

                GeminiNanoAvailability.DOWNLOADABLE -> {
                    statusView.text =
                        "Gemini Nano: DOWNLOADABLE · model is not installed yet."
                    downloadButton.visibility = View.VISIBLE
                    downloadButton.isEnabled = true
                    downloadProgress.visibility = View.GONE
                    downloadStatusView.visibility = View.GONE
                    runButton.isEnabled = false
                    benchmarkButton.isEnabled = false
                }

                GeminiNanoAvailability.DOWNLOADING -> {
                    statusView.text =
                        "Gemini Nano: DOWNLOADING · preparing the on-device model."
                    downloadButton.visibility = View.GONE
                    downloadProgress.visibility = View.VISIBLE
                    downloadStatusView.visibility = View.VISIBLE
                    downloadStatusView.text = "Download already in progress…"
                    runButton.isEnabled = false
                    benchmarkButton.isEnabled = false
                    waitUntilDownloadFinishes()
                }

                GeminiNanoAvailability.UNAVAILABLE -> {
                    generationReady = false
                    statusView.text =
                        "Gemini Nano: UNAVAILABLE · ML Kit reports the Prompt API is not available on this device/configuration."
                    downloadButton.visibility = View.GONE
                    downloadProgress.visibility = View.GONE
                    downloadStatusView.visibility = View.VISIBLE
                    downloadStatusView.text =
                        "Local generation and benchmarking are disabled."
                    runButton.isEnabled = false
                    benchmarkButton.isEnabled = false
                }
            }
        }
    }

    private fun downloadModel() {
        downloadButton.isEnabled = false
        downloadButton.visibility = View.GONE
        downloadProgress.visibility = View.VISIBLE
        downloadStatusView.visibility = View.VISIBLE
        downloadStatusView.text = "Starting model download…"
        statusView.text = "Gemini Nano: DOWNLOADING"

        scope.launch {
            try {
                provider.download().collect { state ->
                    when (state) {
                        is GeminiNanoDownloadState.Started -> {
                            totalDownloadBytes = state.bytesToDownload
                            downloadProgress.progress = 0
                            downloadStatusView.text =
                                "Download started · ${formatBytes(state.bytesToDownload)} total"
                        }

                        is GeminiNanoDownloadState.Progress -> {
                            val percent = if (totalDownloadBytes > 0) {
                                (
                                    state.totalBytesDownloaded * 100 /
                                        totalDownloadBytes
                                    ).toInt().coerceIn(0, 100)
                            } else {
                                0
                            }

                            downloadProgress.progress = percent
                            downloadStatusView.text =
                                "Downloaded ${formatBytes(state.totalBytesDownloaded)} · ${percent}%"
                        }

                        GeminiNanoDownloadState.Completed -> {
                            downloadStatusView.text = "Download complete."
                            showReady()
                        }

                        is GeminiNanoDownloadState.Failed -> {
                            statusView.text = "Gemini Nano download failed."
                            downloadStatusView.text = state.message
                            downloadProgress.visibility = View.GONE
                            downloadButton.visibility = View.VISIBLE
                            downloadButton.isEnabled = true
                        }
                    }
                }
            } catch (error: Exception) {
                statusView.text = "Gemini Nano download failed."
                downloadStatusView.text =
                    error.message ?: error::class.java.simpleName
                downloadProgress.visibility = View.GONE
                downloadButton.visibility = View.VISIBLE
                downloadButton.isEnabled = true
            }
        }
    }

    private suspend fun waitUntilDownloadFinishes() {
        while (true) {
            delay(2_000)

            when (provider.availability()) {
                GeminiNanoAvailability.AVAILABLE -> {
                    showReady()
                    return
                }

                GeminiNanoAvailability.DOWNLOADING -> Unit

                GeminiNanoAvailability.DOWNLOADABLE -> {
                    downloadProgress.visibility = View.GONE
                    downloadButton.visibility = View.VISIBLE
                    downloadButton.isEnabled = true
                    downloadStatusView.text =
                        "Download paused or not started. Tap Download model."
                    return
                }

                GeminiNanoAvailability.UNAVAILABLE -> {
                    downloadProgress.visibility = View.GONE
                    downloadStatusView.text =
                        "Prompt API became unavailable on this device."
                    return
                }
            }
        }
    }

    private fun showReady() {
        generationReady = true
        statusView.text =
            "Gemini Nano: AVAILABLE · ready for local generation."
        downloadProgress.progress = 100
        downloadProgress.visibility = View.GONE
        downloadStatusView.visibility = View.GONE
        downloadButton.visibility = View.GONE
        setBusy(false)
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

    private fun prepareLocalRag() {
        scope.launch {
            try {
                val embedder = MediaPipeTextEmbeddingProvider(this@MainActivity)
                val retriever = EdgeRetriever(
                    embeddingProvider = embedder,
                    vectorStore = EdgeInMemoryVectorStore()
                )

                retriever.index(demoChunks)

                embeddingProvider = embedder
                ragRetriever = retriever
                ragReady = true
                ragStatusView.text =
                    "Indexed ${demoChunks.size} chunks locally with MediaPipe Text Embedder."
                setBusy(false)
            } catch (error: Exception) {
                ragReady = false
                ragStatusView.text =
                    "Local embeddings failed: ${error.message ?: error::class.java.simpleName}"
                setBusy(false)
            }
        }
    }

    private fun runLocalRag() {
        val question = ragQuestionView.text.toString().trim()
        val retriever = ragRetriever ?: return

        if (question.isEmpty() || !generationReady) return

        setBusy(true)
        ragRetrievedView.text = ""
        ragAnswerView.text = ""
        ragStatusView.text = "Retrieving relevant chunks locally…"

        scope.launch {
            try {
                val results = retriever.retrieve(
                    query = question,
                    topK = 3
                )

                ragRetrievedView.text = results
                    .mapIndexed { index, result ->
                        val score = String.format(
                            Locale.US,
                            "%.3f",
                            result.score
                        )
                        "${index + 1}. [$score] ${result.chunk.text}"
                    }
                    .joinToString("\n\n")

                val context = results
                    .joinToString("\n") { it.chunk.text }

                ragStatusView.text =
                    "Generating answer with Gemini Nano from retrieved context…"

                val response = provider.generate(
                    EdgeGenerationRequest(
                        prompt = """
                            Local context:
                            $context

                            Question:
                            $question
                        """.trimIndent(),
                        systemPrompt = """
                            Answer using only the supplied local context.
                            If the answer is not present, say the local knowledge
                            does not contain enough information.
                        """.trimIndent()
                    )
                )

                ragAnswerView.text = response.text
                ragStatusView.text =
                    "RAG completed locally · embeddings + retrieval + generation stayed on device."
            } catch (error: Exception) {
                ragStatusView.text = "Local RAG failed."
                ragAnswerView.text =
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
        runButton.isEnabled = generationReady && !isBusy
        benchmarkButton.isEnabled = generationReady && !isBusy
        ragButton.isEnabled = generationReady && ragReady && !isBusy
    }

    private val demoChunks = listOf(
        EdgeChunk(
            id = "travel-flight",
            documentId = "travel-notes",
            text = "Our flight to Tokyo leaves Newark on October 12 at 9:30 AM."
        ),
        EdgeChunk(
            id = "travel-hotel",
            documentId = "travel-notes",
            text = "We are staying at the Shinagawa Prince Hotel in Tokyo for four nights."
        ),
        EdgeChunk(
            id = "travel-train",
            documentId = "travel-notes",
            text = "The airport train reservation is for the Narita Express after landing."
        ),
        EdgeChunk(
            id = "insurance",
            documentId = "personal-notes",
            text = "The new insurance coverage begins on November 1."
        ),
        EdgeChunk(
            id = "dinner",
            documentId = "personal-notes",
            text = "Friday dinner is reserved at an Italian restaurant at 7:00 PM."
        )
    )

    private fun format(value: Double): String {
        return String.format(Locale.US, "%.1f", value)
    }

    private fun formatBytes(bytes: Long): String {
        val megabytes = bytes / 1_048_576.0
        return String.format(Locale.US, "%.1f MB", megabytes)
    }
}
