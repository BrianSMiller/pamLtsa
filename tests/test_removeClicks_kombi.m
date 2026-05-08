%% test_removeClicks_kombi.m
%
% Manual visual validation of removeClicks on real Kombi003 2021 data.
%
% This 300 s window contains two types of impulsive noise:
%   - Echosounder pulses: regular ~1 Hz bursts, high amplitude, broadband
%   - Seismic airgun shots: ~20 s spacing, low-frequency (<200 Hz),
%     from a distant survey vessel
%
% With default settings (threshold=3, amount=1000), removeClicks
% suppresses the echosounder pulses as intended. However, it introduces
% broadband artefacts at the airgun shot times — visible as short broadband
% bursts in the cleaned audio that are not present in the raw. This is a
% known limitation of threshold-based gating when multiple impulsive noise
% sources with different amplitudes and frequency content are present
% simultaneously. The airguns are received at low amplitude and low
% frequency (below threshold in the raw), but once the echosounder is
% suppressed the local RMS drops and the airgun samples can exceed the
% recalculated threshold.
%
% This example illustrates that removeClicks should be used with awareness
% of the noise environment — it is not a general-purpose impulsive noise
% suppressor.
%
% Expected result: visual inspection of three panels —
%   1. Waveform overlay (raw=blue, cleaned=orange)
%   2. Raw spectrogram — echosounder columns clearly visible, airgun
%      energy confined to low frequencies
%   3. Cleaned spectrogram — echosounder suppressed, but broadband
%      artefacts visible at ~20 s intervals (airgun shot times)
%
% Data required:
%   w:\LongTermRecording2002_present\KOMBI003_2021\25_2021-03-08_03-00-00.wav
%
% See also: removeClicks, wavFolderToLtsa

fs_nominal = 12e3;  % Sample rate Hz
s   = 1;            % Start sample
dur = 300;          % Duration in s

nfft   = 8192;
win    = nfft;
ovrlap = floor(nfft * 0.5);

startEnd = [s, s + fs_nominal * dur];

[w, fs] = audioread( ...
    'w:\LongTermRecording2002_present\KOMBI003_2021\25_2021-03-08_03-00-00.wav', ...
    startEnd);
w_noClicks = removeClicks(w, 3, 1e3);

figure('Name', 'removeClicks — Kombi003 2021', ...
    'Units', 'centimeters', 'Position', [2 2 24 18]);

subplot(3, 1, 1);
plot(w); hold on; plot(w_noClicks); hold off;
legend('Raw', 'Click removed', 'Location', 'southwest');
title('Waveform — echosounder suppressed; broadband artefacts at airgun shot times (~20 s spacing)');
xlabel('Sample'); ylabel('Amplitude');

subplot(3, 1, 2);
spectrogram(w,         win, ovrlap, nfft, fs, 'yaxis', 'minThreshold', -100);
title('Raw');

subplot(3, 1, 3);
spectrogram(w_noClicks, win, ovrlap, nfft, fs, 'yaxis', 'minThreshold', -100);
title('Click removed (threshold=3, amount=1000)');
