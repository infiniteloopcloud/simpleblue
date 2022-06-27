package cloud.infiniteloop.simpleblue.simpleblue

import android.bluetooth.*
import android.content.*
import android.os.*
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat.getSystemService

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.util.*
import kotlin.collections.ArrayList
import kotlin.concurrent.thread


const val MESSAGE_READ: Int = 0
const val MESSAGE_WRITE: Int = 1
const val MESSAGE_TOAST: Int = 2

private val TAG = "SimplebluePlugin"

/** SimplebluePlugin */
class SimplebluePlugin : FlutterPlugin,
    Handler(Looper.getMainLooper()),
    MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel

    private var eventSink: EventChannel.EventSink? = null

    lateinit var bluetoothManager: BluetoothManager
    var bluetoothAdapter: BluetoothAdapter? = null
    var serviceUUID: String? = null

    private lateinit var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding


    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        this.flutterPluginBinding = flutterPluginBinding

        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "simpleblue")
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "simpleblue/events")
        eventChannel.setStreamHandler(this)

        // Initialize Bluetooth Service
        bluetoothManager = getSystemService(
            flutterPluginBinding.applicationContext,
            BluetoothManager::class.java
        )!!
        bluetoothAdapter = bluetoothManager.adapter
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)

        binding.applicationContext.unregisterReceiver(scanningReceiver)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        Log.d(TAG, "android call received: \"${call.method}\"")

        when (call.method) {
            "getDevices" -> {
                val bondedDevices = bluetoothAdapter?.bondedDevices

                val connectedDevices = arrayListOf<BluetoothDevice>()
                for (profile in arrayOf(BluetoothProfile.GATT, BluetoothProfile.GATT_SERVER)) {
                    connectedDevices.addAll(bluetoothManager.getConnectedDevices(profile))
                }

                result.success(bondedDevices?.map { bonded ->
                    deviceToJson(bonded,
                        connectedDevices.any { connected -> connected.address == bonded.address }
                    )
                })
            }
            "scanDevices" -> {
                Log.d(TAG, call.arguments.toString())

                (call.arguments as? Map<*, *>)?.let { args ->
                    (args["serviceUUID"] as? String)?.let { uuid ->
                        serviceUUID = uuid
                    }
                }

                for (action in arrayOf(
                    BluetoothAdapter.ACTION_STATE_CHANGED,
                    BluetoothAdapter.ACTION_CONNECTION_STATE_CHANGED,
                    BluetoothAdapter.ACTION_DISCOVERY_STARTED,
                    BluetoothAdapter.ACTION_DISCOVERY_FINISHED,
                    BluetoothDevice.ACTION_ACL_CONNECTED,
                    BluetoothDevice.ACTION_BOND_STATE_CHANGED,
                    BluetoothDevice.ACTION_FOUND
                )) {

                    ContextWrapper(flutterPluginBinding.applicationContext).registerReceiver(
                        scanningReceiver,
                        IntentFilter(action)
                    )
                }

                if (bluetoothAdapter?.isDiscovering == true) {
                    bluetoothAdapter?.cancelDiscovery()
                }

                bluetoothAdapter?.cancelDiscovery()
            }
            "stopScanning" -> {
                if (bluetoothAdapter?.isDiscovering == true) {
                    bluetoothAdapter?.cancelDiscovery()
                }
            }
            "connect" -> {
                (call.arguments as? Map<*, *>)?.let { args ->
                    (args["uuid"] as? String)?.let { uuid ->
                        bluetoothAdapter?.getRemoteDevice(uuid)?.let {
                            if (connectToDevice(it)) {
                                result.success(0)
                            } else {
                                result.success(-1)
                            }
                            return
                        }
                    }
                }
                result.error("", null, null)
            }
            "disconnect" -> {
                (call.arguments as? Map<*, *>)?.let { args ->
                    (args["uuid"] as? String)?.let { uuid ->
                        connections[uuid]?.let {
                            it.cancel()
                            connections.remove(uuid)

                            eventSink?.success(
                                mapOf(
                                    "type" to "connection",
                                    "data" to mapOf(
                                        "event" to "disconnected",
                                        "device" to deviceToJson(devices[uuid]!!)
                                    )
                                )
                            )

                            result.success(0)

                            return
                        }
                    }
                }
                result.error("", null, null)
            }
            "write" -> {
                (call.arguments as? Map<*, *>)?.let { args ->
                    (args["uuid"] as? String)?.let { uuid ->
                        val data = (args["data"] as List<*>)
                            .map { it as Int }
                            .map { it.toByte() }
                            .toByteArray()

                        connections[uuid]?.write(data)
                    }
                }

                result.success(0)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun connectToDevice(device: BluetoothDevice): Boolean {
        Log.d(TAG, "Connecting to $device")

        if (bluetoothAdapter?.isDiscovering == true) {
            bluetoothAdapter?.cancelDiscovery()
        }

        val connection = ConnectThread(this, device)
        connections[device.address] = connection

        try {
            connection.run()
        } catch (exception: Exception) {
            Log.d(TAG, exception.localizedMessage ?: exception.toString())
            return false
        }

        return true
    }


    override fun handleMessage(msg: Message) {
        super.handleMessage(msg)

        when (msg.what) {
            MESSAGE_READ -> {
                val message = msg.obj as MessageObject
                val data = (message.data as ArrayList<*>)
                    .map { it as UByte }
                    .map { it.toInt() }

                eventSink?.success(
                    mapOf(
                        "type" to "data",
                        "data" to mapOf(
                            "bytes" to data,
                            "device" to deviceToJson(message.device)
                        )
                    )
                )
            }
        }
        Log.d(TAG, "$msg")
    }


    // region EventChannel.StreamHandler

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink?.endOfStream()
    }

    // endregion

    private fun deviceToJson(device: BluetoothDevice, connected: Boolean = false) = mapOf(
        "name" to device.name,
        "uuid" to device.address,
        "isConnected" to connected
    )

    private val devices = hashMapOf<String, BluetoothDevice>()
    private val connections = hashMapOf<String, ConnectThread>()

    private val scanningReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            Log.d(TAG, "onReceive $intent\nExtras: ${intent.extras?.keySet()?.joinToString { it }}")

            when (intent.action) {
                BluetoothAdapter.ACTION_DISCOVERY_STARTED -> {
                    Log.d(TAG, "Bluetooth Discovery started")

                    eventSink?.success(
                        mapOf(
                            "type" to "scanningState",
                            "data" to true
                        )
                    )
                }
                BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                    Log.d(TAG, "Bluetooth Discovery finished")

                    eventSink?.success(
                        mapOf(
                            "type" to "scanningState",
                            "data" to false
                        )
                    )
                }
                BluetoothDevice.ACTION_ACL_CONNECTED -> {
                    (intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE) as? BluetoothDevice)?.let { device ->
                        val deviceName = device.name
                        val deviceHardwareAddress = device.address

                        eventSink?.success(
                            mapOf(
                                "type" to "connection",
                                "data" to mapOf(
                                    "event" to "connected",
                                    "device" to deviceToJson(device, true)
                                )
                            )
                        )

                        Log.d(
                            TAG,
                            "Device Connected: ${deviceName ?: "noname"} [$deviceHardwareAddress]"
                        )
                    }
                }
                BluetoothDevice.ACTION_FOUND -> {
                    (intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE) as? BluetoothDevice)?.let { device ->
                        val deviceName =
                            device.name ?: intent.getParcelableExtra(BluetoothDevice.EXTRA_NAME)
                        val deviceHardwareAddress = device.address // MAC address

                        if (serviceUUID == null || device.uuids == null || device.uuids!!.any { it.uuid.toString() == serviceUUID }) {
                            if (deviceName == null) return
                            if (devices[deviceHardwareAddress] != null) return

                            devices[deviceHardwareAddress] = device

                            Log.d(TAG, "Device Found: $deviceName")

                            eventSink?.success(
                                mapOf(
                                    "type" to "scanning",
                                    "data" to devices.values.map {
                                        deviceToJson(it)
                                    }.toList()
                                )
                            )
                        }
                    }
                }
            }
        }
    }

    private inner class ConnectThread(private val handler: Handler, val device: BluetoothDevice) :
        Thread() {

        private val mmSocket: BluetoothSocket? by lazy(LazyThreadSafetyMode.NONE) {
            device.createRfcommSocketToServiceRecord(UUID.fromString("00001101-0000-1000-8000-00805F9B34FB"))
        }

        private lateinit var mmInStream: InputStream
        private lateinit var mmOutStream: OutputStream
        private lateinit var mmBuffer: ByteArray // mmBuffer store for the stream


        override fun run() {
            mmSocket?.let { socket ->
                // Connect to the remote device through the socket. This call blocks
                // until it succeeds or throws an exception.
                socket.connect()

                mmInStream = socket.inputStream
                mmOutStream = socket.outputStream
                mmBuffer = ByteArray(1024)

                // The connection attempt succeeded. Perform work associated with
                // the connection in a separate thread.
                thread { read() }
            }
        }

        fun read() {
            var numBytes: Int // bytes returned from read()

            // Keep listening to the InputStream until an exception occurs.
            while (true) {
                // Read from the InputStream.
                numBytes = try {
                    mmInStream.read(mmBuffer)
                } catch (e: IOException) {
                    Log.d(TAG, "Input stream was disconnected", e)
                    break
                }

                val received = mmBuffer.sliceArray(IntRange(0, numBytes - 1)).map { it.toUByte() }
                Log.d(TAG, "  <<< ${received.joinToString { "$it" }}")

                // Send the obtained bytes to the UI activity.
                val readMsg = handler.obtainMessage(
                    MESSAGE_READ, numBytes, -1,
                    MessageObject(
                        device,
                        received
                    )
                )
                readMsg.sendToTarget()
            }
        }

        fun write(bytes: ByteArray) {
            Log.d(TAG, ">>>   ${bytes.joinToString { it.toUByte().toString() }}")

            try {
                mmOutStream.write(bytes)
            } catch (e: IOException) {
                Log.e(TAG, "Error occurred when sending data", e)

                // Send a failure message back to the activity.
                val writeErrorMsg = handler.obtainMessage(MESSAGE_TOAST)
                val bundle = Bundle().apply {
                    putString("toast", "Couldn't send data to the other device")
                }
                writeErrorMsg.data = bundle
                handler.sendMessage(writeErrorMsg)
                return
            }

            // Share the sent message with the UI activity.
            val writtenMsg = handler.obtainMessage(
                MESSAGE_WRITE, -1, -1, mmBuffer
            )
            writtenMsg.sendToTarget()
        }

        // Closes the client socket and causes the thread to finish.
        fun cancel() {
            try {
                mmSocket?.close()
            } catch (e: IOException) {
                Log.e(TAG, "Could not close the client socket", e)
            }
        }
    }
}

data class MessageObject(val device: BluetoothDevice, val data: Any)
