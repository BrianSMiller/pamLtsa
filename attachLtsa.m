function data = attachLtsa(metadata, ltsa, freqs, t)
% attachLtsa  Calibrate and attach LTSA arrays to a metadata struct.
%
% Applies hydrophone calibration to a raw LTSA and attaches the calibrated
% result to the metadata struct, producing the same struct shape as
% loadCalibratedLtsa. Useful when working with freshly computed LTSAs
% rather than loading from a saved .mat file.
%
% Usage:
%   data = attachLtsa(metadata, ltsa, freqs, t)
%
% Inputs:
%   metadata  Deployment metadata struct (from loadRecorderMetaData or equivalent)
%   ltsa      numFreqs x numSlices raw PSD matrix (linear, V^2/Hz)
%   freqs     numFreqs x 1 frequency vector in Hz
%   t         1 x numSlices datenum vector of slice start times
%
% Output:
%   data  metadata struct with additional fields:
%           ltsa                 numFreqs x numSlices, dB re 1 uPa^2/Hz
%           freq                 numFreqs x 1, Hz
%           t                    1 x numSlices, datenum
%           transferFunction_dB  numFreqs x 1, calibration in dB
%
% See also: loadCalibratedLtsa, calibrateLtsa, loadLtsa

arguments
    metadata (1,1) struct
    ltsa     (:,:) double
    freqs    (:,1) double
    t        (1,:) double
end

data = metadata;
data.freq = freqs;
data.t    = t;
[data.ltsa, data.transferFunction_dB] = calibrateLtsa(ltsa, freqs, metadata);
