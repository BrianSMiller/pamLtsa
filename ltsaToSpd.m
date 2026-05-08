function [figure1, spd]= ltsaToSpd(ltsa,timeType,dBBins)
% Plot spectral probability distribution from long-term spectral average
% (of power spectral densities). 

if nargin < 2
    timeType = 'season';
end

if nargin < 3
    dBBins = 40:120;
end
ltsa.dt = datetime(ltsa.t,'ConvertFrom','datenum');

[ltsa.season, labs] = season(ltsa.dt);
ltsa.seasonLabs = labs.long; % Time labels (strings)

ltsa.monthLabs = categorical(month(datetime(2000,1:12,1),'shortname'));
ltsa.month = categorical(month(ltsa.dt),(1:12),cellstr(ltsa.monthLabs));

switch(timeType)
    case 'month'
        nCols = 3; % Number of sub-plot columns
        figWidth = 28; % Figure width in cm
        ltsa.plotTimes = ltsa.month;
        ltsa.tLabs = categories(ltsa.month);
    case 'season'
        nCols = 1; % Number of sub-plot columns
        figWidth = 8; % Figure width in cm
        ltsa.plotTimes = ltsa.season;
        ltsa.tLabs = ltsa.seasonLabs;
end

figure1 = figure('units','centimeters','Position',[3 1 figWidth 18]);
tl = tiledlayout(4,nCols,"TileSpacing","compact","Padding","compact");


cMax = 2e-1;
cats = categories(ltsa.plotTimes);
for i = 1:length(cats)
    iAx = int16(i); % Axes (plot) index
    ax(iAx) = nexttile;
    ix = int16(ltsa.plotTimes)==i; % subset by season
    [h(iAx), spd{iAx}] = plotSpd(ltsa.freq(3:end),ltsa.ltsa(3:end,ix), ...
        dBBins,false);
    ylabel('');
    text(10.^mean(log10(xlim)),min(dBBins),ltsa.tLabs{i}, ...
        'horizontalAlignment','Center','VerticalAlignment','bottom', ...
        'FontWeight','bold')
    colormap(plasma);
    ax(iAx).Layer="top";
    set(gca,'XTick',[10,100,1000],'ylim',[40 120]);
    set(gca,'XTickLabel',get(gca,'xtick'),'clim',[1e-2,max(cMax,max(spd{iAx},[],'all'))]);
    if max(get(gca,'clim'))>cMax
        cMax = max(get(gca,'clim'));
    end
    set(gca,xticklabels='',yticklabels='');
    
end
linkaxes(ax,'xy');
tl.XLabel.String='Frequency (Hz)';
tl.YLabel.String= 'Power Spectral Density (dB re 1 uPa^2/Hz)';
cb = colorbar;
cb.Layout.Tile='East';
cb.Label.String='Probability Density (of hourly mean PSD)';
tlab = cb.TickLabels;
tlab{1} = strcat('≤',tlab{1});
cb.TickLabels=tlab;


switch(timeType)
    case('month')
        % Tick labels just on left and bottom subplots
        arrayfun(@(x) set(x,'yticklabelmode','auto'),ax(1:3:10));
        arrayfun(@(x) set(x,'xticklabelmode','auto'),ax(10:12));
        spdAnnotate_Kombi003_monthly;
    case('season')
        % Tick labels just on left and bottom subplots
        arrayfun(@(x) set(x,'yticklabelmode','auto'),ax(1:4));
        arrayfun(@(x) set(x,'xticklabelmode','auto'),ax(4));

end