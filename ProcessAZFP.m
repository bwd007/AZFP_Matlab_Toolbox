function [Output,Par,PavgArr,fig1] = ProcessAZFP(Parameters)

% ProcessAZFP.m run as:
% [Output,Par,PavgArr,fig1] = ProcessAZFP(Parameters);
%
% Inputs can be in any order or omitted and the defaults will be used:
% ProcDir = 0; % 1 will prompt for an entire directory to process
%   = 0 will prompt to load individual files in a directory
% datafilename = ''; % prompt for hourly AZFP file(s) to load
% xmlfilename = ''; % prompt for XML filename if no XML file exists in the directory
% Salinity = 35; % Salinity in
% Bins2Avg = 10; % number of range bins to average
% Time2Avg = 60; % number of time values to average
% Pressure = 50; %in dbars (~ depth in meters)
% Plot = 0; % show an echogram plot for each channel
%
% Outputs are:
% Output: structured array with computed data with N, Sv and TS, averaged in range/time. Each
% freq stored in Output(1), Output(2) etc
% Parameters: the instrument parameters from the XML file
%exit

% Ver 1.3 September 2017
% written by Dave Billenness
% ASL Environmental Sciences Inc.
% 1-6703 Rajpur Place, Victoria, B.C., V8M 1Z5, Canada
% T: +1 (250) 656-0177 ext. 126
% E: dbillenness@aslenv.com
% w: http://www.aslenv.com/
% For any suggestions, comments, questions or collaboration, please contact me.

if ~nargin
    error('Must pass in a list of Parameters => [Output,Par] = ProcessAZFP(Parameters)');
end

% set up defaults
Parameters.ULS6 = 0; % is this uls6 data with embedded xml and diff data structure
Output = [];
DataOut = [];
Par = [];
ProcDir = 0;
xmlfilename = '';
xmlpathname = '';
datafilename = '';
Bins2Avg = 10;
StartRange = 0;
EndRange = 0;
Time2Avg = 60;
Pressure = 50;
Salinity = 35;
Plot = 0;
Channel = 1;
Value2Plot = 2;
NoiseFloor = 10000;
Orientation = 1;
UseTiltCorr = 0;
PavgArr = [];
LoadCSV = 0;
if isfield(Parameters,'ProcDir')
    ProcDir = Parameters(1).ProcDir;
end
if isfield(Parameters,'xmlfilename')
    xmlfilename = Parameters(1).xmlfilename;
end
if isfield(Parameters,'xmlpathname')
    xmlpathname = Parameters(1).xmlpathname;
end
if isfield(Parameters,'datafilename')
    datafilename = Parameters(1).datafilename;
end
if isfield(Parameters,'Bins2Avg')
    Bins2Avg = Parameters(1).Bins2Avg;
end
if isfield(Parameters,'StartRange')
    StartRange = Parameters(1).StartRange;
end
if isfield(Parameters,'EndRange')
    EndRange = Parameters(1).EndRange;
end
if isfield(Parameters,'Time2Avg')
    Time2Avg = Parameters(1).Time2Avg;
end
if isfield(Parameters,'Pressure')
    Pressure = Parameters(1).Pressure;
end
if isfield(Parameters,'Salinity')
    Salinity = Parameters(1).Salinity;
end
if isfield(Parameters,'Plot')
    Plot = Parameters(1).Plot;
end
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
if ~isfield(Parameters,'MultiSelect')
    Parameters(1).MultiSelect = 'on';
end
if isfield(Parameters,'LoadCSV')
    LoadCSV = 1;
end

