function [ltsa_dB, caldB] = calibrateLtsa(ltsa, freqs, metadata)
% calibrateLtsa  Apply hydrophone calibration to a raw LTSA.
%
% Converts a raw power spectral density matrix (linear, V^2/Hz) to
% calibrated sound pressure levels (dB re 1 uPa^2/Hz) using the
% deployment metadata from loadRecorderMetaData or equivalent.
%
% Usage:
%   [ltsa_dB, caldB] = calibrateLtsa(ltsa, freqs, metadata)
%
% Inputs:
%   ltsa      numFreqs x numSlices matrix of raw PSD values (linear)
%   freqs     numFreqs x 1 frequency vector in Hz
%   metadata  Deployment metadata struct with fields:
%               hydroSensitivity_dB  scalar, dB re 1 V/uPa
%               frontEndGain_dB      vector, dB
%               frontEndFreq_Hz      vector, Hz (same length as frontEndGain_dB)
%               adPeakVolt           scalar, V
%
% Outputs:
%   ltsa_dB   numFreqs x numSlices matrix of calibrated PSD (dB re 1 uPa^2/Hz)
%   caldB     numFreqs x 1 calibration transfer function in dB
%
% See also: loadCalibratedLtsa, loadLtsa, loadRecorderMetaData

arguments
    ltsa     (:,:) double
    freqs    (:,1) double
    metadata (1,1) struct
end

adVpeakdB = 10*log10(1 / metadata.adPeakVolt^2);

if isnan(adVpeakdB) || any(isnan(metadata.frontEndGain_dB)) || isnan(metadata.hydroSensitivity_dB)
    warning('calibrateLtsa:noCalibration', ...
        ['Calibration metadata contains NaN — returning uncalibrated PSD\n' ...
         '(0 dB offset applied). Results are in arbitrary dB, not dB re 1 uPa^2/Hz.']);
    caldB   = zeros(size(freqs));
    ltsa_dB = 10*log10(ltsa);
    return
end

frontEndGain_dB = interp1( ...
    log10(metadata.frontEndFreq_Hz), ...
    metadata.frontEndGain_dB, ...
    log10(freqs), 'linear', 'extrap');

caldB   = metadata.hydroSensitivity_dB + frontEndGain_dB + adVpeakdB;
ltsa_dB = 10*log10(ltsa) - repmat(caldB, 1, size(ltsa, 2));
