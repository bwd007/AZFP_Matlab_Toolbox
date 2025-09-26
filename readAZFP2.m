function [Data,Success] = readAZFP2(fidAZFP,ii,Data,Parameters)

% initialize variables
Success = 1;
FileType = 'FD02'; %specify profile data filetype

% read the entire hourly AZFP file
AllData = fread(fidAZFP,'uint8','ieee-be');

% start to pull out data
Pos = 1;
try
for(ii=1:9999)
    Flag = dec2hex(swapbytes(typecast(uint8(AllData(Pos:Pos+1)),'uint16')));Pos=Pos+2;
    if(~strcmpi(Flag,FileType)&&ii==1)
        Success = 0;
        if(~feof(fidAZFP))
            fprintf('Error: Unknown file type: check that the correct XML file was loaded\n');
        end
        return;
    elseif(~strcmpi(Flag,FileType)) % end of data
        return;
    end
    Data(ii).ProfileFlag = Flag;
    Data(ii).ProfileNumber = double(swapbytes(typecast(uint8(AllData(Pos:Pos+1)),'uint16')));Pos=Pos+2;
    Data(ii).SerialNumber = double(swapbytes(typecast(uint8(AllData(Pos:Pos+1)),'uint16')));Pos=Pos+2;
    Data(ii).PingStatus = double(swapbytes(typecast(uint8(AllData(Pos:Pos+1)),'uint16')));Pos=Pos+2;
    Data(ii).BurstInt = double(swapbytes(typecast(uint8(AllData(Pos:Pos+3)),'uint32')));Pos=Pos+4;
    date = double(swapbytes(typecast(uint8(AllData(Pos:Pos+13)),'uint16')));Pos=Pos+14; % YY MM DD hh mm ss hh
    Data(ii).Date = datenum(date(1),date(2),date(3),date(4),date(5),date(6)+date(7)/100);
    Data(ii).DigRate = double(swapbytes(typecast(uint8(AllData(Pos:Pos+7)),'uint16')));Pos=Pos+8; % digitization rate for each channel
    Data(ii).LockoutInd = double(swapbytes(typecast(uint8(AllData(Pos:Pos+7)),'uint16')));Pos=Pos+8; % lockout index for each channel
    Data(ii).NumBins = double(swapbytes(typecast(uint8(AllData(Pos:Pos+7)),'uint16')));Pos=Pos+8; % number of bins for each channel
    Data(ii).RangeSamples = double(swapbytes(typecast(uint8(AllData(Pos:Pos+7)),'uint16')));Pos=Pos+8; % range samples per bin for each channel
    Data(ii).PingPerProfile = double(swapbytes(typecast(uint8(AllData(Pos:Pos+1)),'uint16')));Pos=Pos+2; % number of pings per profile
    Data(ii).AvgPings = double(swapbytes(typecast(uint8(AllData(Pos:Pos+1)),'uint16')));Pos=Pos+2; % flag to indicate if pings avg in time
    Data(ii).NumAcqPings = double(swapbytes(typecast(uint8(AllData(Pos:Pos+1)),'uint16')));Pos=Pos+2; % # pings acquired in this burst
    Data(ii).PingPeriod = double(swapbytes(typecast(uint8(AllData(Pos:Pos+1)),'uint16')));Pos=Pos+2; % ping period in seconds
    Data(ii).FirstLastPing = double(swapbytes(typecast(uint8(AllData(Pos:Pos+3)),'uint16')));Pos=Pos+4;
    Data(ii).DataType = double(swapbytes(typecast(uint8(AllData(Pos:Pos+3)),'uint8')));Pos=Pos+4; % datatype for each channel: 1=Avg Data (5bytes), 0=raw (2bytes)
    Data(ii).DataError = double(swapbytes(typecast(uint8(AllData(Pos:Pos+1)),'uint16')));Pos=Pos+2;% error # is an error occurred
    Data(ii).Phase = double(swapbytes(typecast(uint8(AllData(Pos)),'uint8')));Pos=Pos+1; % phase # used to acquire this profile
    Data(ii).Overrun = double(swapbytes(typecast(uint8(AllData(Pos)),'uint8')));Pos=Pos+1; % 1 if an over run occurred
    Data(ii).NumChan = double(swapbytes(typecast(uint8(AllData(Pos)),'uint8')));Pos=Pos+1; % 1,2,3 or 4 (could acquire only 1 channel)
    Data(ii).Gain = double(swapbytes(typecast(uint8(AllData(Pos:Pos+3)),'uint8')));Pos=Pos+5; % gain chan 1-4
    %fread(fidAZFP,1,'uint8','ieee-be'); %spare chan
    Data(ii).PulseLength = double(swapbytes(typecast(uint8(AllData(Pos:Pos+7)),'uint16')));Pos=Pos+8; % pulselength chan 1-4 uS
    Data(ii).BoardNum = double(swapbytes(typecast(uint8(AllData(Pos:Pos+7)),'uint16')));Pos=Pos+8; % the board the data came from chan 1-4
    Data(ii).Freq = double(swapbytes(typecast(uint8(AllData(Pos:Pos+7)),'uint16')));Pos=Pos+8;% freq Hz for chan 1-4
    Data(ii).SensorFlag = double(swapbytes(typecast(uint8(AllData(Pos:Pos+1)),'uint16')));Pos=Pos+2;% Flag to indicate if pressure sensor or temper sensor is avail
    Data(ii).Ancillary = double(swapbytes(typecast(uint8(AllData(Pos:Pos+9)),'uint16')));Pos=Pos+10; % Tilt-X, Y, Battery, Pressure, Temperature
    Data(ii).AD = double(swapbytes(typecast(uint8(AllData(Pos:Pos+3)),'uint16')));Pos=Pos+4; % AD chan 6 and 7
    
    % read in the data, bytes depend on avg or raw, # channels 1 up to 4
    for(jj=1:Data(ii).NumChan) % might have 4 freq but only 1 was acquired
        if(Data(ii).DataType(jj)) % averaged data = 32 bit summed up linear scale data followed by 8 bit overflow counts
            if(Data(ii).AvgPings)
                divisor = Data(ii).PingPerProfile * Data(ii).RangeSamples(jj);
            else
                divisor = Data(ii).RangeSamples(jj);
            end
            %ls = fread(fidAZFP,Data(ii).NumBins(jj),'uint32','ieee-be'); %linearsum
            ls = double(swapbytes(typecast(uint8(AllData(Pos:Pos+Data(ii).NumBins(jj)*4-1)),'uint32')));Pos=Pos+Data(ii).NumBins(jj)*4;
            %lso = fread(fidAZFP,Data(ii).NumBins(jj),'uchar','ieee-be'); %linearsumoverflow            
            lso = double(swapbytes(AllData(Pos:Pos+Data(ii).NumBins(jj)-1)));Pos=Pos+Data(ii).NumBins(jj);
            v = (ls + lso*4294967295)/divisor;
            v = (log10(v)-2.5)*(8*65535)*Parameters.DS(jj);
            v(isinf(v)) = 0;
            Data(ii).counts{jj} = v;
        else % raw data = 16 bit values Log values
            %Data(ii).counts{jj} = fread(fidAZFP,Data(ii).NumBins(jj),'uint16','ieee-be');
            Data(ii).counts{jj} = double(swapbytes(typecast(uint8(AllData(Pos:Pos+Data(ii).NumBins(jj)-1)),'uint8')));Pos=Pos+Data(ii).NumBins(jj);
        end
    end
    
end

catch % end of data
    return;
end

end