if ProcDir == 1
    if ischar(ProcDir)
        if exist(ProcDir, 'dir') == 7
            dirname = ProcDir;
        else
            dirname = uigetdir('', 'Select AZFP directory');
        end
    else
        % select directory containing the hourly AZFP files to process
        dirname = uigetdir('', 'Select AZFP directory');
    end
    cd(dirname);
    % get a list of all of the AZFP files
    if ispc
        filelist = dir('**\*.0*'); %the extra dot is to ignore .evi Echoview files, this does not work on MAC OS
    else
        filelist = dir('*.0*'); % for MACOS
    end
    numfiles = length(filelist);
    % better? handling of multi phased data using time stamp 01A 01B files,
    % ***assumes filelist.date hasn't been modified
    [~,I] = sort(datenum({filelist.date}));
    f = char({filelist.name});
    d = char({filelist.folder});
    filelist = f(I,:);
    dirlist = d(I,:);
elseif ~LoadCSV
    if isempty(datafilename) %if no datafilename input, then prompt
        [filelist, dirname] = uigetfile('*.??A;*.??B;*.??C;*.??D;*.azfp;*.aps6', 'Select AZFP hourly file(s)','MultiSelect', Parameters(1).MultiSelect);
        if iscell(filelist) % multiple files selected
            numfiles = length(filelist);
        else %one file selected
            numfiles = size(filelist,1);
            if(~filelist)
                return;
            end
        end
        cd(dirname);
    else
        if ProcDir == 0
            dirname = pwd;
        elseif exist(ProcDir,'dir')
            dirname = ProcDir;
        else
            
        end
        numfiles = 1;
        filelist = datafilename;
    end
end
% check filename for uls6
if ProcDir == 1 % if proc an entire directory then the file list is in a structure
    fname = filelist(1,:);
elseif LoadCSV
    fname = Parameters.LoadCSV;
    dirname = pwd;
    numfiles = 1;
else
    if iscell(filelist) % multiple files selected
        fname = char(filelist(1));
    else %one file selected
        fname = char(filelist(1,:));
    end
end
if contains(fname,'azfp')
    Parameters.ULS6 = 1;
end
pathname = pwd;
if ~Parameters.ULS6
    if isempty(xmlfilename) % if a single xml file is in the directory then load it, otherwise prompt
        xmlfile = dir('*.xml');
        if length(xmlfile) == 1
            xmlfilename = char(xmlfile.name);
        end
    end
    if isempty(xmlfilename)
        % select an xml settings file
        [xmlfilename, xmlpathname] = uigetfile('*.xml', 'Select instrument coefficients file');    
    end
    Parameters = LoadAZFPxml(xmlpathname,xmlfilename,Parameters);
    Parameters(1).xmlfilename = xmlfilename;
    Parameters(1).xmlpathname = xmlpathname;
end

