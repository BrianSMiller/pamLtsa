function data = loadCalibratedLtsa(code)
% loadCalibratedLtsa  Load and calibrate a long-term spectral average.
%
% Loads the LTSA for a deployment and applies the hydrophone calibration
% to convert raw PSD (linear, V^2/Hz) to dB re 1 uPa^2/Hz.
%
% Usage:
%   data = loadCalibratedLtsa(code)        % deployment code string
%   data = loadCalibratedLtsa(metadata)    % metadata struct
%
% Input:
%   code  Either a deployment code string recognised by loadRecorderMetaData
%         (e.g. 'kombi003_2021'), or a metadata struct from that function.
%
% Output:
%   data  Metadata struct with additional fields:
%           ltsa              numFreqs x numSlices, dB re 1 uPa^2/Hz
%           freq              numFreqs x 1, Hz
%           t                 1 x numSlices, datenum
%           transferFunction_dB  numFreqs x 1, calibration in dB
%
% See also: loadRecorderMetaData, loadLtsa, calibrateLtsa

switch class(code)
    case 'char'
        data = loadRecorderMetaData(code);
    case 'struct'
        data = code;
    otherwise
        error('loadCalibratedLtsa:badInput', ...
            '1st input must be a deployment code string or metadata struct')
end

[ltsa, freq, t] = loadLtsa(data.ltsaFile, data.startDate, data.endDate);
data = attachLtsa(data, ltsa, freq, t);
