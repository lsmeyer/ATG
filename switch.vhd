-- Title: Macrobloco que integra os componentes para implementação do switch de rede

-- Authors: Lucas Silva Meyer e Pedro Azevedo da Conceição

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity switch is
	generic(
		byte				:	positive := 8;
		ports_len			:	positive := 5;
		flags_size			:	positive := 6;
		counter_packet_size	: positive := 9
	);
	port(
		rst	: in std_logic;
		clk	: in std_logic;
		
		-- entrada interface AXI4-Stream
		S_AXIS_TDATA	:	in std_logic_vector(byte-1 downto 0);
		S_AXIS_TVALID	:	in std_logic;
		S_AXIS_TLAST	:	in std_logic;
		S_AXIS_TREADY	:	out std_logic;
		
		-- entrada de 5 bits que sinaliza porta de origem
		source_port		: in std_logic_vector(ports_len-1 downto 0);
		-- saída de 5 bits que sinaliza porta de destino
		dest_port		: out std_logic_vector(ports_len-1 downto 0);
		-- saída que representam as flags indicativas de erro, conexão e desconexão
		-- erros:
		-- packet length error, checksum error, seqnum error, destnation address not found
		flags				: out std_logic_vector(flags_size-1 downto 0);
		
		-- saída interface AXI4-Stream
		M_AXIS_TDATA	:	out std_logic_vector(byte-1 downto 0);
		M_AXIS_TVALID	:	out std_logic;
		M_AXIS_TLAST	:	out std_logic;
		M_AXIS_TREADY	:	in std_logic;
		
		-- saída de 16 bits que informa qual é o endereço de destino do pacote
		dest_address	: out std_logic_vector(2*byte-1 downto 0);
		
		-- saída de 16 bits que representa endereço de origem ou endereço do dispositivo
		-- que se conectou/desconectou
		source_address	: out std_logic_vector(2*byte-1 downto 0);

		-- sinais auxiliares para verificação da funcionalidade do switch
		checksum_header_p			: out std_logic_vector(2*byte-1 downto 0);
		seqnum_header_p				: out std_logic_vector(4*byte-1 downto 0);
		SYN_header_p, CLO_header_p	: out std_logic;
		protocol_header_p			: out std_logic_vector(byte-1 downto 0);
		dummy_header_p				: out std_logic_vector(2*byte-1 downto 0);
		source_address_header_p		: out std_logic_vector(2*byte-1 downto 0);
		dest_address_header_p		: out std_logic_vector(2*byte-1 downto 0);
		packlen_header_p			: out std_logic_vector(2*byte-1 downto 0);
		TREADY_header_p				: out std_logic;
		checksum_calc				: out std_logic_vector(2*byte-1 downto 0);
		packlen_calc				: out std_logic_vector(2*byte-1 downto 0);

		header_f_p					: out std_logic;
		d_table_f_p					: out std_logic;

		-- debug
		counter_db					: out std_logic_vector(counter_packet_size-1 downto 0);
		counter_h_db				: out std_logic_vector(counter_packet_size-1 downto 0);
		word_counter_db				: out std_logic_vector(1 downto 0);
		seqnum_calc					: out std_logic_vector(4*byte-1 downto 0);

		porta_0_p					: out std_logic_vector(2*byte-1 downto 0);
		porta_1_p					: out std_logic_vector(2*byte-1 downto 0);
		porta_2_p					: out std_logic_vector(2*byte-1 downto 0);
		porta_3_p					: out std_logic_vector(2*byte-1 downto 0);
		porta_4_p					: out std_logic_vector(2*byte-1 downto 0)
		);
end entity switch;

architecture switch_rtl of switch is

-- constant counter_packet_size	: positive := 9;

-- useless signal
signal TREADY_s					: std_logic;

-- auxiliar para os barramento de flags
signal flags_s					: std_logic_vector(flags_size-1 downto 0);
signal packlen_calc_s			: std_logic_vector(2*byte-1 downto 0);
signal checksum_calc_s			: std_logic_vector(2*byte-1 downto 0);
signal seqnum_calc_s			: std_logic_vector(4*byte-1 downto 0);

-- sinais de saída do header
signal packlen_header			: std_logic_vector(2*byte-1 downto 0);
signal checksum_header			: std_logic_vector(2*byte-1 downto 0);
signal seqnum_header			: std_logic_vector(4*byte-1 downto 0);
signal SYN_header, CLO_header	: std_logic;
signal protocol_header			: std_logic_vector(byte-1 downto 0);
signal dummy_header				: std_logic_vector(2*byte-1 downto 0);
signal source_address_header	: std_logic_vector(2*byte-1 downto 0);
signal dest_address_header		: std_logic_vector(2*byte-1 downto 0);

