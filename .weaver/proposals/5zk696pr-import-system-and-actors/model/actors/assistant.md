# Assistant

omp, the AI assistant the user installs and configures on the Mac, outside the app, and reaches through the PATH of the user's login shell. It receives the text of a transcript, never the audio, and answers with corrections or with a summary of the call, through the model provider configured in omp.

## Events

### REACHED
omp has been found on the Mac and answered the app within the time allowed.

### UNREACHABLE
omp is not found on the Mac, ends with an error or does not answer within the time allowed.
