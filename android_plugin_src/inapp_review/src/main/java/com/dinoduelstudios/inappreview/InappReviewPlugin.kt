package com.dinoduelstudios.inappreview

import android.util.Log
import com.google.android.play.core.review.ReviewManager
import com.google.android.play.core.review.ReviewManagerFactory
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

/**
 * Google Play's in-app review for Godot 4: asks Play for its rating card. Play decides whether the
 * card actually shows (it limits how often) and never says whether the player rated, so the game
 * just carries on when `review_finished` comes (or `review_failed`).
 */
class InappReviewPlugin(godot: Godot) : GodotPlugin(godot) {

	companion object {
		private const val TAG = "InappReviewPlugin"
	}

	private val manager: ReviewManager by lazy { ReviewManagerFactory.create(activity!!.applicationContext) }

	override fun getPluginName(): String = "InappReviewPlugin"

	override fun getPluginSignals(): MutableSet<SignalInfo> = mutableSetOf(
		SignalInfo("review_finished"),
		SignalInfo("review_failed", String::class.java)
	)

	@UsedByGodot
	fun requestReview() {
		runOnUiThread {
			val act = activity
			if (act == null) {
				emitSignal("review_failed", "no_activity")
				return@runOnUiThread
			}
			manager.requestReviewFlow().addOnCompleteListener { request ->
				if (!request.isSuccessful) {
					Log.w(TAG, "requestReviewFlow failed", request.exception)
					emitSignal("review_failed", request.exception?.message ?: "request_failed")
					return@addOnCompleteListener
				}
				manager.launchReviewFlow(act, request.result).addOnCompleteListener {
					emitSignal("review_finished")
				}
			}
		}
	}
}
