function p = ltsaBandEnergy(ltsa,freqs,band);
% p = ltsaBandEnergy(ltsa,freqs,band);
if (band(1) > band(2))
    band = flip(band);
end
sliceIx = (freqs > band(1) & freqs < band(2));
ix = repmat(sliceIx,1,size(ltsa,2));
% p = sumskipnan(ltsa .* ix,1)/diff(band);
p = nansum(ltsa .* ix,1)/diff(band);
p = 10 * log10(p);