-- flag para identificar que o header tem dado valido
signal header_f_s		: std_logic;
signal validation_f_s	: std_logic;
signal d_table_f_s		: std_logic;

-- sinal para receber a porta de destino
-- signal dest_port_s : std_logic_vector(dest_port'range);

-- contador de bytes (sai do validation par ao header)
signal byte_counter_s	: std_logic_vector(counter_packet_size-1 downto 0);

begin

	-- begin debug
	counter_db <= byte_counter_s;
	-- end debug
	HEADER : entity work.header(header_rtl)
		generic map(
			byte => byte,
			max_pack_size => counter_packet_size
		)
		port map(
			rst => rst,
			clk => clk,
			S_AXIS_TDATA => S_AXIS_TDATA,
			S_AXIS_TVALID => S_AXIS_TVALID,
			S_AXIS_TLAST => S_AXIS_TLAST,
			S_AXIS_TREADY => TREADY_s,
			packet_length => packlen_header,
			checksum => checksum_header,
			dummy => dummy_header,
			source_address => source_address_header,
			dest_address => dest_address_header,
			sequence_number => seqnum_header,
			SYN => SYN_header,
			CLO => CLO_header,
			protocol => protocol_header,
			header_f => header_f_s,
			count_p => counter_h_db
		);
		
	VALIDATION : entity work.validation(validation_rtl)
		generic map(
			byte => byte,
			max_pack_size => counter_packet_size
		)
		port map(
			rst => rst,
			clk => clk,
			S_AXIS_TDATA => S_AXIS_TDATA,
			S_AXIS_TVALID => S_AXIS_TVALID,
			S_AXIS_TLAST => S_AXIS_TLAST,
			S_AXIS_TREADY => S_AXIS_TREADY,
			packet_length => packlen_header,
			checksum => checksum_header,
			byte_counter => byte_counter_s,
			word_counter => word_counter_db,
			packet_length_f => flags_s(flags_size-1),
			checksum_f => flags_s(flags_size-2),
			checksum_p => checksum_calc_s,
			packet_length_p => packlen_calc_s
		);
	 
	D_TABLE : entity work.d_table(d_table_rtl)
		generic map(
			byte => byte,
			ports_len => ports_len
		)
		port map(
			rst => rst,
			clk => clk,
			header_f => header_f_s,
			seqnum_h => seqnum_header,
			SYN => SYN_header,
			CLO => CLO_header,
			source_address => source_address_header,
			dest_address => dest_address_header,
			source_port => source_port,
			dest_port => dest_port,
			dest_address_not_found => flags_s(flags_size-4),
			seqnum_f => flags_s(flags_size-3),
			seqnum_calc_p => seqnum_calc_s,
			d_table_f => d_table_f_s,
			port_0_out => porta_0_p,
        	port_1_out => porta_1_p,
        	port_2_out => porta_2_p,
	        port_3_out => porta_3_p,
    	    port_4_out => porta_4_p
		);

	ERROR_DATA : entity work.error_data(logica)
		generic map(byte => byte)
		port map(
			clk => clk,
			rst => rst,
			M_AXIS_TREADY => M_AXIS_TREADY,
			flags => flags_s,--essa porta input tem 4 bits e flags_s tem 6bits
			h_packet_length => packlen_header,
			v_packet_length => packlen_calc_s,
			h_checksum => checksum_header,
			v_checksum => checksum_calc_s,
			h_sequence_number => seqnum_header,
			v_sequence_number => seqnum_calc_s, -- COLOCAR UM PORT OUT NA DTABLE PARA O SEQNUM
			h_destination_address => dest_address_header,
			f_header => header_f_s,
			f_d_table => d_table_f_s,
			M_AXIS_TDATA => M_AXIS_TDATA,
			M_AXIS_TVALID => M_AXIS_TVALID,
			M_AXIS_TLAST => M_AXIS_TLAST
		);

	-- dest_port <= dest_port_s;
	dest_address <= dest_address_header;
	source_address <= source_address_header;

	flags_s(flags_size-5) <= SYN_header;
	flags_s(flags_size-6) <= CLO_header;

	flags <= flags_s;
	packlen_calc <= packlen_calc_s;
	checksum_calc <= checksum_calc_s;
	seqnum_calc <= seqnum_calc_s;

	-- portas de verificação do funcionamento do bloco HEADER
	checksum_header_p <= checksum_header;
	seqnum_header_p <= seqnum_header;
	SYN_header_p <= SYN_header;
	CLO_header_p <= CLO_header;
	protocol_header_p <= protocol_header;
	dummy_header_p <= dummy_header;
	source_address_header_p <= source_address_header;
	dest_address_header_p <= dest_address_header;
	packlen_header_p <= packlen_header;
	TREADY_header_p <= TREADY_s;
	header_f_p <= header_f_s;
	d_table_f_p <= d_table_f_s;

end architecture switch_rtl;