--TITLE: Description of a block that have a IPV4 header as input
--       and have a AXI4-Stream interface as output

-- Authors: Lucas Silva Meyer e Pedro Azevedo da Conceição

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity header is

	-- FALTA USAR O VALOR DE BYTE COMO PARÂMETRO DE TAMANHO DAS ENTRADAS E SAÍDAS
	generic(
		byte				: positive := 8;
		max_pack_size	: positive := 9
	);
	
	port(
	
		rst	: in std_logic; -- sinal de reset
		clk	: in std_logic; -- sinal de clock
		
		-- Entrada é o stream de dados relativos ao header
		
		S_AXIS_TDATA    : in std_logic_vector (byte-1 downto 0);
		S_AXIS_TVALID   : in std_logic;
		S_AXIS_TLAST    : in std_logic;
		S_AXIS_TREADY   : out std_logic;

		-- Saída são as informações do header

		packet_length, checksum, dummy, source_address, dest_address    : out std_logic_vector (2*byte-1 downto 0);
		sequence_number                                                 : out std_logic_vector (4*byte-1 downto 0);
		SYN, CLO                                                        : out std_logic;
		protocol														:	out std_logic_vector (byte-1 downto 0);
		
		-- Contador proveniente do validation
		-- counter_in	: in std_logic_vector(max_pack_size-1 downto 0);
		header_f	: out std_logic;
		count_p		: out std_logic_vector(max_pack_size-1 downto 0)
    );
end header;

architecture header_rtl of header is

-- sinal que irá direcionar o byte de entrada para a porta de saída correspondente
signal TDATA_s							:	std_logic_vector (byte-1 downto 0);
signal TREADY_reg, TREADY_next	:	std_logic;
--signal SYN_CLO		:	std_logic_vector (7 downto 0); -- sinal auxiliar para a aquisição das flags Sync e Close

-- sinal que fará a contagem de bytes lidos
signal byte_counter_next, byte_counter_reg : unsigned(max_pack_size-1 downto 0);

-- sinal que será usado para shiftar os bytes
signal header_bus_reg, header_bus_next			: std_logic_vector (16*byte-1 downto 0);
signal header_final_reg, header_final_next	: std_logic_vector (16*byte-1 downto 0);

-- flag que indica que validação do packlen e checksum ocorreu
signal header_f_s : std_logic;

-- definindo o tipo da máquina de estados
type state_p is (get_header, comparison, wait_package);

-- sinais para os registradores da máquina de estados
signal state_reg, state_next : state_p;

-- sinal contador para identificar o fim do header
--signal count_reg, count_next : unsigned (3 downto 0);


begin

	TDATA_s <= S_AXIS_TDATA;

-- Processo de extração

	TICK : process (clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				TREADY_reg <= '0';
				header_bus_reg <= (others => '0');
				header_final_reg <= (others => '0');
				byte_counter_reg <= (others => '0');
				state_reg <= get_header;
			else
				TREADY_reg <= TREADY_next;
				header_bus_reg <= header_bus_next;
				header_final_reg <= header_final_next;
				byte_counter_reg <= byte_counter_next;
				state_reg <= state_next;
			end if;
		end if;
	end process TICK;
	
	GET_P : process(TDATA_s, S_AXIS_TVALID, S_AXIS_TLAST, TREADY_reg, header_bus_reg, state_reg, header_final_reg, byte_counter_reg)
	begin
		state_next <= state_reg;
		header_bus_next <= header_bus_reg;
		header_final_next <= header_final_reg;
		TREADY_next <= TREADY_reg;
		byte_counter_next <= byte_counter_reg;
		header_f_s <= '0';
		SYN <= '0';
		CLO <= '0';
		case state_reg is
			when get_header =>
				TREADY_next <= '1';
				if S_AXIS_TVALID = '1' and TREADY_reg = '1' then
					TREADY_next <= '1';
					byte_counter_next <= byte_counter_reg + 1;
					if byte_counter_reg <= 15 then
						if (S_AXIS_TVALID = '1') then
							TREADY_next <= '1';
							header_bus_next <= header_bus_reg(15*byte-1 downto 0) & TDATA_s;
						else
							header_bus_next <= header_bus_reg;
						end if;
						if byte_counter_reg = 15 then
							header_final_next <= header_bus_reg(15*byte-1 downto 0) & TDATA_s;
						end if;
					end if;
					if (S_AXIS_TLAST = '1' and S_AXIS_TVALID = '1' and TREADY_reg = '1') then
						TREADY_next <= '0';
						-- header_final_next <= header_bus_reg;
						-- header_final_next <= header_bus_reg(15*byte-1 downto 0) & TDATA_s;
						state_next <= comparison;
					end if;
				elsif S_AXIS_TVALID = '1' and TREADY_reg = '0' then
					TREADY_next <= '1';
				end if;
			when comparison =>
				TREADY_next <= '0';
				header_f_s <= '1';
				SYN					<= header_final_reg(8*byte-1);
				CLO					<= header_final_reg(8*byte-8);
				state_next <= wait_package;
			when wait_package =>
				TREADY_next <= '0';
				byte_counter_next <= (others => '0');
--				header_final_next <= header_bus_reg;
				SYN					<= header_final_reg(8*byte-1);
				CLO					<= header_final_reg(8*byte-8);
				if S_AXIS_TVALID = '1' then
					TREADY_next <= '1';
					header_final_next <= (others => '0');
					header_bus_next <= (others => '0');
					byte_counter_next <= (others => '0');
					state_next <= get_header;
				end if;
		end case;
	end process GET_P;
	
	S_AXIS_TREADY 		<= TREADY_reg;
	count_p				<= std_logic_vector(byte_counter_reg);
	packet_length		<= header_final_reg(16*byte-1 downto 14*byte);
	checksum			<= header_final_reg(14*byte-1 downto 12*byte);
	sequence_number		<= header_final_reg(12*byte-1 downto 8*byte);
	-- SYN					<= header_final_reg(8*byte-1);
	-- CLO					<= header_final_reg(8*byte-8);
	protocol			<= header_final_reg(7*byte-1 downto 6*byte);
	dummy				<= header_final_reg(6*byte-1 downto 4*byte);
	source_address		<= header_final_reg(4*byte-1 downto 2*byte);
	dest_address		<= header_final_reg(2*byte-1 downto 0);

	header_f <= header_f_s;
	
end header_rtl;