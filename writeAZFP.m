function Success = writeAZFP(fidAZFP, Data, Parameters)
%WRITEAZFP  Write AZFP profile data in the same binary layout as readAZFP.
%
%   Success = writeAZFP(fidAZFP, Data, Parameters)
%
%   - fidAZFP: file ID opened for writing, preferably with:
%       fopen(filename,'w','ieee-be');
%   - Data   : scalar struct or struct array with the fields created by readAZFP
%   - Parameters: struct with field DS (as used in readAZFP for averaged data)
%
%   Returns:
%       Success = 1 on success, 0 if any error occurs.
%
%   NOTE on averaged data (DataType ~= 0):
%   The original file stores 32-bit linear sums and 8-bit overflow counts.
%   readAZFP converts those to Data.counts{jj} via a log transform and
%   discards ls/lso. Here we *approximately* reconstruct ls/lso by inverting
%   the transform and setting lso = 0. Raw data (DataType==0) is written
%   exactly as 16-bit values.
% Example:
% fid = fopen('23021500_corrN.01A', 'w', 'ieee-be');
% if fid < 0
%     error('Could not open output file');
% end
% Success = writeAZFP(fid, Data, Parameters);
% fclose(fid);

Success = 1;

try
    if ~isstruct(Data)
        error('Data must be a struct or struct array.');
    end

    for ii = 1:numel(Data)
        d = Data(ii);

        %% ---- Header / meta fields (match readAZFP order & types) ----

        % ProfileFlag: stored as uint16 that dec2hex -> 'FD02'
        if isfield(d, 'ProfileFlag')
            if ischar(d.ProfileFlag) || isstring(d.ProfileFlag)
                flagWord = uint16(hex2dec(char(d.ProfileFlag)));
            else
                flagWord = uint16(d.ProfileFlag);
            end
        else
            flagWord = uint16(hex2dec('FD02'));
        end
        fwrite(fidAZFP, flagWord, 'uint16');

        fwrite(fidAZFP, uint16(d.ProfileNumber), 'uint16');   % ProfileNumber
        fwrite(fidAZFP, uint16(d.SerialNumber),  'uint16');   % SerialNumber
        fwrite(fidAZFP, uint16(d.PingStatus),    'uint16');   % PingStatus
        fwrite(fidAZFP, uint32(d.BurstInt),      'uint32');   % BurstInt

        % Date: 7*uint16 (YY MM DD hh mm ss hh) as in readAZFP
        % Data.Date is datenumber
        [yr, mo, dy, hr, mn, sc] = datevec(d.Date);
        sec_int = floor(sc);
        hund    = round((sc - sec_int) * 100); % hundredths of a second
        date_arr = uint16([yr mo dy hr mn sec_int hund]);
        fwrite(fidAZFP, date_arr, 'uint16');

        fwrite(fidAZFP, uint16(d.DigRate(:)),      'uint16'); % 4*uint16
        fwrite(fidAZFP, uint16(d.LockoutInd(:)),   'uint16'); % 4*uint16
        fwrite(fidAZFP, uint16(d.NumBins(:)),      'uint16'); % 4*uint16
        fwrite(fidAZFP, uint16(d.RangeSamples(:)), 'uint16'); % 4*uint16

        fwrite(fidAZFP, uint16(d.PingPerProfile), 'uint16');  % PingPerProfile
        fwrite(fidAZFP, uint16(d.AvgPings),       'uint16');  % AvgPings
        fwrite(fidAZFP, uint16(d.NumAcqPings),    'uint16');  % NumAcqPings
        fwrite(fidAZFP, uint16(d.PingPeriod),     'uint16');  % PingPeriod

        fwrite(fidAZFP, uint16(d.FirstLastPing(:)), 'uint16'); % 2*uint16

        fwrite(fidAZFP, uint8(d.DataType(:)), 'uint8');       % 4*uint8 DataType
        fwrite(fidAZFP, uint16(d.DataError),  'uint16');      % DataError
        fwrite(fidAZFP, uint8(d.Phase),       'uint8');       % Phase
        fwrite(fidAZFP, uint8(d.Overrun),     'uint8');       % Overrun
        fwrite(fidAZFP, uint8(d.NumChan),     'uint8');       % NumChan

        fwrite(fidAZFP, uint8(d.Gain(:)),   'uint8');         % 4*uint8 Gain
        fwrite(fidAZFP, uint8(0),           'uint8');         % spare chan (1 byte)

        fwrite(fidAZFP, uint16(d.PulseLength(:)), 'uint16');  % 4*uint16
        fwrite(fidAZFP, uint16(d.BoardNum(:)),    'uint16');  % 4*uint16
        fwrite(fidAZFP, uint16(d.Freq(:)),        'uint16');  % 4*uint16

        fwrite(fidAZFP, uint16(d.SensorFlag), 'uint16');      % SensorFlag
        fwrite(fidAZFP, uint16(d.Ancillary(:)), 'uint16');    % 5*uint16
        fwrite(fidAZFP, uint16(d.AD(:)),        'uint16');    % 2*uint16

        %% ---- Data block per channel ----

        nChan = double(d.NumChan);
        for jj = 1:nChan
            % Ensure counts exist
            if numel(d.counts) < jj || isempty(d.counts{jj})
                error('Data.counts{%d} is missing or empty.', jj);
            end

            % Ensure NumBins matches length (or truncate/pad)
            numBins = double(d.NumBins(jj));
            v = d.counts{jj}(:);
            if numel(v) < numBins
                % pad with zeros if needed
                v(numBins,1) = 0;
            elseif numel(v) > numBins
                v = v(1:numBins);
            end

            if d.DataType(jj) ~= 0
                %% Averaged data path (DataType == 1)
                % Original reader:
                %   if AvgPings
                %       divisor = PingPerProfile * RangeSamples(jj);
                %   else
                %       divisor = RangeSamples(jj);
                %   end
                %   v = (ls + lso*4294967295)/divisor;
                %   v = (log10(v)-2.5)*(8*65535)*Parameters.DS(jj);
                %
                % Here we approximately invert to get ls (uint32) and lso (uint8=0).

                if d.AvgPings
                    divisor = double(d.PingPerProfile) * double(d.RangeSamples(jj));
                else
                    divisor = double(d.RangeSamples(jj));
                end

                DS = double(Parameters.DS(jj));
                v   = double(v);

                % invert the transform:
                % v_lin = 10.^(v/(8*65535*DS) + 2.5);
                v_lin = 10.^((v ./ (8*65535*DS)) + 2.5);
                S     = v_lin * divisor;          % ~ ls + lso*2^32-1

                % avoid nonpositive / NaN
                S(~isfinite(S) | S <= 0) = 1;

                % approximate with lso=0, ls=round(S)
                ls  = uint32(round(S));
                lso = uint8(zeros(size(ls)));

                fwrite(fidAZFP, ls,  'uint32');   % linearsum
                fwrite(fidAZFP, lso, 'uint8');    % overflow counts

            else
                %% Raw data path (DataType == 0): 16-bit log values
                fwrite(fidAZFP, uint16(v), 'uint16');
            end
        end
    end

catch ME
    warning('writeAZFP:Error', 'Error writing AZFP data: %s', ME.message);
    Success = 0;
end

end
