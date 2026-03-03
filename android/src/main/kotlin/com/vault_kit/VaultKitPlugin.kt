package com.vault_kit

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class VaultKitPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    companion object {
        private const val CHANNEL_NAME = "vault_kit_channel"
        private const val KEY_ALIAS = "VaultKitKey"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val PREF_NAME = "vault_kit_storage"
        private const val GCM_TAG_LENGTH = 128
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }


    // -------------------------------------------------------
    // 📡 Method Channel Handler
    // -------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "save" -> {
                val key   = call.argument<String>("key")
                val value = call.argument<String>("value")
                if (key.isNullOrEmpty() || value.isNullOrEmpty()) {
                    result.error("INVALID_ARGUMENT", "Key and value must not be null or empty", null)
                    return
                }
                try { encrypt(key, value); result.success(true) }
                catch (e: Exception) { result.error("ENCRYPT_FAILED", e.message, null) }
            }
            "fetch" -> {
                val key = call.argument<String>("key")
                if (key.isNullOrEmpty()) {
                    result.error("INVALID_ARGUMENT", "Key must not be null or empty", null)
                    return
                }
                try { result.success(decrypt(key)) }
                catch (e: Exception) { result.error("DECRYPT_FAILED", e.message, null) }
            }
            "delete" -> {
                val key = call.argument<String>("key")
                if (key.isNullOrEmpty()) {
                    result.error("INVALID_ARGUMENT", "Key must not be null or empty", null)
                    return
                }
                try { deleteEntry(key); result.success(true) }
                catch (e: Exception) { result.error("DELETE_FAILED", e.message, null) }
            }
            "clearAll" -> {
                try { clearAll(); result.success(true) }
                catch (e: Exception) { result.error("CLEAR_FAILED", e.message, null) }
            }
            "has" -> {
                val key = call.argument<String>("key")
                if (key.isNullOrEmpty()) {
                    result.error("INVALID_ARGUMENT", "Key must not be null or empty", null)
                    return
                }
                result.success(hasKey(key))
            }
            else -> result.notImplemented()
        }
    }

    // -------------------------------------------------------
    // 🔑 Key Management
    // -------------------------------------------------------

    private fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        if (keyStore.containsAlias(KEY_ALIAS)) {
            try {
                val existingKey = keyStore.getKey(KEY_ALIAS, null) as SecretKey
                Cipher.getInstance("AES/GCM/NoPadding").init(Cipher.ENCRYPT_MODE, existingKey)
                return existingKey
            } catch (e: Exception) { keyStore.deleteEntry(KEY_ALIAS) }
        }
        val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        keyGenerator.init(
            KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setUserAuthenticationRequired(false)
                .build()
        )
        return keyGenerator.generateKey()
    }

    // -------------------------------------------------------
    // 🔒 Encrypt
    // -------------------------------------------------------

    private fun encrypt(key: String, value: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        val encryptedBytes = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        getPrefs().edit()
            .putString(key, Base64.encodeToString(encryptedBytes, Base64.NO_WRAP))
            .putString("${key}_iv", Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
            .apply()
    }

    // -------------------------------------------------------
    // 🔓 Decrypt
    // -------------------------------------------------------

    private fun decrypt(key: String): String? {
        val prefs = getPrefs()
        val ciphertext = prefs.getString(key, null) ?: return null
        val iv         = prefs.getString("${key}_iv", null) ?: return null
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(),
            GCMParameterSpec(GCM_TAG_LENGTH, Base64.decode(iv, Base64.NO_WRAP)))
        return String(cipher.doFinal(Base64.decode(ciphertext, Base64.NO_WRAP)), Charsets.UTF_8)
    }

    // -------------------------------------------------------
    // 🗑 Delete single entry
    // -------------------------------------------------------

    private fun deleteEntry(key: String) =
        getPrefs().edit().remove(key).remove("${key}_iv").apply()

    // -------------------------------------------------------
    // 🧹 Clear all entries
    // -------------------------------------------------------

    private fun clearAll() =
        getPrefs().edit().clear().apply()

    // -------------------------------------------------------
    // 🛠 Helpers
    // -------------------------------------------------------

    private fun getPrefs(): SharedPreferences =
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)

    private fun hasKey(key: String): Boolean =
        getPrefs().contains(key)
}