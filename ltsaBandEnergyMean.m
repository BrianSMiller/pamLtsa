function p = ltsaBandEnergyMean(ltsa,freqs,band)
% p = ltsaBandEnergy(ltsa,freqs,band);
if (band(1) > band(2))
    band = flip(band);
end
sliceIx = (freqs > band(1) & freqs < band(2));
ix = repmat(sliceIx,1,size(ltsa,2));
p = sum(ltsa .* ix,1,'omitnan')/sum(sliceIx);
p = 20 * log10(p);