function fig1 = PlotAZFP(Output,Parameters)
%(Output,Channel,Value2Plot,NoiseFloor)

% PlotAZFP('Output',Output,'Channel',2,'Value2Plot',2,'NoiseFloor',[10000],'Orientation',1);
% Inputs can be in any order or omitted and the defaults will be used:
% Output: pass in the Output array from ProcessAZFP
% Channel: freq to plot #1-4, default 1
% Value2Plot = 1,2,3,4 = Counts, Sv, TS, Temperature/Tilts, default 2
% NoiseFloor = 10000; % for Sv and Ts plotting only, values
% with counts < NoiseFloor will be set to -150, can use individual values
% for eash frequency, ex. 'NoiseFloor',[10000; 11000; 10500; 12500]
% Default = 10000.
% Orientation = 0 instrument on bottom looking up (range bins), 1 at surface looking down (depth bins). This
% changes the ydir on the echogram plots. Default 1.
%
% Ver 1.3 September 2017
% written by Dave Billenness
% ASL Environmental Sciences Inc.
% 1-6703 Rajpur Place, Victoria, B.C., V8M 1Z5, Canada
% T: +1 (250) 656-0177 ext. 126
% E: dbillenness@aslenv.com
% w: http://www.aslenv.com/
% For any suggestions, comments, questions or collaboration, please contact me.

% defaults
Channel = 1;
Value2Plot = 2;
NoiseFloor = 10000;
Orientation = 1;
UseTiltCorr = 0;
StartRange = 0;
EndRange = 0;
fig1 = [];

if isfield(Parameters,'Channel')
    Channel = Parameters(1).Channel;
end
if isfield(Parameters,'Value2Plot')
    Value2Plot = Parameters(1).Value2Plot;
end
if isfield(Parameters,'NoiseFloor')
    NoiseFloor = Parameters(1).NoiseFloor;
end
if isfield(Parameters,'Orientation')
    Orientation = Parameters(1).Orientation;
end
if isfield(Parameters,'UseTiltCorr')
    UseTiltCorr = Parameters(1).UseTiltCorr;
end
if isfield(Parameters,'StartRange')
    StartRange = Parameters(1).StartRange;
end
if isfield(Parameters,'EndRange')
    EndRange = Parameters(1).EndRange;
end

CBarLim = [-110 -40];
if isempty(Output) || ~isstruct(Output)
    error('Use [Output,Par] = ProcessAZFP(varargin) and pass in a valid Output variable');
end
% check # Channels
if length(Output) < Channel
    Channel = length(Output);
end
% if more channels than NoiseFloors given then use the first value
if length(NoiseFloor) < Channel
    NoiseFloor(Channel) = NoiseFloor;
end
% find loc with N < NoiseFloor
if Value2Plot > 1 && Value2Plot < 4
    NFloc = find(Output(Channel).N < NoiseFloor(Channel));
end

% only the first datafile's range values are used to plot the data.
% Plot the data by ping number, not date. If it is burst data (irregularly
% spaced in time), imagesc will fill the gaps in with the data when plotted vs.
% Date. Plot as ping number then replace with Dates

% use tilt corr range in plots?
if UseTiltCorr
    Y = Output(Channel).TiltCorrRange(1,:);
    txt = 'Tilt Corrected '; % for ylabel
else
    Y = Output(Channel).Range(1,:);
    txt = '';
end

% create a new figure window
if ~isfield(Parameters,'Subplot')
    fig1 = figure;
else
    subplot(4,1,Parameters.Subplot);
end

% use Output(1).Depth if non-zero
if isfield(Parameters,'useDepth')
    useDepth = Parameters(1).useDepth;
    if all(Output(1).Depth) && Value2Plot <= 3 && useDepth
        Xrec = size(Output(1).Date,1);
        Yrec = size(Output(Channel).N,2);
        % need to make array from min depth+range(1) to max depth+range(end) and fill
        Y1 = Y(1) + min(Output(1).Depth);
        Y2 = Y(end) + max(Output(1).Depth);
        Ynew = Y1:Output(1).BinInc(Channel):Y2;
        if Value2Plot == 1
            %Output(Channel).N
        elseif Value2Plot == 2
            %Output(Channel).Sv
            Sv = zeros(Xrec,length(Ynew)) + NaN;
            for(kk=1:Xrec)
                d = Output(1).Depth(kk)+Y(1);
                [~,loc]=min(abs(d-Ynew));
                Sv(kk,loc:loc+Yrec-1) = Output(Channel).Sv(kk,:);
            end
            Output(Channel).Sv = Sv;
        else
            %Output(Channel).TS
        end
        Y = Ynew;
    end
