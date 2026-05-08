function plotDeploymentLocations(siteCode)
m = struct2table(loadRecorderMetaData(siteCode));
m_proj('UTM','lon',[min(m.longitude),max(m.longitude)],'lat',[min(m.latitude),max(m.latitude)]);
m_scatter(m.longitude,m.latitude,80,'filled'); 
hold on; 
% m_scatter(m.longitude(6),m.latitude(6),'r','filled');
m_utmgrid;
m_text(m.longitude+0.001,m.latitude,m.code)
hold off;
xlabel('Easting (km)');
ylabel('Northing (km)');
m_ruler(0.95,[0.05 0.95]);
m_ruler([0.05 0.95],0.95);
