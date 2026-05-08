function [spd, ax] =spdSiteSeason(ltsa,varargin)
% spdSiteSeason(ltsa,varargin)
% SPD by site (rows) and season(columns) ;
figWidth = 16;        % Figure width in cm
nCols = length(ltsa); % Number of sub-plot columns
% dBBins = 60:130;
% xlims = [5 125];

% highFreqFactor specifies the proportion of max freq to use for finding 
% min and max dB. Needed to avoid anti-aliasing filter on high end. 
highFreqFactor = 0.9; 

xlims = [10 nan]; % 10 Hz frequency limits avoids effects of DC coupling.

% Get frequency limits and dB limits from data
for i = 1:length(ltsa)
    freqMax(i) = max(ltsa(i).freq);
    ix = ltsa(i).freq > xlims(1) & ltsa(i).freq < freqMax(i)*highFreqFactor; 
    dBMin(i) = min(ltsa(i).ltsa(ix,:),[],'all'); 
    dBMax(i) = max(ltsa(i).ltsa(ix,:),[],'all'); 
end
xlims(2) = max(freqMax);
dBBins = min(dBMin):max(dBMax);

figure1 = figure('units','centimeters','Position',[3 1 figWidth 22]);
tl = tiledlayout(nCols,4,"TileSpacing","compact","Padding","compact");

ylims = [min(dBBins) max(dBBins)];
tcount = 1;
for j = 1:length(ltsa)
    dt = datetime(ltsa(j).t,'ConvertFrom','datenum');
    [time, labs] = season(dt(:));
    seasonLabs = labs.long; % Time labels (strings)


    plotTimes = time;
    tLabs = seasonLabs;


    cMax = 2e-1;
    cats = categories(plotTimes);

    for i = 1:length(cats)
        iAx = int16(i); % Axes (plot) index
        ax(j,iAx) = nexttile(tl);
        ix = int16(plotTimes)==i; % subset by season
        [~, spd{j,iAx}] = plotSpd(ltsa(j).freq(3:end),ltsa(j).ltsa(3:end,ix), ...
            dBBins,false);
        colormap(plasma);
        ax(j,iAx).Layer="top";
        set(gca,'ylim',ylims,'xlim',xlims); % 'XTick',[10, 100]
        set(gca,...'XTickLabel',get(gca,'xtick'), ...
            'clim',[1e-3,max(cMax,max(spd{j,iAx},[],'all'))]);
        if max(get(gca,'clim'))>cMax
            cMax = max(get(gca,'clim'));
        end

        % xlabel on bottom row only
        if tcount <= 4*(nCols-1)
            set(gca,xticklabels='');
            xlabel('');
        else
            xlabel(tLabs{i});
        end

        % ylabel on left column only
        if rem(tcount-1,4)~=0
            set(gca,yticklabels='');
            ylabel('');
        else
            code = strrep(ltsa(j).code,'Meek001_','');
            code = strrep(code,'_2024','');
            ylabel(code);
        end
        tcount=tcount+1;
    end
end

linkaxes(ax,'xy');
tl.XLabel.String='Frequency (Hz)';
tl.YLabel.String= 'Power Spectral Density (dB re 1 uPa^2/Hz)';
cb = colorbar;
cb.Layout.Tile='North';
cb.TickDirection="both";
cb.Label.String='Probability Density (of hourly mean PSD)';
cb.Ticks = [0.001:0.001:0.002, 0.005, 00.01:0.01:0.03, 0.05, 0.1:0.1:0.3 0.5];
cb.TickLabelsMode='auto';
tlab = cb.TickLabels;
tlab{1} = strcat('≤',tlab{1});
cb.TickLabels=tlab;


% Tick labels just on left and bottom subplots
%     arrayfun(@(x) set(x,'yticklabelmode','auto'),ax(1:4));
%     arrayfun(@(x) set(x,'xticklabelmode','auto'),ax(4));


