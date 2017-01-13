function string = tooltipstring(sObject)
% generate tooltip string from the data of a graphical object
%
% SWPLOT.TOOLTIPSTRING(sObject)
%

string = '';

switch sObject.name
    case 'atom'
        labelTemp = strword(sObject.label,[1 2],true);
        label1 = labelTemp{1};
        label2 = labelTemp{2};
        string = [label2 ' atom (' label1 ')' newline 'Unit cell:' newline];
        % add cell index and position
        posi = sObject.position(:,1)';
        string = [string sprintf('[%d, %d, %d]',floor(posi)) newline 'Atomic position' newline sprintf('[%5.3f, %5.3f, %5.3f]',posi-floor(posi))];
end

end