end

switch Value2Plot
    case 1 % counts
        imagesc(1:length(Output(1).Date),Y,Output(Channel).N',[0 65535]);
        y_tick = 0:8192:65536;
        y_limit = [0 65536];
        y_label = 'Counts';
    case 2 % Sv
        Output(Channel).Sv(NFloc) = NaN;
        imAlpha=ones(size(Output(Channel).Sv'));
        imAlpha(isnan(Output(Channel).Sv'))=0;
        imagesc(1:length(Output(1).Date),Y,Output(Channel).Sv','AlphaData',imAlpha,CBarLim);
        y_tick = CBarLim(1):10:CBarLim(2);
        y_limit = CBarLim;
        y_label = 'Sv (dB re 1/m)';
    case 3 % TS
        Output(Channel).TS(NFloc) = -150;
        imagesc(1:length(Output(1).Date),Y,Output(Channel).TS',[-150 -10]);
        y_tick = -150:10:-10;
        y_limit = [-150 -10];
        y_label = 'Ts';
    case 4 % Tx etc
        yyaxis("left")
        % plot Tx, Ty and Temperature
        plot(1:length(Output(1).Date),Output(1).Tx,'r.-',1:length(Output(1).Date),Output(1).Ty,'b.-',1:length(Output(1).Date),Output(1).T,'g.-');
        ylabel('Tilt (deg) and Temperature (degC)')
        if isfield(Output(1),'Depth')
            yyaxis("right")
            set(gca,'YDir','reverse');
            plot(1:length(Output(1).Date),Output(1).Depth,'k.-');
            ylabel('Depth (m)');
            set(gca,'YColor','k');
        end
        format = 'dd-mmm-yy';
        if(Output(1).Date(end)-Output(1).Date(1) < 4) % less than 3 day add HH:MM
            format = 'dd-mmm-yy HH:MM';
        end
        numTicks = 4;
        if(Output(1).Date(end)-Output(1).Date(1) < 1) % less than 1 day
            numTicks = 12;
        end
        if(length(Output(1).Date) > 1)
            set(gca,'xlim',[1 length(Output(1).Date)]);
            set(gca,'xtick',[1:round(length(Output(1).Date)/numTicks):length(Output(1).Date)]);
        end
        
        if(length(Output(1).Date) > 1)
            set(gca, 'XTickLabel', cellstr(datestr(Output(1).Date(round(get(gca,'xtick'))),format)));
        end
        if isfield(Output(1),'Depth')
            legend('Tx (deg)','Ty (deg)','T (degC)','Depth (m)');
        else
            legend('Tx (deg)','Ty (deg)','T (degC)');
        end
        grid on;
        if(length(Output(1).filename)>1)
            title(['Files: ' char(Output(1).filename(1)) ' to ' char(Output(1).filename(end)) '  [' datestr(Output(1).Date(1)) ' to ' datestr(Output(1).Date(end)) ']']);
        else
            title(['File: ' char(Output(1).filename(1)) '  [' datestr(Output(1).Date(1)) ' to ' datestr(Output(1).Date(end)) ']']);
        end
    otherwise % SvAvg over depth
        if StartRange > 0 && EndRange > 0
            hold on;
            for ii = 1:length(Output)
                plot(1:length(Output(1).Date),Output(ii).Sv,'DisplayName', [num2str(Output(ii).Freq) 'kHz'],'LineWidth',1.3);
            end
            hold off;
            if(length(Output(1).Date) > 1)
                set(gca,'xlim',[1 length(Output(1).Date)]);
                set(gca,'xtick',[1:round(length(Output(1).Date)/4):length(Output(1).Date)]);
            end
            format = 'dd-mmm-yy';
            if(Output(1).Date(end)-Output(1).Date(1) < 4) % less than 3 day add HH:MM
                format = 'dd-mmm-yy HH:MM';
            end
            if(length(Output(1).Date) > 1)
                set(gca, 'XTickLabel', cellstr(datestr(Output(1).Date(round(get(gca,'xtick'))),format)));
            end
            grid on;
            txt1 = sprintf('Sv at Range: %.1fm (TimeAvg = %.0f, BinAvg = %.0f)',Output(1).Range(1), Output(1).Time2Avg(1), Output(1).StartEndRangeNumBins{1});          
            if(length(Output(1).filename)>1)
                title([txt1 ', Files: ' char(Output(1).filename(1)) ' to ' char(Output(1).filename(end)) '  [' datestr(Output(1).Date(1)) ' to ' datestr(Output(1).Date(end)) ']']);
            else
                title([txt1 ', File: ' char(Output(1).filename(1)) '  [' datestr(Output(1).Date(1)) ' to ' datestr(Output(1).Date(end)) ']']);
            end
            ylabel('Sv (dB re 1/m)');
            legend('Location', 'north','Orientation','horizontal')
        end

end

if Value2Plot < 4 % imagesc plots
    %     try
    %         load('AZFPColormap.mat');
    %         colormap(myNewMap);
    %     catch
    colormap(jet(1000));
    %    end
    H = colorbar;
    set(H,'ylim',y_limit);
    set(H,'ytick',y_tick);
    set(H, 'YTickLabel', cellstr(num2str(reshape(get(H, 'YTick'),[],1),'%.0f')) );
    title(H,y_label);
    
    if Orientation
        ylabel([txt 'Range (metres)']);
    else
        set(gca,'ydir','normal');
        ylabel([txt 'Range (metres)']);
    end
    if length(Output(1).Date) > 1
        set(gca,'xlim',[1 length(Output(1).Date)]);
        set(gca,'xtick',[1:round(length(Output(1).Date)/8):length(Output(1).Date)]);
    end
    format = 'dd-mmm-yy';
    if Output(1).Date(end)-Output(1).Date(1) < 4 % less than 3 day add HH:MM
        format = 'dd-mmm-yy HH:MM';
    end
    if length(Output(1).Date) > 1
        set(gca, 'XTickLabel', cellstr(datestr(Output(1).Date(round(get(gca,'xtick'))),format)));
    end
    
    % set up zoom to redraw dateticks
    if ~isfield(Parameters,'Subplot')
        z = zoom(gcf);
        set(z,'ActionPostCallback',{@zoomDateTick,Output(1).Date});
        set(z,'Enable','on');
    end
    
    % set up title
    if length(Output(1).filename)>1
        txt1 = ['Files: ' char(Output(1).filename(1)) ' to ' char(Output(1).filename(end))];
    else
        txt1 = ['File: ' char(Output(1).filename(1))];
    end
    title(['Channel ' num2str(Channel) ': Freq ' num2str(Output(Channel).Freq) 'kHz - ' txt1 '  [' datestr(Output(1).Date(1)) ' to ' datestr(Output(1).Date(end)) '], TimeAvg = ' num2str(Output(1).Time2Avg) ', BinAvg = ' num2str(Output(1).Bins2Avg)]);
else
    % set up zoom to redraw dateticks
    z = zoom(gcf);
    set(z,'ActionPostCallback',{@zoomDateTick,Output(1).Date});
    set(z,'Enable','on');
    
end

function zoomDateTick(~,event_obj,Date)

% get current xlim when zoomed and round the values
xlim = get(event_obj.Axes,'xlim');
set(event_obj.Axes,'xlim',[floor(xlim(1)) ceil(xlim(2))]);
xlim = get(event_obj.Axes,'xlim');

% set xticks
set(event_obj.Axes,'xtick',[xlim(1):round((xlim(2)-xlim(1))/8):xlim(2)]);
xticks = get(event_obj.Axes,'xtick');    % Get x ticks after zooming

% set xticks to Dates
format = 'dd-mmm-yy';
if Date(xlim(2))-Date(xlim(1)) < 3 % less than 3 day plotted
    format = 'dd-mmm-yy HH:MM';
end
if Date(xlim(2))-Date(xlim(1)) < 5/1440 % less than 5 min plotted
    format = 'dd-mmm-yy HH:MM:SS';
end
if ~isempty(xticks)
    set(event_obj.Axes, 'XTickLabel', cellstr(datestr(Date(round(xticks)),format)));
end

function zoomDateTick2(~,event_obj)

nticks = 5;                             % How many tick marks to use
xlim = get(event_obj.Axes,'XLim');    % Get x limits after zooming
newticks = linspace(xlim(1),xlim(2),nticks); % Create n ticks
set(event_obj.Axes,'XTick',newticks);   % Set x tick marks in axes

format = 'dd-mmm-yy';
if xlim(2)-xlim(1) < 3 % less than 3 day plotted
    format = 'dd-mmm-yy HH:MM';
end
if xlim(2)-xlim(1) < 5/1440 % less than 5 min plotted
    format = 'dd-mmm-yy HH:MM:SS';
end
% Change format using "datetick" but preserve custom ticks:
datetick(event_obj.Axes,'x',format,'keepticks')
