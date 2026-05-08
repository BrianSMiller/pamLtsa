function [h,gaps] = plotDataGaps(m,start,stop)
gaps = getNoDataTimes(start,stop,m);
shouldHold = ishold;
hold on;
ax = gca;

minorTicks =  dateshift(start,'start','month'):calmonths(1):dateshift(stop,'start','month');
if ~isdatetime(ax.XLim)
    gaps = datenum(gaps);
    minorTicks = datenum(minorTicks);
end

for i = 1:length(gaps)
    h(i) = plotSquare(gaps(i,:),ylim,0.85*[1 1 1], ...
        'faceColor',0.85*[1 1 1]);
end
uistack(h,'bottom')

% set(h,'FaceAlpha',0.5,'EdgeAlpha',0.5);
% ax.XAxis.MinorTickValues=minorTicks;
% ax.XAxis.MinorTick='on';
if ~shouldHold
    hold off;
end

