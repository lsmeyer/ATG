-- Title: Verifier of the comunication bytes integrity
--
-- Authors: Lucas Silva Meyer e Pedro Azevedo da Conceição

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity validation is

	generic (
		byte					: positive := 8;
		max_pack_size		: positive := 9 -- tamanho de bits para contar quantidade máxima de bytes
	);
	
	port(
		rst	: in std_logic;
		clk	: in std_logic;
		
		-- AXI4_STREAM ports
		S_AXIS_TDATA	: in std_logic_vector(byte - 1 downto 0);
		S_AXIS_TVALID	: in std_logic;
		S_AXIS_TLAST	: in std_logic;
		S_AXIS_TREADY	: out std_logic;
		
		
		packet_length, checksum			: in std_logic_vector (2*byte-1 downto 0);
		byte_counter					: out std_logic_vector(max_pack_size-1 downto 0);
		word_counter					: out std_logic_vector(1 downto 0);
		packet_length_f, checksum_f		: out std_logic;
		
		-- somente para visualização da lógica
		checksum_p, packet_length_p	: out std_logic_vector (2*byte-1 downto 0)
	);

end entity;

architecture validation_rtl of validation is

signal TDATA_s															: unsigned(byte - 1 downto 0);
signal TVALID_s, TLAST_s											: std_logic;
signal TREADY_reg, TREADY_next									: std_logic;
signal packet_len_calc_reg, packet_len_calc_next			: unsigned(2*byte - 1 downto 0);
signal checksum_calc_reg, checksum_calc_next					: unsigned(2*byte - 1 downto 0);
-- variável para armazenar o número de 16 bits que será incrementado no valor de checksum
signal checksum_bus_reg, checksum_bus_next					: unsigned(2*byte - 1 downto 0);
signal packet_len_f_reg, packet_len_f_next					: std_logic;
signal checksum_f_reg, checksum_f_next							: std_logic;

-- conta o número de bytes
signal byte_counter_reg, byte_counter_next					: unsigned(max_pack_size-1 downto 0);

-- quando igual a 3, incrementar o packet_len_calc
signal word_counter_reg, word_counter_next					: unsigned(1 downto 0);

type state_p is (first_byte, second_byte, comparison, wait_package);

signal state_reg, state_next : state_p;

