function [ltsa_bands, freqTable] = ltsaToBands(ltsa, freqs, sampleRate, bandType)
% ltsaToBands  Convert a full-resolution LTSA to standard frequency bands.
%
% Compresses a power spectral density matrix from 1 Hz resolution to one
% of several standard band formats. Millidecade and decidecade bands use
% the hybrid millidecade framework of Martin et al. (2021), preserving
% 1 Hz resolution below 455 Hz. Octave and third-octave bands use exact
% ISO 266 centre frequencies computed directly from the 1 Hz bins.
%
% Third-octave and decidecade bands are numerically identical (both divide
% a decade into 10 equal logarithmic steps, since 3 third-octaves per
% octave × log2(10) octaves per decade ≈ 10 bands per decade). ISO 266
% third-octave centre frequencies (e.g. 100, 125, 160, 200 Hz ...)
% coincide with decidecade centres. Both are returned identically; the
% label differs for documentation purposes only.
%
% Usage:
%   [ltsa_bands, freqTable] = ltsaToBands(ltsa, freqs, sampleRate, bandType)
%
% Inputs:
%   ltsa        numFreqs x numSlices matrix of raw PSD values (linear,
%               Pa^2/Hz). Output of wavFolderToLtsa or pwelch.
%   freqs       numFreqs x 1 frequency vector in Hz.
%   sampleRate  Scalar sample rate in Hz.
%   bandType    String specifying band type (case-insensitive):
%                 'millidecade'  — 1000 bands per decade (default)
%                 'decidecade'   — 10 bands per decade
%                 'third-octave' — 10 bands per decade (≡ decidecade;
%                                  ISO 266 centre frequencies)
%                 'octave'       — ISO 266 octave bands, exact centres
%                                  computed directly from 1 Hz bins
%
% Outputs:
%   ltsa_bands  numBands x numSlices matrix of band-averaged PSD values
%               (same linear units as input, mean PSD per band in Pa^2/Hz).
%   freqTable   numBands x 3 array of [bandStart, bandCenter, bandEnd]
%               frequencies in Hz.
%
% References:
%   Martin et al. (2021). Hybrid millidecade spectra: A practical format
%   for exchange of long-term ambient sound data. JASA Express Letters,
%   1(1), 011203. https://doi.org/10.1121/10.0003324
%
%   ISO 266:1997. Acoustics — Preferred frequencies.
%
% Dependencies:
%   getBandTable, getBandMeanPowerSpectralDensity — from Martin et al.
%   (2021) supplementary material, available at c:\analysis\millidecade\
%
% See also: ltsaBandEnergy, ltsaBandEnergyMean, wavFolderToLtsa

arguments
    ltsa       (:,:) double
    freqs      (:,1) double
    sampleRate (1,1) double {mustBePositive}
    bandType   (1,1) string = "millidecade"
end

switch lower(bandType)

    case 'millidecade'
        [ltsa_bands, freqTable] = iGetBands(ltsa, freqs, sampleRate, 1000);

    case {'decidecade', 'third-octave'}
        [ltsa_bands, freqTable] = iGetBands(ltsa, freqs, sampleRate, 10);

    case 'octave'
        [ltsa_bands, freqTable] = iGetOctaveBands(ltsa, freqs, sampleRate);

    otherwise
        error('ltsaToBands:unknownBandType', ...
            'bandType must be ''millidecade'', ''decidecade'', ''third-octave'', or ''octave''. Got: %s', ...
            bandType);
end

end

% -------------------------------------------------------------------------
function [ltsa_bands, freqTable] = iGetBands(ltsa, freqs, sampleRate, bandsPerDivision)
% Shared path for millidecade and decidecade via Martin et al. getBandTable.

fftBinSize = freqs(2) - freqs(1);
freqTable  = getBandTable(fftBinSize, 0, sampleRate, 10, bandsPerDivision, 1, 1);
nBands     = size(freqTable, 1);

ltsa_bands = getBandMeanPowerSpectralDensity( ...
    ltsa', fftBinSize, 0, 1, nBands, freqTable)';

end

% -------------------------------------------------------------------------
function [ltsa_bands, freqTable] = iGetOctaveBands(ltsa, freqs, sampleRate)
% ISO 266 octave bands computed directly from 1 Hz bins.
%
% Band edges are f_centre * 2^(+/-0.5), giving exact ISO 266 centres:
%   16, 31.5, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000 Hz ...
% Only bands whose edges fall within the recorder's usable range are
% returned. Output is mean linear PSD (Pa^2/Hz) per band, consistent
% with the millidecade/decidecade paths.

% Full set of ISO 266 octave centre frequencies (Hz)
iso_centres = [16, 31.5, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000, 31500];

nyquist  = sampleRate / 2;
f_low    = freqs(1);

% Exact ISO band edges: centre * 2^(+/-0.5)
edges_lo = iso_centres ./ sqrt(2);
edges_hi = iso_centres .* sqrt(2);

% Retain only bands fully within the available frequency range
valid    = edges_lo >= f_low & edges_hi <= nyquist;
centres  = iso_centres(valid);
edges_lo = edges_lo(valid);
edges_hi = edges_hi(valid);

nBands     = numel(centres);
nSlices    = size(ltsa, 2);
ltsa_bands = zeros(nBands, nSlices);

for ib = 1:nBands
    sliceIx = freqs >= edges_lo(ib) & freqs <= edges_hi(ib);
    if ~any(sliceIx)
        ltsa_bands(ib, :) = NaN;
    else
        ltsa_bands(ib, :) = mean(ltsa(sliceIx, :), 1, 'omitnan');
    end
end

freqTable = [edges_lo(:), centres(:), edges_hi(:)];

end
