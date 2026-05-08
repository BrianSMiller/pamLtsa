function [ltsa_hmd, freqTable] = ltsaToMillidecade(ltsa, freqs, sampleRate)
% ltsaToMillidecade  Convert a full-resolution LTSA to hybrid millidecade bands.
%
% Compresses a power spectral density matrix from 1 Hz resolution to the
% hybrid millidecade format proposed by Martin et al. (2021). Below 455 Hz
% the 1 Hz bins are preserved; above 455 Hz logarithmically-spaced
% millidecade bands are used. This provides a large compression ratio for
% high-bandwidth recorders while maintaining full resolution in the
% biologically-important low-frequency range.
%
% For a 24 kHz recorder: ~1300 bands vs 12001 1 Hz bins (9:1 compression)
% For a 96 kHz recorder: ~2000 bands vs 48001 1 Hz bins (24:1 compression)
%
% Usage:
%   [ltsa_hmd, freqTable] = ltsaToMillidecade(ltsa, freqs, sampleRate)
%
% Inputs:
%   ltsa        numFreqs x numSlices matrix of raw PSD values (linear,
%               V^2/Hz or Pa^2/Hz). Output of wavFolderToLtsa or pwelch.
%   freqs       numFreqs x 1 frequency vector in Hz (from pwelch or
%               wavFolderToLtsa).
%   sampleRate  Scalar sample rate in Hz. Used to define the Nyquist
%               frequency and band table.
%
% Outputs:
%   ltsa_hmd    numBands x numSlices matrix of hybrid millidecade PSD
%               values (same units as input ltsa — linear, mean PSD per
%               band in units of input/Hz).
%   freqTable   numBands x 3 array of [bandStart, bandCenter, bandEnd]
%               frequencies in Hz. Column 2 (band centers) is the
%               frequency axis for plotting.
%
% References:
%   Martin et al. (2021). Hybrid millidecade spectra: A practical format
%   for exchange of long-term ambient sound data. JASA Express Letters,
%   1(1), 011203. https://doi.org/10.1121/10.0003324
%
% Dependencies:
%   getBandTable, getBandMeanPowerSpectralDensity, getBandSquaredSoundPressure,
%   getCenterFreq — from Martin et al. (2021) supplementary material,
%   available at c:\analysis\millidecade\
%
% See also: wavFolderToLtsa, calibrateLtsa, loadCalibratedLtsa

arguments
    ltsa       (:,:) double
    freqs      (:,1) double
    sampleRate (1,1) double {mustBePositive}
end

% FFT bin size from frequency vector
fftBinSize = freqs(2) - freqs(1);

% Build hybrid millidecade band table for this sample rate
% Parameters: fftBinSize, bin1CenterFreq, fs, base, bandsPerDivision,
%             firstOutputBandCenterFreq, useFFTResAtBottom
freqTable = getBandTable(fftBinSize, 0, sampleRate, 10, 1000, 1, 1);
nBands = size(freqTable, 1);

% getBandMeanPowerSpectralDensity expects rows=time, cols=freq
% ltsa is numFreqs x numSlices, so transpose in and out
ltsa_hmd = getBandMeanPowerSpectralDensity( ...
    ltsa', fftBinSize, 0, 1, nBands, freqTable)';

end
