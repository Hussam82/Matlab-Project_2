
fname = 'inputdata.txt';
fid = fopen(fname);
raw = fread(fid,inf);
input_binary = dec2bin(raw,8);

fname = 'config.json';
fid = fopen(fname);
raw = fread(fid,inf);
str = char(raw');
fclose(fid);
config = jsondecode(str);

UART_index = 0;
USB_index = 0;
for i = 1:length(config)
    if(strcmp( char( config(i).protocol_name ) , 'UART'  ) == 1)
        UART_index = i;
    elseif(strcmp( char( config(i).protocol_name ) , 'USB'  ) == 1)
            USB_index = i;
    else 
        disp('Invalid Protocol name, Please check the config file');
    end
end


input_size = size(input_binary);
input_size = input_size(1);

%UART
if(UART_index > 0)
    UART_parity_even = 0;
    UART_parity_odd = 0;
    
    if(strcmp( char( config(UART_index).parameters.parity ) , 'none'  ) == 1)
        UART_num_parity_bit = 0;
    elseif(strcmp( char( config(UART_index).parameters.parity ) , 'even'  ) == 1)
        UART_num_parity_bit = 1;
        UART_parity_even = 1;
    elseif(strcmp( char( config(UART_index).parameters.parity ) , 'odd'  ) == 1)
        UART_num_parity_bit = 1;
        UART_parity_odd = 1;
    end
    
    
    
    UART_output_binary = [];

    UART_num_cols = 1;
  
    UART_over_head_bits = (1 + config(UART_index).parameters.stop_bits + UART_num_parity_bit) *input_size(1);

    UART_num_bits = UART_over_head_bits + (input_size(1) * 8);

    %==================================================================================================================================%
    %>>>>>>>>>>>>>>>>>>>>>>>>>>>> If you need to Get only two frames, Put 2 instead of input_size(1) <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<%
    %==================================================================================================================================%
    for i = 1:input_size(1)
        %Insert Start Bit
        UART_ones = 0;
        UART_output_binary(1, UART_num_cols) = 0;
        UART_num_cols = UART_num_cols + 1;
        %Insert Data
        for j = 1:8
            if(input_binary(i, j) == '1')
                UART_ones = UART_ones + 1;
            end
            UART_output_binary(1, UART_num_cols) = input_binary(i, j) - 48;
            UART_num_cols = UART_num_cols + 1;
        end
        %Insert Parity Bit
        if(UART_parity_even == 1)
            if(mod(UART_ones,2) == 0)
                UART_output_binary(1, UART_num_cols) = 0;
            else
                 UART_output_binary(1, UART_num_cols) = 1;
            end
            UART_num_cols = UART_num_cols + 1;
        end
        if(UART_parity_odd == 1)
            if(mod(UART_ones,2) == 1)
                 UART_output_binary(1, UART_num_cols) = 0;
            else
                 UART_output_binary(1, UART_num_cols) = 1;
            end
            UART_num_cols = UART_num_cols + 1;
        end
        %Insert stop bit 
        UART_output_binary(1, UART_num_cols) = 1;
        UART_num_cols = UART_num_cols + 1;
        if(config(UART_index).parameters.stop_bits == 2)
            UART_output_binary(1, UART_num_cols) = 1;
            UART_num_cols = UART_num_cols + 1;
        end
    end

    UART_tx_time = length(UART_output_binary) * config(UART_index).parameters.bit_duration;%

    UART_over_head = UART_over_head_bits / UART_num_bits;

    UART_effeciency = 1 - UART_over_head;

    subplot(2,1,1);
    stairs(UART_output_binary);
    ylim([0 2]);
    %xlim([0 23]);
    xlabel('Number of bits * 100 us', 'color' ,'b');
    title('UART');
end
%==========================================================================================================================
if(USB_index > 0)
    input_file_packets = ceil(input_size / config(USB_index).parameters.payload);
    input_file_extra = (ceil(input_size) / config(USB_index).parameters.payload - floor(input_size / config(USB_index).parameters.payload)) * config(USB_index).parameters.payload;
    if(input_file_extra > 0)
        input_file_extra = 128 - input_file_extra;
    end
    USB_EOP_bits = 2;
    USB_extra_zeros = 0;
    USB_num_cols = 1;
    USB_num_rows = 1;
    %==================================================================================================================================%
    %>>>>>>>>>>>>>>>>>>>>>>>>>>>> If you need to Get only two packets, Put 2 instead of input_file_packets<<<<<<<<<<<<<<<<<<<<<<<<<<<<<%
    %==================================================================================================================================%
    for USB_num_packets = 1:input_file_packets
        % Insert SOP 8 bits
        for col = 1:8
            USB_output_binary(1, USB_num_cols) = config(USB_index).parameters.sync_pattern(1, col);
            USB_num_cols = USB_num_cols + 1;
        end
        % Inert PID  8 bits    
        PID = dec2bin(USB_num_packets);
        zeros_ = zeros(1, 4 - length(PID));
        zeros_ = int2str(zeros_);
        zeros_ = zeros_(find(~isspace(zeros_)));
        PID = cat(2,zeros_ ,PID);
        PID_NOT = not(PID - 48);
        PID_NOT = int2str(PID_NOT);
        PID_NOT = PID_NOT(find(~isspace(PID_NOT)));
        USB_PID = cat(2,PID_NOT,PID);
        for col = 1:8
         USB_output_binary(1, USB_num_cols) = USB_PID(1, col) ;
         USB_num_cols = USB_num_cols + 1;
        end
        % Insert address line 11 bits
        for col = 1:11
            USB_output_binary(1, USB_num_cols) = config(USB_index).parameters.dest_address(1, col);%
            USB_num_cols = USB_num_cols + 1;
        end
        % Insert Data with stuffed bits %
        for row = 1:config(USB_index).parameters.payload
            for col = 1:8
                if(USB_num_rows <= input_size(1))
                    USB_output_binary(1, USB_num_cols) = input_binary(USB_num_rows, col);
                else
                    USB_output_binary(1, USB_num_cols) ='0';
                    USB_extra_zeros = USB_extra_zeros + 1;
                end
                USB_num_cols = USB_num_cols + 1;
            end
            USB_num_rows = USB_num_rows + 1;
        end
        USB_output_binary(1, USB_num_cols) = '0';
        USB_num_cols = USB_num_cols + 1;
        USB_output_binary(1, USB_num_cols) = '0';
        USB_num_cols = USB_num_cols + 1;
    end
    USB_num_one = 0;
    index = 1;
    USB_stuffed_bits = 0;
    for USB_num_bits = 1 : length(USB_output_binary)
        if(USB_output_binary(1,USB_num_bits) == '1')
            USB_num_one = USB_num_one + 1;
            if(USB_num_one == 6)
                USB_output_binary_wStuffedBits(1, index) = 0;
                index = index + 1;
                USB_num_one = 0;
                USB_num_bits = USB_num_bits + 1;
                USB_output_binary_wStuffedBits(1, index) = 1;
                index = index + 1;
                USB_stuffed_bits = USB_stuffed_bits + 1;
            else
                USB_output_binary_wStuffedBits(1, index) = USB_output_binary(1, USB_num_bits);
                index = index + 1;    
            end
        else
            USB_num_one = 0;
            USB_output_binary_wStuffedBits(1, index) = USB_output_binary(1, USB_num_bits);
            index = index + 1;
        end
    end

    USB_output_NRZI = [string('1')];

     for USB_num_bits = 1:length(USB_output_binary_wStuffedBits)
         if(USB_output_binary_wStuffedBits(USB_num_bits) == '1')
         USB_output_NRZI(end + 1) = char(USB_output_NRZI(end)) ;
         else
             USB_output_NRZI(end + 1) = '1' -  char(USB_output_NRZI(end));
         end
     end

 USB_over_head_bits_per_packet = (length(config(USB_index).parameters.sync_pattern) + config(USB_index).parameters.pid + length(config(USB_index).parameters.dest_address) + USB_EOP_bits) * input_file_packets;%

 USB_over_head_bits =  USB_over_head_bits_per_packet + USB_extra_zeros + USB_stuffed_bits;

 USB_tx_time = config(USB_index).parameters.bit_duration * (length(USB_output_NRZI) - 1);%

 USB_over_head = USB_over_head_bits / (config(USB_index).parameters.payload * 8 * input_file_packets);%

 USB_effeciency = 1 - USB_over_head;
    
 subplot(2,1,2);
 stairs(USB_output_NRZI);
 ylim([0 2]);
 xlabel('number of bits * 100 us', 'color' ,'b');
 title('USB');
end
% Create a JSON file
jsonFile1 = struct( 'protocol_name', 'UART', 'outputs' ,struct( 'total_tx_time', UART_tx_time, 'overhead', UART_over_head, 'efficiency', UART_effeciency ) );
jsonFile2 = struct( 'protocol_name', 'USB', 'outputs' ,struct( 'total_tx_time', USB_tx_time, 'overhead', USB_over_head, 'efficiency', USB_effeciency ) );
jsonArray = [ jsonFile1, jsonFile2 ];
jsonOP = jsonencode( jsonArray );
%Press new line after each '{'
jsonOP = strrep( jsonOP, '{', sprintf( '\r\t{\r\t\t' ) );
%after each '}}' press new line before and in-between
jsonOP = strrep( jsonOP, '}}', sprintf( '\r\t}\r\r\t}' ) );
%Press new line after each ','
jsonOP = strrep( jsonOP, ',', sprintf( '\r\t\t,' ) );
%after each '}]' press new line before and in-between
jsonOP = strrep( jsonOP, '}]', sprintf( '}\r]\t\t' ) );
fid = fopen( 'output_new.json', 'w' );
fprintf( fid, jsonOP );
fclose( fid );
%============================================================================================================================