begin

	TICK: process (clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_reg <= first_byte;
				TREADY_reg <= '0';
				packet_len_calc_reg <= (others => '0');
				checksum_calc_reg <= (others => '0');
				byte_counter_reg <= (others => '0');
				word_counter_reg <= (others => '0');
				checksum_f_reg <= '0';
				packet_len_f_reg <= '0';
				checksum_bus_reg <= (others => '0');
			else
				state_reg <= state_next;
				packet_len_calc_reg <= packet_len_calc_next;
				checksum_calc_reg <= checksum_calc_next;
				byte_counter_reg <= byte_counter_next;
				word_counter_reg <= word_counter_next;
				TREADY_reg <= TREADY_next;
				checksum_f_reg <= checksum_f_next;
				packet_len_f_reg <= packet_len_f_next;
				checksum_bus_reg <= checksum_bus_next;
			end if;
		end if;
	end process TICK;
	
	COMPARE_P: process	(TDATA_s, TVALID_s, TLAST_s, TREADY_reg, state_reg, packet_len_calc_reg, checksum_calc_reg,
								 byte_counter_reg, word_counter_reg, packet_length, checksum, packet_len_f_reg, checksum_f_reg,
								 checksum_bus_reg)
	begin
		state_next <= state_reg;
		packet_len_calc_next <= packet_len_calc_reg;
		checksum_calc_next <= checksum_calc_reg;
		byte_counter_next <= byte_counter_reg;
		word_counter_next <= word_counter_reg;
		TREADY_next <= TREADY_reg;
		checksum_f_next <= checksum_f_reg;
		packet_len_f_next <= packet_len_f_reg;
		checksum_bus_next <= checksum_bus_reg;
		case state_reg is
			when first_byte =>
				TREADY_next <= '1';
				if TVALID_s = '1' and TREADY_reg = '1' then
--					TREADY_next <= '1';
					byte_counter_next <= byte_counter_reg + 1;
					word_counter_next <= word_counter_reg + 1;
					-- condição da lógica do checksum
					if (byte_counter_reg = 2 or byte_counter_reg = 3) then
--						checksum_calc_next <= checksum_calc_reg + checksum_bus_reg;
					else
						checksum_bus_next <= checksum_bus_reg(byte - 1 downto 0) & TDATA_s;
						if (checksum_calc_reg + checksum_bus_reg) < checksum_calc_reg or
							(checksum_calc_reg + checksum_bus_reg) < checksum_bus_reg then
							checksum_calc_next <= checksum_calc_reg + checksum_bus_reg + 1;
						else
							checksum_calc_next <= checksum_calc_reg + checksum_bus_reg;
						end if;
					end if;
					-- condição da lógica do packet_length
					if word_counter_reg = "11" then
						packet_len_calc_next <= packet_len_calc_reg + 1;
					else
						packet_len_calc_next <= packet_len_calc_reg;
					end if;
--					-- condição da mudança de estados;
					if TLAST_s = '1' then
						TREADY_next <= '0';
						state_next <= comparison;
					else
						state_next <= second_byte;
					end if;
				elsif TVALID_S = '1' and TREADY_reg = '0' then
					TREADY_next <= '1';
				end if;
			when second_byte =>
				TREADY_next <= '1';
				if TVALID_s = '1' and TREADY_reg = '1' then
--					TREADY_next <= '1';
					byte_counter_next <= byte_counter_reg + 1;
					word_counter_next <= word_counter_reg + 1;
					-- condição da lógica do checksum
					if (byte_counter_reg = 2 or byte_counter_reg = 3) then
					else
						checksum_bus_next <= checksum_bus_reg(byte - 1 downto 0) & TDATA_s;
					end if;
					-- condição da lógica do packet_length
					if word_counter_reg = "11" then
						packet_len_calc_next <= packet_len_calc_reg + 1;
					else
						packet_len_calc_next <= packet_len_calc_reg;
					end if;
					-- condição da mudança de estados;
					if TLAST_s = '1' then
						TREADY_next <= '0';
						state_next <= comparison;
					else
						state_next <= first_byte;
					end if;
				elsif TVALID_S = '1' and TREADY_reg = '0' then
					TREADY_next <= '1';
				end if;
			when comparison =>
				state_next <= wait_package;
				TREADY_next <= '0';
				checksum_bus_next <= checksum_bus_reg(byte - 1 downto 0) & TDATA_s;
				if (checksum_calc_reg + checksum_bus_reg) < checksum_calc_reg or
					(checksum_calc_reg + checksum_bus_reg) < checksum_bus_reg then
					checksum_calc_next <= not (checksum_calc_reg + checksum_bus_reg + 1);
					if (not (checksum_calc_reg + checksum_bus_reg + 1)) = unsigned(checksum) then
						checksum_f_next <= '0';
					else
						checksum_f_next <= '1';
					end if;
				else
					checksum_calc_next <= not(checksum_calc_reg + checksum_bus_reg);
					if (not (checksum_calc_reg + checksum_bus_reg)) = unsigned(checksum) then
						checksum_f_next <= '0';
					else
						checksum_f_next <= '1';
					end if;
				end if;				
				if packet_len_calc_reg = unsigned(packet_length) then
					packet_len_f_next <= '0';
				else
					packet_len_f_next <= '1';
				end if;
			when wait_package =>
				TREADY_next <= '0';
				byte_counter_next <= (others => '0');
				word_counter_next <= (others => '0');
				if TVALID_s = '1' then
					TREADY_next <= '1';
					checksum_calc_next <= (others => '0');
					checksum_bus_next <= (others => '0');
					checksum_f_next <= '0';
					packet_len_calc_next <= (others => '0');
					packet_len_f_next <= '0';					
					state_next <= first_byte;
				else
					state_next <= state_reg;
				end if;
		end case;	
	end process COMPARE_P;
	
	TDATA_s <= unsigned(S_AXIS_TDATA);
	TVALID_s <= S_AXIS_TVALID;
	TLAST_s <= S_AXIS_TLAST;
	S_AXIS_TREADY <= TREADY_reg;
	byte_counter <= std_logic_vector(byte_counter_reg);
	word_counter <= std_logic_vector(word_counter_reg);
	checksum_f <= checksum_f_reg;
	packet_length_f <= packet_len_f_reg;
	
	checksum_p <= std_logic_vector(checksum_calc_reg);
	packet_length_p <= std_logic_vector(packet_len_calc_reg);

end architecture validation_rtl;
