# macOS

The operating system of the Mac, which tells the app what happens around it.

## Events

### APP_LAUNCHED
The app has been launched, at login or by the user.

### CALL_APP_MIC_STARTED
A known call app has started using the microphone; apps already using it when the app starts watching count as started.

### CALL_APP_MIC_STOPPED
A known call app has stopped using the microphone.

### AUDIO_DEVICES_CHANGED
The audio devices of the Mac have changed: the default microphone or output, the list of devices, the sample rate of the output or of the system audio, for example because headphones were plugged in or Bluetooth headphones switched to their call mode.

### NETWORK_AVAILABLE
The Mac is connected to the network again after being offline.

### LANGUAGE_INSTALLED
The speech model of the chosen transcription language is installed on the Mac, found at a check or after a download.

### LANGUAGE_NOT_INSTALLED
A check finds that the speech model of the chosen transcription language is not installed; its download starts.

### LANGUAGE_DOWNLOAD_FAILED
The download of the speech model of the chosen transcription language has failed, or the model is still missing after it.
