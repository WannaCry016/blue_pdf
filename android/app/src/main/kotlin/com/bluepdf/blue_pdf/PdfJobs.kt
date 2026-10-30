package com.bluepdf.blue_pdf

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Progress and cancellation for long operations. Dart tags a call with a `jobId`;
 * progress is streamed on `com.bluepdf.channel/progress` and [cancel] flips the
 * job's flag, which native code checks after every page and every buffer written.
 */
class PdfJobs(messenger: BinaryMessenger) : EventChannel.StreamHandler {

    inner class Job(private val id: Int) {
        val cancelled = AtomicBoolean(false)
        private var lastStage = -1
        private var lastSentAt = 0L

        /** Native code reports every page; Dart only needs a frame's worth of updates. */
        val listener = PdfProgressListener { stage, done, total, fraction ->
            val now = SystemClock.uptimeMillis()
            if (stage != lastStage || fraction >= 1f || now - lastSentAt >= MIN_INTERVAL_MS) {
                lastStage = stage
                lastSentAt = now
                send(
                    mapOf(
                        "jobId" to id,
                        "stage" to stage,
                        "done" to done,
                        "total" to total,
                        "fraction" to fraction.toDouble(),
                    ),
                )
            }
            !cancelled.get()
        }
    }

    private val channel = EventChannel(messenger, NAME)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val jobs = ConcurrentHashMap<Int, Job>()

    @Volatile
    private var sink: EventChannel.EventSink? = null

    init {
        channel.setStreamHandler(this)
    }

    fun dispose() {
        channel.setStreamHandler(null)
        sink = null
    }

    /** Call on the main thread when the request arrives, so a later cancel always finds the job. */
    fun start(jobId: Int?): Job? = jobId?.let { id -> Job(id).also { jobs[id] = it } }

    fun finish(jobId: Int?) {
        if (jobId != null) jobs.remove(jobId)
    }

    fun cancel(jobId: Int) {
        jobs[jobId]?.cancelled?.set(true)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    private fun send(event: Map<String, Any>) {
        mainHandler.post { sink?.success(event) }
    }

    private companion object {
        const val NAME = "com.bluepdf.channel/progress"
        const val MIN_INTERVAL_MS = 50L
    }
}
