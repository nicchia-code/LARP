#ifndef WEBRTC_AUDIO_PROCESSING_H
#define WEBRTC_AUDIO_PROCESSING_H

#ifdef __cplusplus
extern "C" {
#endif

/// Samples in one 10 ms frame of 16 kHz mono audio: the only format the echo canceller takes.
#define WAP_FRAME_SAMPLES 160

/// WebRTC's echo canceller (AEC3) alone: no gain control, no noise suppression, no other
/// stage. It takes 16 kHz mono float audio in 10 ms frames, in the range [-1, 1].
typedef struct WAPEchoCanceller WAPEchoCanceller;

/// Creates an echo canceller, or returns NULL when it cannot be created.
WAPEchoCanceller *wap_echo_canceller_create(void);

void wap_echo_canceller_destroy(WAPEchoCanceller *canceller);

/// Gives the canceller one frame of the reference signal (the sound the speakers play).
/// `frame` holds WAP_FRAME_SAMPLES samples. Returns 0 on success.
int wap_echo_canceller_process_reference(WAPEchoCanceller *canceller, const float *frame);

/// Removes the echo of the reference from one frame of the microphone signal. `input` and
/// `output` hold WAP_FRAME_SAMPLES samples each and may be the same memory.
/// Returns 0 on success.
int wap_echo_canceller_process_microphone(WAPEchoCanceller *canceller, const float *input, float *output);

#ifdef __cplusplus
}
#endif

#endif
