% Parameter description and the default value (if the value is omitted):
% >> ParametersAZFP;[Output,Par] = ProcessAZFP(Parameters);
%
% Ver 1.3 September 2017 
% written by Dave Billenness
% ASL Environmental Sciences Inc.
% 1-6703 Rajpur Place, Victoria, B.C., V8M 1Z5, Canada
% T: +1 (250) 656-0177 ext. 126
% E: dbillenness@aslenv.com 
% w: http://www.aslenv.com/ 
% For any suggestions, comments, questions or collaboration, please contact me.

% FILE LOADING AND AVERAGING:
% Parameters.ProcDir = 0; 1 will prompt for an entire directory to
% process, = 0 will prompt to load individual files in a directory
Parameters.ProcDir = 0;
Parameters.PavgArr = 0;

% Parameters.datafilename = ''; % '' will prompt for hourly AZFP
% file(s) to load, example '16010100.01A'
Parameters.datafilename = '';

% Parameters.xmlfilename = ''; % prompt for XML filename if no XML file exists 
% in the directory, example '15101614.XML'
Parameters.xmlfilename = '';

% Parameters.Salinity = 35; % Salinity in psu
Parameters.Salinity = 30;

% Parameters.Bins2Avg = 10; % number of range bins to average
Parameters.Bins2Avg = 1;
Parameters.StartRange = 0; % startbin for Sv average (in meters). Set to 0 to use Bins2Avg instead.
Parameters.EndRange = 0; % startbin for Sv average (in meters). Set to 0 to use Bins2Avg instead.

% Parameters.Time2Avg = 60; % number of time values to average
Parameters.Time2Avg = 1;

% Parameters.Pressure = 50; % in dbars (~ depth of instrument in meters). 
% This can be approximate and is used in the soundspeed and absorption calc
Parameters.Pressure = 40;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PLOTTING:
% Parameters.Plot = 1; % show a plot for each channel
Parameters.Plot = 1;

% Parameters.Channel: freq to plot #1-4, default 1
Parameters.Channel = 1;

% Parameters.Value2Plot = 2; 1,2,3,4,5 = Counts, Sv, TS, Temperature/Tilts, SvAvg time series from Parameters.StartRange to Parameters.EndRange, default 2
Parameters.Value2Plot = 2;

% Parameters.NoiseFloor = 10000; % for Sv and Ts plotting only, values
% with counts < NoiseFloor will be set to -150, can use individual values
% for eash frequency, ex. 'NoiseFloor',[10000; 11000; 10500; 12500]
% Default = 10000.
Parameters.NoiseFloor = [0 0 0 0];

% Parameters.Orientation = 0 instrument on bottom looking up (range bins), 1 at surface 
% looking down (depth bins). This changes the ydir on the echogram plots only. Default is 1.
Parameters.Orientation = 0;

% Parameters.UseTiltCorr = 0; Use the tilt corrected ranges for the echogram plots, 
% default 0. Will give a warning if the tilt magnitudes are unreasonable (> 20 deg)
Parameters.UseTiltCorr = 0;