enum SimpleblueState {
  /**
   * iOS
   * A state that indicates Bluetooth is currently powered off.
   *
   * Android
   * Indicates the local Bluetooth adapter is off.
   */
  off,

  /**
   * iOS
   * A state that indicates Bluetooth is currently powered on and available to use.
   *
   * Android
   * Indicates the local Bluetooth adapter is on, and ready for use.
   */
  on,

  /**
   * Only on Android
   * Indicates the local Bluetooth adapter is turning off. Local clients should immediately attempt graceful disconnection of any remote links.
   */
  turningOff,

  /**
   * Only on Android
   * Indicates the local Bluetooth adapter is turning on. However local clients should wait for STATE_ON before attempting to use the adapter.
   */
  turningOn,

  /**
   * Only on iOS
   * A state that indicates the connection with the system service was momentarily lost.
   */
  resetting,

  /**
   * Only on iOS
   * A state that indicates the application isn’t authorized to use the Bluetooth low energy role.
   */
  unauthorized,

  /**
   * iOS
   * The manager’s state is unknown.
   */
  unknown,

  /**
   * Only on iOS
   * A state that indicates this device doesn’t support the Bluetooth low energy central or client role.
   */
  unsupported;

  static SimpleblueState fromInt(int state) {
    switch (state) {
      case 4:  // iOS
      case 10: // Android
        return off;
      case 5:  // iOS
      case 12: // Android
        return on;
      case 13: return turningOff;
      case 11: return turningOn;
      case 1: return resetting;
      case 3: return unauthorized;
      case 2: return unsupported;
    }

    return unknown;
  }
}
