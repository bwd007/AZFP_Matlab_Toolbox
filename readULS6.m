function [Data,Success,Parameters] = readULS6(fidAZFP,ii,Data,Parameters)

Success = 1;
% read uls6 header info constants
uls6HEADERINFO;

% matlab version check, need 2019b at least for 0x3A type entries
% a = ver('matlab');
% if(datetime(a.Date) < datetime('2020-01-01','InputFormat','uuuu-MM-dd'))
%     Success = 0;
%     fprintf('>= MATLAB 2019b required\n');
%     return;
% end

% read start of xml or data flag
Flag = dec2hex(fread(fidAZFP,1,'uint32'));
if(~strcmpi(Flag,xmlStartFlag) && ~strcmpi(Flag,dataStartFlag))
    Success = 0;
    if(~feof(fidAZFP))
        fprintf('Error Unknown file type: %s\n',Parameters.datafilename);
    end
    return;
end

% could be block > 1 data flag
if(strcmpi(Flag,xmlStartFlag))
    Data(ii).NumXMLBytes = fread(fidAZFP,1,'uint32');
    
    % read xml, parse xml string
    xmlString=fread(fidAZFP,Data(ii).NumXMLBytes,'*char');
    if(ii==1)
        Parameters = LoadAZFPxml('',xmlString,Parameters);
    end
    
    % read end of xml flag
    Flag = dec2hex(fread(fidAZFP,1,'uint32'));
    if(~strcmpi(Flag,xmlEndFlag))
        Success = 0;
        if(~feof(fidAZFP))
            fprintf('Error: error reading end of xml flag\n');
        end
        return;
    end
    
    % read num bytes for prev record
    Data(ii).NumPrevXMLBytes = fread(fidAZFP,1,'uint32');
    
    % data start flag
    Flag = dec2hex(fread(fidAZFP,1,'uint32'));
    if(~strcmpi(Flag,dataStartFlag))
        Success = 0;
        if(~feof(fidAZFP))
            fprintf('Error: error reading start of data flag\n');
        end
        return;
    end
end
% read size of profile data
Data(ii).NumDataBytes = fread(fidAZFP,1,'uint32');

info = ReadHeader(fidAZFP);
for(kk=1:length(RecordIDLookup))
    try
        var = char(RecordIDLookup(info.loc,2));
        %fprintf('%s \n',var);
        a = fread(fidAZFP,info.arraysize,info.type);
        % set variable, sorry cant figure out how without eval statement
        eval(['Data(ii).' var '=a;']);
        if(strcmp(var,'FIRST_HEADER_RECORD'))
            if(a ~= FIRST_HEADER_RECORD)
                Success = 0;
                fprintf('Error: expected FIRST_HEADER_RECORD Code\n');
                return;
            end
        elseif(strcmp(var,'LAST_HEADER_RECORD'))
            if(a ~= LAST_HEADER_RECORD)
                Success = 0;
                fprintf('Error: expected LAST_HEADER_RECORD Code\n');
                return;
            end
            break;
        end
        
        info = ReadHeader(fidAZFP);
    catch
        Success = 0 ;
        fprintf('Error: Unrecognized first header record\n');
        return;
    end      
end

% now read the profile data
for(jj=1:Data(ii).NumChan)
    if(Data(ii).DataType(jj)) % averaged data = 32 bit summed up linear scale data followed by 8 bit overflow counts
        if(Data(ii).AvgPings)
            divisor = Data(ii).PingPerProfile * Data(ii).RangeSamples(jj);
        else
            divisor = Data(ii).RangeSamples(jj);
        end
        ls = fread(fidAZFP,Data(ii).NumBins(jj),'uint32'); %linearsum
        lso = fread(fidAZFP,Data(ii).NumBins(jj),'uchar'); %linearsumoverflow
        v = (ls + lso*4294967295)/divisor;
        v = (log10(v)-2.5)*(8*65535)*Parameters.DS(jj);
        v(isinf(v)) = 0;
        Data(ii).counts{jj} = v;
    else % raw data = 16 bit values Log values
        Data(ii).counts{jj} = fread(fidAZFP,Data(ii).NumBins(jj),'uint16');
    end
end
% for compatability with <uls6 data
Data(ii).AD = Data(ii).Ancillary(6:7);
Data(ii).Date = datenum(Data(ii).date(1),Data(ii).date(2),Data(ii).date(3),Data(ii).date(4),Data(ii).date(5),Data(ii).date(6)+Data(ii).date(7)/100);

% data end flag
Flag = dec2hex(fread(fidAZFP,1,'uint32'));
if(~strcmpi(Flag,dataEndFlag))
    Success = 0;
    if(~feof(fidAZFP))
        fprintf('Error: error reading end of data flag\n');
    end
    return;
end

% read num bytes for prev record
Data(ii).NumPrevDataBytes = fread(fidAZFP,1,'uint32');
if(Data(ii).NumPrevDataBytes ~= Data(ii).NumDataBytes)
    Success = 0 ;
    fprintf('Error: NumPrevDataBytes and NumDataBytes should be equal\n');
    return;
end

if(Success)
 %   fprintf('Block %d: Success!! \n',ii);
end

%%%%%%%%%%%%%%%%%%%55
function info = ReadHeader(fidAZFP)

% read uls6 header info constants
uls6HEADERINFO;

RecordCode = fread(fidAZFP,1,'uint16');
info.required = bin2dec(num2str(bitget(RecordCode,16)));

% bit mask RECORD_DATA_TYPE_MASK % requires MATLAB 2019b+
type = '';
RecordDataType = bitand(RecordCode,RECORD_DATA_TYPE_MASK);
if(RecordDataType==0x0020)
    type = 'uint16';
elseif(RecordDataType==0x0040)
    type = 'int32';
elseif(RecordDataType==0x0060)
    type = 'uint32';
elseif(RecordDataType==0x0080)
    type = 'int64';
elseif(RecordDataType==0x00A0)
    type = 'uint64';
elseif(RecordDataType==0x00C0)
    type = 'double';
elseif(RecordDataType==0x0020)
    type = 'uint16';
else
    Success = 0;
    fprintf('Error: Unrecognized Data Type Code\n');
    return;
end

%Record ID can be retrieved from the Record Code using the bit mask
% CODE_BITS_MASK and shifting 8 bits right.
RecordID = bitshift(bitand(RecordCode,CODE_BITS_MASK),-8);
info.type = type;
info.loc = find(ID==RecordID);
info.loc = info.loc(1);
info.bits = bitand(RecordCode,TYPE_BITS_MASK);
info.arraysize = bitand(RecordCode,ARRAY_BITS_MASK)+1;

%fprintf('Type = %s Req = %d Size=%d ',type,info.required,info.arraysize);


