function [Output,Parameters,PavgArr] = LoadAZFP(varargin)

% LoadAZFP.m run as:
% [Output,Par] = LoadAZFP('datafilename','','xmlfilename','15051410.XML','Salinity',35,'Bins2Avg',5,'Time2Avg',100);
%
% Inputs can be in any order or omitted and the defaults will be used:
% defaultxmlfilename = ''; % prompt for XML filename
% defaultdatafilename = ''; % AZFP hourly data file name
% defaultSalinity = 35; % Salinity in
% defaultBins2Avg = 1; % number of range bins to average
% defaultTime2Avg = 1; % number of time values to average
%
% Outputs are:
% Output: computed data with N, Sv and TS, averaged in range/time. Each
% freq stored in Output(1), Output(2) etc
% Par: the instrument parameters from the XML file
%
% Ver 1.3 September 2017
% written by Dave Billenness
% ASL Environmental Sciences Inc.
% 1-6703 Rajpur Place, Victoria, B.C., V8M 1Z5, Canada
% T: +1 (250) 656-0177 ext. 126
% E: dbillenness@aslenv.com
% w: http://www.aslenv.com/
% For any suggestions, comments, questions or collaboration, please contact me.

p = inputParser;
defaultParameters = '';
defaultdatafilename = '';
defaultBins2Avg = 1;
defaultStartRange = 0;
defaultEndRange = 0;
defaultTime2Avg = 1;
defaultPressure = 50;
defaultSalinity = 35;
addParameter(p,'Parameters',defaultParameters,@isstruct);
addParameter(p,'datafilename',defaultdatafilename,@ischar);
addParameter(p,'Bins2Avg',defaultBins2Avg,@isnumeric);
addParameter(p,'StartRange',defaultStartRange,@isnumeric);
addParameter(p,'EndRange',defaultEndRange,@isnumeric);
addParameter(p,'Time2Avg',defaultTime2Avg,@isnumeric);
addParameter(p,'Pressure',defaultPressure,@isnumeric);
addParameter(p,'Salinity',defaultSalinity,@isnumeric);
parse(p,varargin{:});
Parameters = p.Results.Parameters;
datafilename = p.Results.datafilename;
Bins2Avg = p.Results.Bins2Avg;
StartRange = p.Results.StartRange;
EndRange = p.Results.EndRange;
Time2Avg = p.Results.Time2Avg;
Press = p.Results.Pressure;    % pressure (dBar)
Salinity = p.Results.Salinity;

% initialize variables
Data = [];
StartEndRangeAvg = 0;
Output = [];
pathname = '';
PavgArr = [];
OutputPavg = 0;
LoadCSV = 0;

if ~isfield(Parameters,'ShowComments')
    Parameters(1).ShowComments = 1;
end
if ~isfield(Parameters,'HourlyTemp')
    Parameters(1).HourlyTemp = [];
end
if ~isfield(Parameters,'QuickScan') % load only first ping of uls6 data for a quickscan (quickview)
    Parameters(1).QuickScan = 0;
end
if isfield(Parameters,'PavgArr') % output PavgArr even if no averaging
    OutputPavg = 1;
end
if isfield(Parameters,'LoadCSV') % output PavgArr even if no averaging
    LoadCSV = 1;
end
if StartRange > 0 && EndRange > 0
    StartEndRangeAvg = 1;
    Bins2Avg = 1; % will do averaging from start-end
end
% select an AZFP hourly file
if isempty(datafilename)
    [filename, pathname] = uigetfile({'*.*A;*.*B;*.*C;*.*D;*.azfp;*.aps6'}, 'Select an AZFP hourly file');
else
    pathname = pwd;
    filename = datafilename;
end

% open binary file
if LoadCSV
    fidAZFP = 0;
else
    fidAZFP = fopen([pathname '/' filename],'rb');
    if fidAZFP < 1
        fprintf('File %s not found!\n',[pathname '/' filename]);
        return;
        %[filename, pathname] = uigetfile({'*.*A;*.*B;*.*C;*.*D'}, 'Select an AZFP hourly file');
        %fidAZFP = fopen([pathname '/' filename],'rb');
    end
end

