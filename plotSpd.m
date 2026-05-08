% [h, spd, hp] = plotSpd(f, psd)
% Plot spectral probability distribution
% Given a long-term spectral average such as hourly power-spectral
% densities (PSDs), or MANTA minute-level PSDs plot the spectral
% probability distribution of each frequency band, f.
function [h, spd, hp] = plotSpd(f, psd, dBBins, quantileLines)
if nargin < 3
    dBBins = 0:1:160;
end
if nargin < 4
    quantileLines = true;
end

% Figure out which dimension of psd matches f;
dim = find(size(psd)==length(f));
timeDim = find(size(psd)~=length(f));

spd = nan(length(dBBins)-1,size(psd,dim));

for i = 1:size(psd,dim)
    if dim == 2
        [spd(:,i), c] = histcounts(psd(:,i),dBBins,'Normalization','probability');
    else
        [spd(:,i), c] = histcounts(psd(i,:),dBBins,'Normalization','probability');
    end
end
spd(spd(:)==0)=nan(size(find(spd(:)==0)));

Q = quantile(psd,[0.05 0.25 0.5 0.75 0.95],timeDim);

h = pcolor(f, dBBins(2:end), spd);
h.LineStyle='none';
set(gca,'XScale','log')
% cmap = flipud(gray(10));
% cmap = cmap(2:end,:)
% cmap = flipud(brewermap(20,'spectral'));
% cmap = plasma(20);
% colormap(cmap)
% cb = colorbar;
% cb.Label.String='Probability density';
% cb.Location="north";
% cb.Position=[0.7 0.85 0.18 0.025];
% cb.AxisLocation="in";
grid on;
cLim = get(gca,'CLim');
cLim = [cLim(1), 0.2];
cLim = [0.0001 1];
% xlabel('Frequency (Hz)')
ylabel('PSD (dB re 1 \muPa)');
ylim([min(psd(:)),max(psd(:))]);
xlim([min(f),max(f)]);
hold on;
set(gca,...'XTicklabel',get(gca,'XTick')
    'CLim',cLim,'ColorScale','log');

if quantileLines
    hp = plot(f,Q,'k');
    hold off;
    hp(1).LineStyle='-';  hp(1).DisplayName = ' 5th';
    hp(2).LineStyle='--'; hp(2).DisplayName = '25th';
    hp(3).LineWidth=2;    hp(3).DisplayName = '50th';
    hp(4).LineStyle='-.'; hp(4).DisplayName = '75th';
    hp(5).LineStyle=':';  hp(5).DisplayName = '95th';
end

end
