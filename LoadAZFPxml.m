function Parameters = LoadAZFPxml(pathname,xmlfilename,Parameters)

% Parameters = LoadAZFPxml(pathname,xmlfilename,Parameters,LoadFromFile)
% pathname = xml pathname, can be empty
% xmlfilename = xml filename, filename ore pass in string of xml data (uls6)
% Parameters = pas in existing Parameters, new Parameters from xml passed
% out

try
    if(strcmp(xmlfilename(1),'<'))
        xmlStream = java.io.StringBufferInputStream(xmlfilename);
        xDoc = xmlread(xmlStream);
    else
        if(~isempty(pathname))
            xDoc = xmlread([pathname '/' xmlfilename]);
        else
            xDoc = xmlread(xmlfilename);
        end
    end
catch
    msgbox('Error: bad XML file format','Error');
    error('Bad XML format');
end

Parameters(1).NumFreq = str2double(xDoc.getElementsByTagName('NumFreq').item(0).getFirstChild.getData);
Parameters(1).SerialNumber = str2double(xDoc.getElementsByTagName('SerialNumber').item(0).getFirstChild.getData);
try
    Parameters(1).BurstInterval = str2double(xDoc.getElementsByTagName('BurstInterval').item(0).getFirstChild.getData);
    Parameters(1).PingsPerBurst = str2double(xDoc.getElementsByTagName('PingsPerBurst').item(0).getFirstChild.getData);
    Parameters(1).AverageBurstPings = str2double(xDoc.getElementsByTagName('AverageBurstPings').item(0).getFirstChild.getData);
catch
    Parameters(1).BurstInterval = 1;
    Parameters(1).PingsPerBurst = 1;
    Parameters(1).AverageBurstPings = 1;
end

% temperature coeff
Parameters(1).ka = str2double(xDoc.getElementsByTagName('ka').item(0).getFirstChild.getData);
Parameters(1).kb = str2double(xDoc.getElementsByTagName('kb').item(0).getFirstChild.getData);
Parameters(1).kc = str2double(xDoc.getElementsByTagName('kc').item(0).getFirstChild.getData);
Parameters(1).A = str2double(xDoc.getElementsByTagName('A').item(0).getFirstChild.getData);
Parameters(1).B = str2double(xDoc.getElementsByTagName('B').item(0).getFirstChild.getData);
Parameters(1).C = str2double(xDoc.getElementsByTagName('C').item(0).getFirstChild.getData);

% tilts
Parameters(1).X_a = str2double(xDoc.getElementsByTagName('X_a').item(0).getFirstChild.getData);
Parameters(1).X_b = str2double(xDoc.getElementsByTagName('X_b').item(0).getFirstChild.getData);
Parameters(1).X_c = str2double(xDoc.getElementsByTagName('X_c').item(0).getFirstChild.getData);
Parameters(1).X_d = str2double(xDoc.getElementsByTagName('X_d').item(0).getFirstChild.getData);
Parameters(1).Y_a = str2double(xDoc.getElementsByTagName('Y_a').item(0).getFirstChild.getData);
Parameters(1).Y_b = str2double(xDoc.getElementsByTagName('Y_b').item(0).getFirstChild.getData);
Parameters(1).Y_c = str2double(xDoc.getElementsByTagName('Y_c').item(0).getFirstChild.getData);
Parameters(1).Y_d = str2double(xDoc.getElementsByTagName('Y_d').item(0).getFirstChild.getData);

Parameters(1).SensorsFlag = str2double(xDoc.getElementsByTagName('SensorsFlag').item(0).getFirstChild.getData);

% Pressure
Parameters(1).a0 = str2double(xDoc.getElementsByTagName('a0').item(0).getFirstChild.getData);
Parameters(1).a1 = str2double(xDoc.getElementsByTagName('a1').item(0).getFirstChild.getData);

