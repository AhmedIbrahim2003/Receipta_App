package com.receipta.app

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log

class ReceiptHostApduService : HostApduService() {

    companion object {

        private const val TAG = "ReceiptHCE"

        private const val AID = "F0010203040506"

        private const val INS_GET_RECEIPT = 0x10

        private const val SW_SUCCESS_1 = 0x90.toByte()
        private const val SW_SUCCESS_2 = 0x00.toByte()

        // ISO 7816-4 "referenced data not found" - used when there is no
        // active claim code to serve (not armed yet, or already consumed).
        private const val SW_NO_DATA_1 = 0x6A.toByte()
        private const val SW_NO_DATA_2 = 0x88.toByte()

        // Set by MainActivity when Flutter calls startHce/stopHce, with the
        // `code` from POST /api/claims (the backend-issued claim token this
        // Flutter app is broadcasting - not generated on-device). Read here
        // when the ESP32 asks for the receipt. Same process as MainActivity,
        // so a simple synchronized companion field is sufficient - no IPC
        // needed.
        @Volatile
        private var activeClaimCode: String? = null

        // Set by MainActivity's EventChannel StreamHandler so a successful
        // tap can be reported back to Dart. Invoked on whatever thread
        // processCommandApdu runs on - callers are responsible for hopping
        // to the main thread before touching Flutter.
        @Volatile
        var onTapSuccess: ((String) -> Unit)? = null

        fun setActiveClaimCode(code: String?) {
            activeClaimCode = code
            Log.d(TAG, "Active claim code set to: $code")
        }
    }

    override fun processCommandApdu(
        commandApdu: ByteArray,
        extras: Bundle?
    ): ByteArray {

        Log.d(TAG, "================================")
        Log.d(TAG, "APDU RECEIVED")
        Log.d(TAG, "APDU: ${toHex(commandApdu)}")
        Log.d(TAG, "APDU length: ${commandApdu.size}")

        // =====================================================
        // SELECT AID
        // =====================================================

        if (isSelectAid(commandApdu)) {

            Log.d(TAG, "SELECT AID received")
            Log.d(TAG, "AID matched: $AID")
            Log.d(TAG, "Returning: 90 00")

            return successResponse()
        }

        // =====================================================
        // GET RECEIPT
        // =====================================================

        if (
            commandApdu.size >= 2 &&
            (commandApdu[1].toInt() and 0xFF) == INS_GET_RECEIPT
        ) {

            Log.d(TAG, "GET RECEIPT received")

            val currentCode = activeClaimCode

            if (currentCode == null) {
                Log.d(TAG, "No active claim code - rejecting (already used or not armed)")
                return byteArrayOf(SW_NO_DATA_1, SW_NO_DATA_2)
            }

            val dataBytes =
                currentCode.toByteArray(Charsets.UTF_8)

            val response =
                ByteArray(dataBytes.size + 2)

            // Copy payload
            System.arraycopy(
                dataBytes,
                0,
                response,
                0,
                dataBytes.size
            )

            // Append 90 00
            response[response.size - 2] =
                SW_SUCCESS_1

            response[response.size - 1] =
                SW_SUCCESS_2

            Log.d(TAG, "Claim code served: $currentCode")
            Log.d(TAG, "Response: ${toHex(response)}")
            Log.d(TAG, "Response length: ${response.size}")

            // One-time use: clear immediately so a replayed/second tap is
            // rejected, then notify Dart (if listening) that this code was
            // consumed. The backend independently enforces single-use too
            // (POST /receipts/{id}/assign validates status=pending) - this
            // is defense in depth, not the source of truth.
            activeClaimCode = null
            onTapSuccess?.invoke(currentCode)

            return response
        }

        // =====================================================
        // UNKNOWN APDU
        // =====================================================

        Log.d(
            TAG,
            "Unknown APDU"
        )

        Log.d(
            TAG,
            "Returning: 6D 00"
        )

        return byteArrayOf(
            0x6D.toByte(),
            0x00.toByte()
        )
    }

    override fun onDeactivated(
        reason: Int
    ) {

        Log.d(
            TAG,
            "================================"
        )

        Log.d(
            TAG,
            "NFC DEACTIVATED"
        )

        Log.d(
            TAG,
            "Reason: $reason"
        )

        Log.d(
            TAG,
            "================================"
        )
    }

    // =========================================================
    // CHECK SELECT AID
    // =========================================================

    private fun isSelectAid(
        apdu: ByteArray
    ): Boolean {

        if (apdu.size < 5) {
            return false
        }

        // CLA
        if (apdu[0] != 0x00.toByte()) {
            return false
        }

        // INS = SELECT
        if (apdu[1] != 0xA4.toByte()) {
            return false
        }

        // P1 = 04
        if (apdu[2] != 0x04.toByte()) {
            return false
        }

        // P2 = 00
        if (apdu[3] != 0x00.toByte()) {
            return false
        }

        // AID length
        val aidLength =
            apdu[4].toInt() and 0xFF

        if (aidLength <= 0) {
            return false
        }

        if (apdu.size < 5 + aidLength) {
            return false
        }

        val receivedAid =
            toHex(
                apdu.copyOfRange(
                    5,
                    5 + aidLength
                )
            ).replace(
                " ",
                ""
            )

        Log.d(
            TAG,
            "AID: $receivedAid"
        )

        return receivedAid.equals(
            AID,
            ignoreCase = true
        )
    }

    // =========================================================
    // SUCCESS RESPONSE
    // =========================================================

    private fun successResponse(): ByteArray {

        return byteArrayOf(
            0x90.toByte(),
            0x00.toByte()
        )
    }

    // =========================================================
    // HEX CONVERSION
    // =========================================================

    private fun toHex(
        data: ByteArray
    ): String {

        val builder =
            StringBuilder()

        for (i in data.indices) {

            val value =
                data[i].toInt() and 0xFF

            if (value < 0x10) {
                builder.append("0")
            }

            builder.append(
                value.toString(16)
                    .uppercase()
            )

            if (i < data.size - 1) {
                builder.append(" ")
            }
        }

        return builder.toString()
    }
}