Output(1).Date = [];
Output(1).Tx = [];
Output(1).Ty = [];
Output(1).T = [];
Output(1).BatteryMain = [];
Output(1).BatteryTx = [];
Output(1).Depth = [];
Output(1).filename = {''};
Output(1).HourlyAvgTemp = [];
Output(1).SoundSpeed = [];
for ii = 1:numfiles
    if ProcDir == 1 % if proc an entire directory then the file list is in a structure
        fname = filelist(ii,:);
        cd(dirlist(ii,:));
    elseif ~LoadCSV
        if iscell(filelist) % multiple files selected
            fname = char(filelist(ii));
        else %one file selected
            fname = char(filelist(ii,:));
        end
    end
    [DataOut,Par,PavgArr] = LoadAZFP('Salinity',Salinity,'Bins2Avg',Bins2Avg,'StartRange',StartRange,'EndRange',EndRange,'Time2Avg',Time2Avg,'datafilename',fname,'Parameters',Parameters,'Pressure',Pressure);
    % check for an empty file and break
    if isempty(DataOut)
        if numfiles > 1
            break;
        else
            Output = [];
            return;
        end
    end
    for jj=1:DataOut(1).NumChan
        if ii==1
            Output(jj).N = [];
            Output(jj).Range = [];
            Output(jj).TiltCorrRange = [];
            Output(jj).Sv = [];
            Output(jj).TS = [];
            Output(jj).seaAbs = [];
        else
            % if DataOut(jj).N has a differnet number of columns compared to
            % the previous file (stored in Output(jj).N) then catch this and
            % return an error
            if size(DataOut(jj).N,2) ~= size(Output(jj).N,2)
                error('For a given freq - all files must have then same number of range bins');
            end
        end
        Output(jj).N(end+1:end+1+size(DataOut(jj).N,1)-1,:) = DataOut(jj).N;
        Output(jj).Range(end+1:end+1+size(DataOut(jj).Range,1)-1,:) = DataOut(jj).Range;
        Output(jj).TiltCorrRange(end+1:end+1+size(DataOut(jj).TiltCorrRange,1)-1,:) = DataOut(jj).TiltCorrRange;
        % check for bad tilt values
        if jj==1 && UseTiltCorr
            if mean(DataOut(jj).TiltCorrRange./DataOut(jj).Range) < 0.9 % this would be about 20 deg Tx and Ty tilts
                fprintf('** Warning: tilt correction is set to ON but the tilts are large ... check\n');
            end
        end
        Output(jj).Sv(end+1:end+1+size(DataOut(jj).Sv,1)-1,:) = DataOut(jj).Sv;
        Output(jj).TS(end+1:end+1+size(DataOut(jj).TS,1)-1,:) = DataOut(jj).TS;
        Output(jj).Freq = DataOut(jj).Freq;
        Output(jj).seaAbs(end+1:end+1+size(DataOut(jj).seaAbs,1)-1,:) = DataOut(jj).seaAbs;
    end
    Output(1).Date(end+1:end+1+size(DataOut(1).Date,1)-1,:) = DataOut(1).Date;
    Output(1).Tx(end+1:end+1+size(DataOut(1).Tx,1)-1,:) = DataOut(1).Tx;
    Output(1).Ty(end+1:end+1+size(DataOut(1).Ty,1)-1,:) = DataOut(1).Ty;
    Output(1).T(end+1:end+1+size(DataOut(1).T,1)-1,:) = DataOut(1).T;
    Output(1).BatteryMain(end+1:end+1+size(DataOut(1).BatteryMain,1)-1,:) = DataOut(1).BatteryMain;
    Output(1).BatteryTx(end+1:end+1+size(DataOut(1).BatteryTx,1)-1,:) = DataOut(1).BatteryTx;
    Output(1).Depth(end+1:end+1+size(DataOut(1).Depth,1)-1,:) = DataOut(1).Depth;
    Output(1).filename(ii) = {fname};
    Output(1).dirname = dirname;
    Output(1).HourlyAvgTemp(end+1:end+1+size(DataOut(1).HourlyAvgTemp,1)-1,:) = DataOut(1).HourlyAvgTemp;
    Output(1).SoundSpeed(end+1:end+1+size(DataOut(1).SoundSpeed,1)-1,:) = DataOut(1).SoundSpeed;
    Output(1).StartEndRangeNumBins = DataOut(1).StartEndRangeNumBins;
end

% save the avg to the Output variable
Output(1).Bins2Avg = Bins2Avg;
Output(1).Time2Avg = Time2Avg;
Output(1).BurstInt = DataOut(1).BurstInt;
Output(1).PingPerProfile = DataOut(1).PingPerProfile;
Output(1).NumAcqPings = DataOut(1).NumAcqPings;
Output(1).DataType = DataOut(1).DataType;
Output(1).PulseLength = DataOut(1).PulseLength;
Output(1).BinInc = DataOut(1).BinInc;
Output(1).TimeInc = DataOut(1).TimeInc;
% save s/n
Output(1).SerialNumber = DataOut(1).SerialNumber;

% Plot results, all channels. Plot just Sv, default NoiseFloor and
% Orientation. To plot Counts or TS, and to change orientation see PlotAZFP.m
if Plot && ~isempty(Output(1).Date)
    % plot N, Sv, or Ts
    fig1 = PlotAZFP(Output,Parameters);
end