% get parameters for each transducer freq
for(jj=1:Parameters(1).NumFreq)
    Parameters(1).Freq(jj) = str2double(xDoc.getElementsByTagName('kHz').item(jj-1).getFirstChild.getData);
    try
        Parameters(1).DigRate(jj) = str2double(xDoc.getElementsByTagName('DigRate').item(jj-1).getFirstChild.getData);
        Parameters(1).LockOutIndex(jj) = str2double(xDoc.getElementsByTagName('LockOutIndex').item(jj-1).getFirstChild.getData);
    catch
        Parameters(1).DigRate(jj) = 64000;
        Parameters(1).LockOutIndex(jj) = 0;
    end
    try
        Parameters(1).Gain(jj) = str2double(xDoc.getElementsByTagName('Gain').item(jj-1).getFirstChild.getData);
    catch
        Parameters(1).Gain(jj) = 1;
    end
    Parameters(1).DS(jj) = str2double(xDoc.getElementsByTagName('DS').item(jj-1).getFirstChild.getData);
    Parameters(1).EL(jj) = str2double(xDoc.getElementsByTagName('EL').item(jj-1).getFirstChild.getData);
    Parameters(1).TVR(jj) = str2double(xDoc.getElementsByTagName('TVR').item(jj-1).getFirstChild.getData);
    Parameters(1).VTX(jj) = str2double(xDoc.getElementsByTagName('VTX0').item(jj-1).getFirstChild.getData);
    Parameters(1).BP(jj) = str2double(xDoc.getElementsByTagName('BP').item(jj-1).getFirstChild.getData);
end

% save Phase info
try
    Parameters(1).NumPhases = str2double(xDoc.getElementsByTagName('NumPhases').item(0).getFirstChild.getData);


    % get parameters for each phase
    for jj=1:Parameters(1).NumPhases
        % StartDate convert from unix time, use jj=1 since jj=0 is main
        % startdate
        Parameters(1).PhaseStart(jj,1) = datenum(datetime(str2double(xDoc.getElementsByTagName('StartDate').item(jj).getFirstChild.getData),'ConvertFrom','posixtime'));
        Parameters(1).BurstIntervalPhase(jj,1) = str2double(xDoc.getElementsByTagName('BurstInterval').item(jj-1).getFirstChild.getData);
        Parameters(1).PingsPerBurstPhase(jj,1) = str2double(xDoc.getElementsByTagName('PingsPerBurst').item(jj-1).getFirstChild.getData);
        Parameters(1).AverageBurstPingsPhase(jj,1) = str2double(xDoc.getElementsByTagName('AverageBurstPings').item(jj-1).getFirstChild.getData);
        for ii=1:Parameters(1).NumFreq
            Parameters(1).AcquireFrequencyPhase(jj,ii) = str2double(xDoc.getElementsByTagName('AcquireFrequency').item((ii-1)+(jj-1)*Parameters(1).NumFreq).getFirstChild.getData);
            Parameters(1).PulseLenPhase(jj,ii) = str2double(xDoc.getElementsByTagName('PulseLen').item((ii-1)+(jj-1)*Parameters(1).NumFreq).getFirstChild.getData);
            Parameters(1).DigRatePhase(jj,ii) = str2double(xDoc.getElementsByTagName('DigRate').item((ii-1)+(jj-1)*Parameters(1).NumFreq).getFirstChild.getData);
            Parameters(1).RangeSamplesPhase(jj,ii) = str2double(xDoc.getElementsByTagName('RangeSamples').item((ii-1)+(jj-1)*Parameters(1).NumFreq).getFirstChild.getData);
            Parameters(1).RangeAveragingSamplesPhase(jj,ii) = str2double(xDoc.getElementsByTagName('RangeAveragingSamples').item((ii-1)+(jj-1)*Parameters(1).NumFreq).getFirstChild.getData);
        end
    end
catch
    Parameters(1).NumPhases = 1;
end


