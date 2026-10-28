#include "WebRTCAudioProcessing.h"

#include "api/audio/audio_processing.h"
#include "api/scoped_refptr.h"

struct WAPEchoCanceller {
    rtc::scoped_refptr<webrtc::AudioProcessing> processing;
    webrtc::StreamConfig stream{16000, 1};
};

WAPEchoCanceller *wap_echo_canceller_create(void) {
    webrtc::AudioProcessing::Config config;
    // Only the echo canceller: the level of the voice is not changed by any other stage.
    config.echo_canceller.enabled = true;
    config.echo_canceller.mobile_mode = false;
    config.echo_canceller.enforce_high_pass_filtering = false;
    config.high_pass_filter.enabled = false;
    config.pre_amplifier.enabled = false;
    config.capture_level_adjustment.enabled = false;
    config.noise_suppression.enabled = false;
    config.gain_controller1.enabled = false;
    config.gain_controller2.enabled = false;

    auto processing = webrtc::AudioProcessingBuilder().SetConfig(config).Create();
    if (!processing) {
        return nullptr;
    }
    return new WAPEchoCanceller{processing};
}

void wap_echo_canceller_destroy(WAPEchoCanceller *canceller) {
    delete canceller;
}

int wap_echo_canceller_process_reference(WAPEchoCanceller *canceller, const float *frame) {
    const float *channels[1] = {frame};
    // The float interface needs an output; the processed reference is not used.
    float scratch[WAP_FRAME_SAMPLES];
    float *out[1] = {scratch};
    return canceller->processing->ProcessReverseStream(channels, canceller->stream, canceller->stream, out);
}

int wap_echo_canceller_process_microphone(WAPEchoCanceller *canceller, const float *input, float *output) {
    const float *in[1] = {input};
    float *out[1] = {output};
    return canceller->processing->ProcessStream(in, canceller->stream, canceller->stream, out);
}