% load the data
ii = 1;
Stop = 0;
while ~feof(fidAZFP) && ~Stop
    if ~Parameters.ULS6 && ~LoadCSV
        [Data,Success] = readAZFP(fidAZFP,ii,Data,Parameters);
    elseif LoadCSV
        if ii == 1
            [CSVData, Success] = readCSV(Parameters);
            Data = defaultData(ii);
        end
        d = defaultData(ii);
        d.ProfileNumber = ii;
        d.BurstInt = table2array(CSVData(ii,6));
        d.Date = datenum(table2array(CSVData(ii,3))+table2array(CSVData(ii,4)));
        d.DigRate = table2array(CSVData(ii,17));
        d.LockoutInd = 0;
        d.NumBins = table2array(CSVData(ii,14));
        d.RangeSamples = table2array(CSVData(ii,15));
        d.PingPerProfile = table2array(CSVData(ii,8));
        d.AvgPings = 0;
        d.NumAcqPings = 1;
        d.PingPeriod = table2array(CSVData(ii,7));
        d.FirstLastPing = [];
        d.DataType = 0;
        d.DataError = 0;
        d.Phase = 1;
        d.Overrun = 0;
        d.NumChan = 1;
        d.Gain = [];
        d.PulseLength = table2array(CSVData(ii,16));
        Parameters(1).PulseLenPhase = d.PulseLength;
        d.BoardNum = [];
        d.Freq = table2array(CSVData(ii,12));
        d.SensorFlag = 1;
        d.Ancillary = [];
        d.T = table2array(CSVData(ii,25));
        d.Tx = table2array(CSVData(ii,22));
        d.Ty = table2array(CSVData(ii,23));
        d.BatteryMain = table2array(CSVData(ii,24));
        d.BatteryTx = 0;
        d.Depth = 0;
        d.Pressure = 0;
        d.AD = [];
        d.counts = {table2array(CSVData(ii,29:end))'};
        Data(ii) = d;
        if ii == size(CSVData,1)
            Stop = 1;
        end
    else
        if ii == 1
            Data = defaultULS6;
        end
        d = defaultULS6;
        [d,Success,Parameters] = readULS6(fidAZFP,1,d,Parameters);
        if ~isempty(d.NumDataBytes)
            Data(ii) = d;
        end
        if Parameters(1).QuickScan && ii > 1
            Stop = 1;
        end

    end

    if Success
        % compare the size of Parameters.Freq to Data(1).NumChan,
        % if Data(1).NumChan < Parameters.Freq, then get rid of the unused
        % values in Parameters.EL, Parameters.DS etc so the channels match the
        % Parameters
        if (Data(1).NumChan < length(Parameters(1).Freq)) && ii == 1
            FreqCollected = Data(1).Freq(1:Data(1).NumChan)';
            [~,ia] = setdiff(Parameters(1).Freq,FreqCollected);
            Parameters(1).Freq(ia) = [];
            Parameters(1).EL(ia) = [];
            Parameters(1).DS(ia) = [];
            Parameters(1).TVR(ia) = [];
            Parameters(1).VTX(ia) = [];
            Parameters(1).BP(ia) = [];
            Parameters(1).DigRate(ia) = [];
            try
                Parameters(1).AcquireFrequencyPhase(:,ia) = [];
                Parameters(1).PulseLenPhase(:,ia) = [];
                Parameters(1).DigRatePhase(:,ia) = [];
                Parameters(1).RangeSamplesPhase(:,ia) = [];
                Parameters(1).RangeAveragingSamplesPhase(:,ia) = [];
            catch
            end
        end

        % preallocate array if data averaging to #values in the hourly file x number of ranges
        if ii == 1 && (Bins2Avg > 1 || Time2Avg > 1 || StartEndRangeAvg || OutputPavg)
            for jj = 1:Data(ii).NumChan
                NumAvg = 1;
                if Data(1).DataType(jj) % if averaged data then divide by # pings
                    NumAvg = Data(1).NumAcqPings;
                end
                PavgArr(jj).data = zeros(floor(3600/Data(1).BurstInt)*ceil(Data(1).PingPerProfile/NumAvg),Data(1).NumBins(jj));
            end
        end

        % compute temperature from Data(ii).Ancillary(5)
        if ~LoadCSV
            Data(ii).T = NaN;
            if isempty(Parameters(1).HourlyTemp)
                Data(ii).T = computeTemperature(Data(ii).Ancillary(5),Parameters);
            else
                Data(ii).T = Parameters(1).HourlyTemp;
            end
        end

        if ii == 1
            [~,NAME,EXT] = fileparts(Parameters(1).xmlfilename);
            if Parameters(1).ShowComments
                fprintf('File: %s - Loading Profile #%d %s using xml=%s Bins2Avg=%d Time2Avg=%d Salinity=%.2f Pressure=%.1f ',filename,Data(ii).ProfileNumber,datestr(Data(ii).Date),[NAME EXT],Bins2Avg,Time2Avg,Salinity,Press);
            end
        end

        % compute tilts from Data(ii).Ancillary(1) and
        % Data(ii).Ancillary(2), then cos(tiltmag), battery from
        % Ancillary(3), pressure from Ancillary(4)
        if ~LoadCSV
            Data(ii).Tx = computeTilt(Data(ii).Ancillary(1),Parameters(1).X_a,Parameters(1).X_b,Parameters(1).X_c,Parameters(1).X_d);
            Data(ii).Ty = computeTilt(Data(ii).Ancillary(2),Parameters(1).Y_a,Parameters(1).Y_b,Parameters(1).Y_c,Parameters(1).Y_d);
            Data(ii).cosTiltMag = cos((sqrt(Data(ii).Tx^2+Data(ii).Ty^2))*pi/180);
            Data(ii).BatteryMain = computeBattery(Data(ii).Ancillary(3)); % main battery pack
            Data(ii).BatteryTx = computeBattery(Data(ii).AD(1)); %if there is a Tx battery pack
            Data(ii).Depth = 0;
            Data(ii).Pressure = 0;
            if Parameters.a0 ~= 0 && Parameters.a1 ~= 0 %if there is a Psensor
                [Data(ii).Depth,Data(ii).Pressure] = computeDepth(Data(ii).Ancillary(4),Parameters,Data(ii).T);
            end
        else
            Data(ii).cosTiltMag = cos((sqrt(Data(ii).Tx^2+Data(ii).Ty^2))*pi/180);
        end

        % compute power if we are averaging the data
        if Bins2Avg > 1 || Time2Avg > 1 || StartEndRangeAvg || OutputPavg
            for jj = 1:Data(ii).NumChan
                EL = Parameters(1).EL(jj) - 2.5/Parameters(1).DS(jj) + Data(ii).counts{jj}/(26214*Parameters(1).DS(jj));
                P = 10.^(EL/10);
                if ~isempty(P)
                    Data(ii).Pavg{jj} = P';
                    % create an array so easier to time average
                    PavgArr(jj).data(ii,:) = Data(ii).Pavg{jj}';
                end
            end
        end
        ii = ii + 1;
    else
        % check if entire file is empty, or just an end block of data,
        % either return [] data or break out of loop
        if Parameters.ULS6
            if isempty(Data(end).NumDataBytes)
                fclose(fidAZFP);
                return;
            end
        else
            break;
        end
    end
end
% close the binary file
if ~LoadCSV
    fclose(fidAZFP);
end

% trim PavgArr to 1:ii-1 in case not a full hour of data
if Bins2Avg > 1 || Time2Avg > 1 || StartEndRangeAvg || OutputPavg
    for jj = 1:Data(1).NumChan
        PavgArr(jj).data(ii:end,:) = [];
    end
end

% compute hourly average temperature, then use this to compute SoundSpeed
% and the range bins, store in Data(1)
if isempty(Parameters(1).HourlyTemp)
    Data(1).HourlyAvgTemp = mean(arrayfun(@(x) Data(x).T, 1:length(Data)),'omitnan');
    fprintf('HrlyTemp=%.1f ',Data(1).HourlyAvgTemp);
else
    Data(1).HourlyAvgTemp = Parameters(1).HourlyTemp;
    fprintf('HrlyTemp=%.1f ',Data(1).HourlyAvgTemp);
end
if isnan(Data(1).HourlyAvgTemp) || ~isreal(Data(1).HourlyAvgTemp)
    Data(1).HourlyAvgTemp = 15; %to do, move this to the setup parameter file
    fprintf('\n**** No AZFP temperature found - using a fixed temperature of %.1f degC to calc soundspeed and range\n', Data(1).HourlyAvgTemp);
    %f = msgbox(['No water temperature available ...using a fixed value of ' num2str(Data(1).HourlyAvgTemp) ' degC'],'Warning');
end

%compute hourly average pressure, then use this to compute SoundSpeed
if Parameters.a0 ~= 0 && Parameters.a1 ~= 0
    Press = nanmean(arrayfun(@(x) Data(x).Pressure, 1:length(Data)));
    fprintf('HrlyPressure=%.1f\n',Press);
else
    fprintf('\n');
end

% calculate sound speed using input Salinity
% use meas Pressure if available
Data(1).SoundSpeed = computeSS(Data(1).HourlyAvgTemp,Press,Salinity);

% compute the hourly avg value of the cos(TiltMag)
Data(1).HourlyAvgcosTiltMag = mean(arrayfun(@(x) Data(x).cosTiltMag, 1:length(Data)));

% if no bin averaging and PArameters.Value2Plot=3 (TS) adjust to start of bin
RangeOffset = [0 0 0 0];
if Parameters(1).Value2Plot == 3 && Bins2Avg == 1
    fprintf('Setting range to start of bin instead of center, no bin averaging and TS...\n');
    for jj = 1:Data(1).NumChan
        RangeOffset(jj) =  Data(1).SoundSpeed*Parameters(1).PulseLenPhase(jj)*1e-6/4;%Data(1).PulseLength(jj)
    end
end

% compute range and avg range (if depth averaging)
for jj = 1:Data(1).NumChan
    % calc the number of averaged blocks and the range to the centre of the
    % sampling volume for bin m (from eqn. 11 on page 86 of the AZFP Operators Manual)
    m = 1:length(1:Bins2Avg:length(Data(1).counts{jj})-Bins2Avg+1);
    Data(1).Range{jj} = Data(1).SoundSpeed*Data(1).LockoutInd(jj)/(2*Data(1).DigRate(jj))+(Data(1).SoundSpeed/4)*(((2*m-1)*Data(1).RangeSamples(jj)*Bins2Avg-1)/Data(1).DigRate(jj)+Parameters(1).PulseLenPhase(jj)/1e6) - RangeOffset(jj);

    % calc absorption coeff for each freq
    Data(1).seaAbs(jj) = computeAbs(Data(1).HourlyAvgTemp,Press,Salinity,Data(1).Freq(jj));

    m = 1:length(1:1:length(Data(1).counts{jj})-1+1);
    r = Data(1).SoundSpeed*Data(1).LockoutInd(jj)/(2*Data(1).DigRate(jj))+(Data(1).SoundSpeed/4)*(((2*m-1)*Data(1).RangeSamples(jj)*1-1)/Data(1).DigRate(jj)+Parameters(1).PulseLenPhase(jj)/1e6) - RangeOffset(jj);
    % calc orig range and time sampling
    Output(1).BinInc(jj) = mean(diff(r));
end

% check averaging time, max is all values in hourly file
if Time2Avg > length(Data)
    Time2Avg = length(Data);
end

% average from StartBin to EndBin if they are > 0
if StartEndRangeAvg
    for jj = 1:Data(1).NumChan
        r = Data(1).Range{jj};
        c = Data(1).counts{jj};
        p = PavgArr(jj).data;
        % get closest Range to Start and EndRange
        [~,startloc(jj)] = min(abs(r - StartRange));
        [~,endloc(jj)] = min(abs(r - EndRange));
        r = r(startloc:endloc);
        c = c(startloc:endloc);
        p = p(:,startloc:endloc);
        % trim
        Data(1).Range{jj} = mean(r);
        Data(1).counts{jj} = c;
        PavgArr(jj).data = p;
        Data(1).StartEndRangeNumBins{jj} = endloc-startloc+1; % number of bins averaged
    end
end

% now bin average, after all data from a single file has been loaded
if Bins2Avg > 1 || StartEndRangeAvg
    for jj = 1:Data(1).NumChan
        if StartEndRangeAvg
            tmp1 = mean(PavgArr(jj).data,2);
        else
            % calc #bins after averaging
            numBins = Data(1).counts{jj};
            numBins = length(arrayfun(@(i) mean(numBins(i:i+Bins2Avg-1)),1:Bins2Avg:length(numBins)-Bins2Avg+1));
            tmp1 = zeros(size(PavgArr(jj).data,1),numBins);
            for nn = 0:numBins-1
                tmp1(:,nn+1) = mean(PavgArr(jj).data(:,nn*Bins2Avg+1:(nn+1)*Bins2Avg),2);
            end
        end
        PavgArr(jj).data = tmp1;
    end
end

% now time average
if Time2Avg > 1
    NumTime = floor(length(Data)/Time2Avg);
    for kk = 1:NumTime
        % Elements of array to average, Time2Avg = 30 then Elem=1-30, 31-60 etc
        Elem = [(kk-1)*Time2Avg+1:(kk-1)*Time2Avg+Time2Avg]';
        for jj = 1:Data(1).NumChan
            % convert back to counts N
            ELavg = 10*log10(mean(PavgArr(jj).data(Elem,:),1));
            Output(jj).N(kk,:) = round(26214*Parameters(1).DS(jj)*(ELavg - Parameters(1).EL(jj) + 2.5/Parameters(1).DS(jj)));
            Output(jj).Range = Data(1).Range{jj};
            Output(jj).TiltCorrRange = Data(1).Range{jj}*Data(1).HourlyAvgcosTiltMag;
            % calc correction to Sv due to non square transmit pulse
            SvOffset = CalcSvOffset(Data(1).Freq(jj),Parameters(1).PulseLenPhase(jj));
            Output(jj).Sv(kk,:) = Parameters(1).EL(jj)-2.5/Parameters(1).DS(jj)+Output(jj).N(kk,:)/(26214*Parameters(1).DS(jj))-Parameters(1).TVR(jj)-20*log10(Parameters(1).VTX(jj))+20*log10(Output(jj).Range)+2*Data(1).seaAbs(jj)*Output(jj).Range-10*log10(0.5*Data(1).SoundSpeed*Parameters(1).PulseLenPhase(jj)/1e6*Parameters(1).BP(jj)) + SvOffset;
            Output(jj).TS(kk,:) = Parameters(1).EL(jj)-2.5/Parameters(1).DS(jj)+Output(jj).N(kk,:)/(26214*Parameters(1).DS(jj))-Parameters(1).TVR(jj)-20*log10(Parameters(1).VTX(jj))+40*log10(Output(jj).Range)+2*Data(1).seaAbs(jj)*Output(jj).Range;
            Output(jj).Freq = Data(1).Freq(jj);
            Output(jj).seaAbs = Data(1).seaAbs(jj);
        end
        Output(1).Date(kk,1) = mean(arrayfun(@(x) Data(x).Date, Elem))';
        Output(1).Tx(kk,1) = mean(arrayfun(@(x) Data(x).Tx, Elem))';
        Output(1).Ty(kk,1) = mean(arrayfun(@(x) Data(x).Ty, Elem))';
        Output(1).T(kk,1) = mean(arrayfun(@(x) Data(x).T, Elem))';
        Output(1).BatteryMain(kk,1) = mean(arrayfun(@(x) Data(x).BatteryMain, Elem))';
        Output(1).BatteryTx(kk,1) = mean(arrayfun(@(x) Data(x).BatteryTx, Elem))';
        Output(1).Depth(kk,1) = mean(arrayfun(@(x) Data(x).Depth, Elem))';
    end

else % no time averaging, but may still have range averaging
    if Bins2Avg > 1 || StartEndRangeAvg
        for jj = 1:Data(1).NumChan
            % convert back to counts N
            ELavg = 10*log10(PavgArr(jj).data);
            Output(jj).N = round(26214*Parameters(1).DS(jj)*(ELavg - Parameters(1).EL(jj) + 2.5/Parameters(1).DS(jj)));
            Output(jj).Range = Data(1).Range{jj};
            Output(jj).TiltCorrRange = Data(1).Range{jj}*Data(1).HourlyAvgcosTiltMag;
        end
    else
        for jj = 1:Data(1).NumChan
            Output(jj).N = cell2mat(arrayfun(@(x) Data(x).counts{jj}', [1:length(Data)]', 'UniformOutput', false));
            Output(jj).Range = Data(1).Range{jj};
            Output(jj).TiltCorrRange = Data(1).Range{jj}*Data(1).HourlyAvgcosTiltMag;
        end
    end
    for jj = 1:Data(1).NumChan
        % calc correction to Sv due to non square transmit pulse
        SvOffset = CalcSvOffset(Data(1).Freq(jj),Parameters(1).PulseLenPhase(jj));
        Output(jj).Sv = Parameters(1).EL(jj)-2.5/Parameters(1).DS(jj)+Output(jj).N./(26214*Parameters(1).DS(jj))-Parameters(1).TVR(jj)-20*log10(Parameters(1).VTX(jj))+20*log10(repmat(Output(jj).Range,[size(Output(jj).N,1) 1]))+2*Data(1).seaAbs(jj).*(repmat(Output(jj).Range,[size(Output(jj).N,1) 1]))-10*log10(0.5*Data(1).SoundSpeed*Parameters(1).PulseLenPhase(jj)/1e6*Parameters(1).BP(jj)) + SvOffset;
        Output(jj).TS = Parameters(1).EL(jj)-2.5/Parameters(1).DS(jj)+Output(jj).N./(26214*Parameters(1).DS(jj))-Parameters(1).TVR(jj)-20*log10(Parameters(1).VTX(jj))+40*log10(repmat(Output(jj).Range,[size(Output(jj).N,1) 1]))+2*Data(1).seaAbs(jj).*(repmat(Output(jj).Range,[size(Output(jj).N,1) 1]));
        Output(jj).Freq = Data(1).Freq(jj);
        Output(jj).seaAbs = Data(1).seaAbs(jj);
    end
    Output(1).Date = arrayfun(@(x) Data(x).Date, 1:length(Data))';
    Output(1).Tx = arrayfun(@(x) Data(x).Tx, 1:length(Data))';
    Output(1).Ty = arrayfun(@(x) Data(x).Ty, 1:length(Data))';
    Output(1).T = arrayfun(@(x) Data(x).T, 1:length(Data))';
    Output(1).BatteryMain = arrayfun(@(x) Data(x).BatteryMain, 1:length(Data))';
    Output(1).BatteryTx = arrayfun(@(x) Data(x).BatteryTx, 1:length(Data))';
    Output(1).Depth = arrayfun(@(x) Data(x).Depth, 1:length(Data))';
end
% trim N, Sv, TS to length of Output(1).Date
% size of Output(1).N if averaging was based on pre-alloc PavgArr array
% before the hourly file was read in (there may be missing time values)
if size(Output(1).N,1) > size(Output(1).Date,1)
    Output(1).N(size(Output(1).Date,1)+1:end,:)= [];
    Output(1).TS(size(Output(1).Date,1)+1:end,:)= [];
    Output(1).Sv(size(Output(1).Date,1)+1:end,:)= [];
end

% store orig bin and time
% for jj=1:Data(1).NumChan
%     % calc orig range and time sampling
%     Output(1).BinInc(jj) = mean(diff(Data(1).Range{jj}));
% end
Output(1).TimeInc = 0;
if length(Data(1).Date) > 1
    Output(1).TimeInc = round((Data(end).Date-Data(end-1).Date)*86400);
end

%fprintf('Date = %dx%d N = %dx%d\n',size(Output(1).Date),size(Output(1).N))
Output(1).HourlyAvgTemp = Data(1).HourlyAvgTemp;
Output(1).SoundSpeed = Data(1).SoundSpeed;
Output(1).NumChan = Data(1).NumChan;
Output(1).BurstInt = Data(1).BurstInt;
Output(1).PingPerProfile = Data(1).PingPerProfile;
Output(1).NumAcqPings = Data(1).NumAcqPings;
Output(1).DataType = Data(1).DataType;
Output(1).PulseLength = Parameters(1).PulseLenPhase;
Output(1).SerialNumber = Data(1).SerialNumber;
Output(1).StartEndRangeNumBins = 0;
if StartEndRangeAvg
    Output(1).StartEndRangeNumBins = Data(1).StartEndRangeNumBins;
end
end

% **************************************************************
% function readAZFP data block < uls6
function [Data,Success] = readAZFP(fidAZFP,ii,Data,Parameters)

% initialize variables
Success = 1;
FileType = 'FD02'; %specify profile data filetype

% read binary data file in big-endian format (ieee-be)
Flag = dec2hex(fread(fidAZFP,1,'uint16','ieee-be'));
if ~strcmpi(Flag,FileType)
    Success = 0;
    if ~feof(fidAZFP)
        fprintf('Error: Unknown file type: check that the correct XML file was loaded\n');
    end
    return;
end
Data(ii).ProfileFlag = Flag;

% try to speed up loading by loading in header with one fread and then
% using typecast to get indiv values and limit the number of freads
a = fread(fidAZFP,122,'uint8','ieee-be');
Data(ii).ProfileNumber = double(swapbytes(typecast(uint8(a(1:2)),'uint16')));
Data(ii).SerialNumber = double(swapbytes(typecast(uint8(a(3:4)),'uint16')));
Data(ii).PingStatus = double(swapbytes(typecast(uint8(a(5:6)),'uint16')));
Data(ii).BurstInt = double(swapbytes(typecast(uint8(a(7:10)),'uint32')));
date = double(swapbytes(typecast(uint8(a(11:24)),'uint16'))); % YY MM DD hh mm ss hh
Data(ii).Date = datenum(date(1),date(2),date(3),date(4),date(5),date(6)+date(7)/100);
Data(ii).DigRate = double(swapbytes(typecast(uint8(a(25:32)),'uint16'))); % digitization rate for each channel
Data(ii).LockoutInd = double(swapbytes(typecast(uint8(a(33:40)),'uint16'))); % lockout index for each channel
Data(ii).NumBins = double(swapbytes(typecast(uint8(a(41:48)),'uint16'))); % number of bins for each channel
Data(ii).RangeSamples = double(swapbytes(typecast(uint8(a(49:56)),'uint16'))); % range samples per bin for each channel
Data(ii).PingPerProfile = double(swapbytes(typecast(uint8(a(57:58)),'uint16'))); % number of pings per profile
Data(ii).AvgPings = double(swapbytes(typecast(uint8(a(59:60)),'uint16'))); % flag to indicate if pings avg in time
Data(ii).NumAcqPings = double(swapbytes(typecast(uint8(a(61:62)),'uint16'))); % # pings acquired in this burst
Data(ii).PingPeriod = double(swapbytes(typecast(uint8(a(63:64)),'uint16'))); % ping period in seconds
Data(ii).FirstLastPing = double(swapbytes(typecast(uint8(a(65:68)),'uint16')));
Data(ii).DataType = double(swapbytes(typecast(uint8(a(69:72)),'uint8'))); % datatype for each channel: 1=Avg Data (5bytes), 0=raw (2bytes)
Data(ii).DataError = double(swapbytes(typecast(uint8(a(73:74)),'uint16')));% error # is an error occurred
Data(ii).Phase = double(swapbytes(typecast(uint8(a(75)),'uint8'))); % phase # used to acquire this profile
Data(ii).Overrun = double(swapbytes(typecast(uint8(a(76)),'uint8'))); % 1 if an over run occurred
Data(ii).NumChan = double(swapbytes(typecast(uint8(a(77)),'uint8'))); % 1,2,3 or 4 (could acquire only 1 channel)
Data(ii).Gain = double(swapbytes(typecast(uint8(a(78:81)),'uint8'))); % gain chan 1-4
%fread(fidAZFP,1,'uint8','ieee-be'); %spare chan
Data(ii).PulseLength = double(swapbytes(typecast(uint8(a(83:90)),'uint16'))); % pulselength chan 1-4 uS
Data(ii).BoardNum = double(swapbytes(typecast(uint8(a(91:98)),'uint16'))); % the board the data came from chan 1-4
Data(ii).Freq = double(swapbytes(typecast(uint8(a(99:106)),'uint16'))); % freq Hz for chan 1-4
Data(ii).SensorFlag = double(swapbytes(typecast(uint8(a(107:108)),'uint16')));% Flag to indicate if pressure sensor or temper sensor is avail
Data(ii).Ancillary = double(swapbytes(typecast(uint8(a(109:118)),'uint16'))); % Tilt-X, Y, Battery, Pressure, Temperature
Data(ii).AD = double(swapbytes(typecast(uint8(a(119:122)),'uint16'))); % AD chan 6 and 7

% read in the data, bytes depend on avg or raw, # channels 1 up to 4
for jj = 1:Data(ii).NumChan % might have 4 freq but only 1 was acquired
    if Data(ii).DataType(jj) % averaged data = 32 bit summed up linear scale data followed by 8 bit overflow counts
        if Data(ii).AvgPings
            divisor = Data(ii).PingPerProfile * Data(ii).RangeSamples(jj);
        else
            divisor = Data(ii).RangeSamples(jj);
        end
        ls = fread(fidAZFP,Data(ii).NumBins(jj),'uint32','ieee-be'); %linearsum
        lso = fread(fidAZFP,Data(ii).NumBins(jj),'uchar','ieee-be'); %linearsumoverflow
        v = (ls + lso*4294967295)/divisor;
        v = (log10(v)-2.5)*(8*65535)*Parameters(1).DS(jj);
        v(isinf(v)) = 0;
        Data(ii).counts{jj} = v;
    else % raw data = 16 bit values Log values
        Data(ii).counts{jj} = fread(fidAZFP,Data(ii).NumBins(jj),'uint16','ieee-be');
    end
end

end

% *************************
function T = computeTemperature(counts,Par)

Vin = 2.5 * (counts / 65535);
R = (Par(1).ka + Par(1).kb * Vin) / (Par(1).kc - Vin);
T = 1 / (Par(1).A + Par(1).B * (log(R)) + Par(1).C * (log(R)^3)) - 273;

end

function Tilt = computeTilt(N,a,b,c,d)

% X_a; X_b; X_c and X_d
Tilt = a + b*(N) + c*(N)^2 + d*(N)^3;

end

function seaC = computeSS(T,P,S)

% from Fundamentals of Physical Acoustics By David T. Blackstock
z = T/10;
seaC = 1449.05+z*(45.7+z*((-5.21)+0.23*z))+(1.333+z*((-0.126)+z*0.009))*(S-35.0)+(P/1000)*(16.3+0.18*(P/1000));

end

% calc Absorption coeff using Temperature, Pressure and Salinity and
% transducer frequency
function seaAbs = computeAbs(T,P,S,Freq)

% calculate relaxation frequencies
T_K = T + 273.0;
f1 = 1320.0*(T_K)*exp(-1700/T_K);
f2 = (1.55e7)*T_K*exp(-3052/T_K);

% coefficients for absorption equations
k = 1 + P/10.0;
a = (8.95e-8)*(1+T*((2.29e-2)-(5.08e-4)*T));
b = (S/35.0)*(4.88e-7)*(1+0.0134*T)*(1-0.00103*k+(3.7e-7)*(k*k));
c = (4.86e-13)*(1+T*((-0.042)+T*((8.53e-4)-T*6.23e-6)))*(1+k*(-(3.84e-4)+k*7.57e-8));
freqk = Freq*1000;
if S == 0
    seaAbs = c*(freqk.^2);
else
    seaAbs = (a*f1*(freqk.^2))./((f1*f1)+(freqk.^2))+(b*f2*(freqk.^2))./((f2*f2)+(freqk.^2))+c*(freqk.^2);
end

end

% A correction must be made to compensate for the effects of the
% finite response times of both the receiving and transmitting parts of the instrument. The
% magnitude of the correction will depend on the length of the transmitted pulse, and the response
% time (on both transmission and reception) of the instrument.
function SvOffset = CalcSvOffset(Frequency,PulseLength)

SvOffset = 0;

if Frequency > 38 % 125,200,455,769 kHz
    if PulseLength == 300
        SvOffset = 1.1;
    elseif PulseLength == 500
        SvOffset = 0.8;
    elseif PulseLength == 700
        SvOffset = 0.5;
    elseif PulseLength == 900
        SvOffset = 0.3;
    elseif PulseLength == 1000
        SvOffset = 0.3;
    end
else % 38 kHz
    if PulseLength == 500
        SvOffset = 1.1;
    elseif PulseLength == 1000
        SvOffset = 0.7;
    end
end

end

% calc battery voltage from counts
function Volts = computeBattery(N)

USL5_BAT_CONSTANT = 2.4738E-4;
Volts = (N * (2.5/65536.) * (86.6 + 475.)/86.6);

end

% calc pressure from counts, then depth using inputted Salinity
function [Depth,Pressure] = computeDepth(N,Parameters,T)

Patm = 10.125;
g = 9.815;
Vin = 2.5 * (N/65535);
Pressure = Vin * Parameters.a1 + Parameters.a0 - Patm;
dens = sw_dens(Parameters.Salinity,T,Pressure);
Depth = Pressure*10000 / (dens * g);

end

function d = defaultULS6

d.NumXMLBytes = [];
d.NumPrevXMLBytes = [];
d.NumDataBytes = [];
d.FIRST_HEADER_RECORD = [];
d.HEADER_BYTES = [];
d.HEADER_NUM_RECORDS = [];
d.ProfileNumber = [];
d.SerialNumber = [];
d.date = [];
d.ACQ_STATUS = [];
d.BurstInt = [];
d.BASE_TIME = [];
d.PING_PERIOD = [];
d.PING_PERIOD_COUNTS = [];
d.PingPerProfile = [];
d.AvgPings = [];
d.NumAcqPings = [];
d.FIRST_PING = [];
d.LAST_PING = [];
d.DATA_ERROR = [];
d.OVER_RUN = [];
d.PHASE = [];
d.NumChan = [];
d.DigRate = [];
d.LockoutInd = [];
d.NumBins = [];
d.RangeSamples = [];
d.DataType = [];
d.PulseLength = [];
d.BOARD = [];
d.Freq = [];
d.NUM_SENSORS = [];
d.SENSOR_STATUS = [];
d.Ancillary = [];
d.GPS_DATE_TIME = [];
d.GPS_LAT_LONG = [];
d.LAST_HEADER_RECORD = [];
d.counts = [];
d.AD = [];
d.Date = [];
d.NumPrevDataBytes = [];
d.T = [];
d.Tx = [];
d.Ty = [];
d.cosTiltMag = [];
d.BatteryMain = [];
d.BatteryTx = [];
d.Depth = [];
d.Pressure = [];
d.Pavg = [];

end

function [CSVData, Success] = readCSV(Parameters)

    CSVData = [];
    Success = 0;
    if exist(Parameters.LoadCSV,"file")
        CSVData = readtable(Parameters.LoadCSV,'ReadVariableNames',false);
        Success = 1;
    else
        fprintf('Error: CSV file not found: %s\n',Parameters.LoadCSV);
        return;
    end


end

function d = defaultData(ii)

d.ProfileFlag = 'FD02';
d.ProfileNumber = ii;
d.SerialNumber = 0;
d.PingStatus = 0;
d.BurstInt = [];
d.Date = [];
d.DigRate = [];
d.LockoutInd = [];
d.NumBins = [];
d.RangeSamples = [];
d.PingPerProfile = [];
d.AvgPings = [];
d.NumAcqPings = [];
d.PingPeriod = [];
d.FirstLastPing = [];
d.DataType = [];
d.DataError = 0;
d.Phase = [];
d.Overrun = 0;
d.NumChan = 1;
d.Gain = [];
d.PulseLength = [];
d.BoardNum = [];
d.Freq = [];
d.SensorFlag = 1;
d.Ancillary = [];
d.AD = [];
d.counts = {[]};
d.T = [];
d.Tx = [];
d.Ty = [];
d.Depth = [];
d.Pressure = [];
d.Pavg = [];
d.cosTiltMag = [];
d.BatteryMain = [];
d.BatteryTx = [];

end