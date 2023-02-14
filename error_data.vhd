-- Title: Bloco de comunicação M_AXIS quando há erros na comunicação

-- Authors: Lucas Silva Meyer e Pedro Azevedo da Conceição

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY error_data IS

	GENERIC (
		byte : POSITIVE := 8
	);

	PORT (

		----debug singnals (db)
		--	db_finish : out std_logic;
		--	db_valid  : out std_logic;
		--	db_count  : out std_logic_vector(2 downto 0);
		--	start     : out std_logic;
		--	db_local  : out std_logic_vector(4 downto 0);
		-----------		

		clk, rst : IN STD_LOGIC;

		--inputs
		M_AXIS_TREADY : IN STD_LOGIC;
		flags : IN STD_LOGIC_VECTOR (5 DOWNTO 0); -- pktlen, cksum, seqnum
		-- header e validator inputs

		h_packet_length, v_packet_length : IN STD_LOGIC_VECTOR(2 * byte - 1 DOWNTO 0);
		h_checksum, v_checksum : IN STD_LOGIC_VECTOR(2 * byte - 1 DOWNTO 0);
		h_sequence_number, v_sequence_number : IN STD_LOGIC_VECTOR(4 * byte - 1 DOWNTO 0);
		h_destination_address : IN STD_LOGIC_VECTOR(2 * byte - 1 DOWNTO 0);
		f_header, f_d_table : IN STD_LOGIC;

		-- outputs
		M_AXIS_TDATA : OUT STD_LOGIC_VECTOR (byte - 1 DOWNTO 0);
		M_AXIS_TVALID : OUT STD_LOGIC;
		M_AXIS_TLAST : OUT STD_LOGIC
		------------

		--	f_error_data 	 : out std_logic;

	);
END ENTITY error_data;

ARCHITECTURE logica OF error_data IS

	--	signal f_cksum_next, f_cksum_reg, f_pktlen_next, f_pktlen_reg, f_seqnum_next, f_seqnum_reg : std_logic;	 
	--	signal dest_addr_next, dest_addr_reg : unsigned (2*byte-1 downto 0);	

	SIGNAL f_pktlen, f_cksum, f_seqnum, f_dest_addr : STD_LOGIC;
	SIGNAL f_pktlen_reg, f_pktlen_next, f_cksum_reg, f_cksum_next,
	f_seqnum_reg, f_seqnum_next : STD_LOGIC;

	SIGNAL f_dest_addr_reg, f_dest_addr_next : STD_LOGIC;

	SIGNAL TDATA_reg, TDATA_next : STD_LOGIC_VECTOR (byte - 1 DOWNTO 0);
	SIGNAL TVALID_reg, TVALID_next : STD_LOGIC;
	SIGNAL TREADY_reg, TREADY_next : STD_LOGIC;
	SIGNAL TREADY_s : STD_LOGIC;
	SIGNAL TLAST_reg, TLAST_next : STD_LOGIC;
	SIGNAL count_reg, count_next : unsigned (2 DOWNTO 0);
	SIGNAL start_reg, start_next : STD_LOGIC;
	--inputs vindo do header e validator	 
	SIGNAL h_pktlen_reg, h_pktlen_next : STD_LOGIC_VECTOR(2 * byte - 1 DOWNTO 0);
	SIGNAL h_cksum_reg, h_cksum_next : STD_LOGIC_VECTOR (2 * byte - 1 DOWNTO 0);
	SIGNAL h_seqnum_reg, h_seqnum_next : STD_LOGIC_VECTOR (4 * byte - 1 DOWNTO 0);
	SIGNAL h_dest_addr_reg, h_dest_addr_next : STD_LOGIC_VECTOR (2 * byte - 1 DOWNTO 0);
	SIGNAL v_pktlen_reg, v_pktlen_next : STD_LOGIC_VECTOR(2 * byte - 1 DOWNTO 0);
	SIGNAL v_cksum_reg, v_cksum_next : STD_LOGIC_VECTOR (2 * byte - 1 DOWNTO 0);
	SIGNAL v_seqnum_reg, v_seqnum_next : STD_LOGIC_VECTOR (4 * byte - 1 DOWNTO 0);
	SIGNAL v_dest_addr_reg, v_dest_addr_next : STD_LOGIC_VECTOR (2 * byte - 1 DOWNTO 0);
	-- db signals
	SIGNAL f_finish_next, f_finish_reg : STD_LOGIC;
	SIGNAL f_header_next, f_header_reg : STD_LOGIC;
	-- SIGNAL local : unsigned(4 DOWNTO 0);
	---

	TYPE state_p IS (get_flags, s_pktlen, s_seqnum, s_cksum, s_addr);

	-- sinais para os registradores da máquina de estados
	SIGNAL state_reg, state_next : state_p;

BEGIN
	f_pktlen <= flags(5);
	f_cksum <= flags(4);
	f_seqnum <= flags(3);
	f_dest_addr <= flags(2);
	--	f_header_next   <= f_header;

	TICK : PROCESS (clk, rst)
	BEGIN
		IF rising_edge(clk) THEN
			IF rst = '1' THEN
				TVALID_reg <= '0';
				TDATA_reg <= (OTHERS => '0');
				TLAST_reg <= '0';
				TREADY_reg <= '0';
				state_reg <= get_flags;
				count_reg <= (OTHERS => '0');
				f_finish_reg <= '0';
				start_reg <= '0';
				-- dados do header
				h_pktlen_reg 	  <= (others => '0');	  
				h_cksum_reg 	  <= (others => '0');	
				h_seqnum_reg 	  <= (others => '0');	
				h_dest_addr_reg <= (others => '0');
				v_pktlen_reg 	  <= (others => '0');	  
				v_cksum_reg 	  <= (others => '0');	
				v_seqnum_reg 	  <= (others => '0');	
				v_dest_addr_reg <= (others => '0');
				f_header_reg <= '0';
				f_dest_addr_reg <= '0';
				f_pktlen_reg <= '0';
				f_cksum_reg <= '0';
				f_seqnum_reg <= '0';
				f_dest_addr_reg <= '0';
			ELSE
				TVALID_reg <= TVALID_next;
				TDATA_reg <= TDATA_next;
				TLAST_reg <= TLAST_next;
				TREADY_reg <= TREADY_next;
				state_reg <= state_next;
				count_reg <= count_next;
				f_finish_reg <= f_finish_next;
				start_reg <= start_next;
				f_header_reg <= f_header_next;
				-- dados do header
				h_pktlen_reg 	 <= h_pktlen_next;	 
				h_cksum_reg 	 <= h_cksum_next;	
				h_seqnum_reg 	 <=	h_seqnum_next;
				h_dest_addr_reg <= h_dest_addr_next;
				v_pktlen_reg 	 <= h_pktlen_next;	 
				v_cksum_reg 	 <= h_cksum_next;	
				v_seqnum_reg 	 <=	h_seqnum_next;
				v_dest_addr_reg <= h_dest_addr_next;
				f_dest_addr_reg <= f_dest_addr_next;
				f_pktlen_reg <= f_pktlen_next;
				f_cksum_reg <= f_cksum_next;
				f_seqnum_reg <= f_seqnum_next;
			END IF;
		END IF;
	END PROCESS TICK;
	flag_read : PROCESS (f_cksum, f_pktlen, f_seqnum, h_dest_addr_reg, flags, TVALID_reg,
		state_reg, count_reg, TREADY_reg, TLAST_reg, TDATA_reg,
		f_finish_reg, start_reg, v_pktlen_reg, v_cksum_reg, v_seqnum_reg, v_dest_addr_reg,
		h_pktlen_reg, h_cksum_reg, h_seqnum_reg, f_d_table, h_packet_length, h_checksum,
		h_sequence_number, h_destination_address, v_packet_length, v_checksum,
		v_sequence_number, f_header, f_dest_addr, f_dest_addr_reg, f_pktlen_reg,
		f_cksum_reg, f_seqnum_reg, TREADY_s, f_header_reg)
	BEGIN

		TDATA_next <= TDATA_reg;
		TVALID_next <= TVALID_reg;
		TREADY_next <= TREADY_reg;
		TLAST_next <= TLAST_reg;
		state_next <= state_reg;
		count_next <= count_reg;
		f_finish_next <= f_finish_reg;
		TLAST_next <= '0';
		h_pktlen_next 	 <= h_pktlen_reg;	 
		h_cksum_next 	 <= h_cksum_reg;	
		h_seqnum_next 	 <=	h_seqnum_reg;
		h_dest_addr_next <= h_dest_addr_reg;
		v_pktlen_next 	 <= h_pktlen_reg;	 
		v_cksum_next 	 <= h_cksum_reg;	
		v_seqnum_next 	 <=	h_seqnum_reg;
		v_dest_addr_next <= h_dest_addr_reg;
		f_dest_addr_next <= f_dest_addr_reg;
		f_pktlen_next <= f_pktlen_reg;
		f_cksum_next <= f_cksum_reg;
		f_seqnum_next <= f_seqnum_reg;

		IF f_header = '1' THEN
			h_pktlen_next <= h_packet_length;
			h_cksum_next <= h_checksum;
			h_seqnum_next <= h_sequence_number;
			h_dest_addr_next <= h_destination_address;

			v_pktlen_next <= v_packet_length;
			v_cksum_next <= NOT(v_checksum);
			-- v_seqnum	   <=  v_sequence_number; 

		END IF;
		IF f_d_table = '1' THEN
			v_seqnum_next <= v_sequence_number;
			start_next <= '1';
			f_pktlen_next <= f_pktlen;
			f_cksum_next <= f_cksum;
			f_seqnum_next <= f_seqnum;
			f_dest_addr_next <= f_dest_addr;
			state_next <= get_flags;
			TVALID_next <= '0';
		ELSE
			start_next <= start_reg;
			-- state_next <= state_reg;
		END IF;

		IF start_reg = '1' THEN
			CASE state_reg IS
				WHEN get_flags =>
					-- local <= "00001";-- debug signal
					f_finish_next <= '0';
					TLAST_next <= '0';
					TVALID_next <= '1';

					IF f_pktlen_reg = '1' THEN
						state_next <= s_pktlen;
					ELSE
						IF f_cksum_reg = '1' THEN
							state_next <= s_cksum;
						ELSE
							IF f_seqnum_reg = '1' THEN
								state_next <= s_seqnum;
							ELSE
								IF f_dest_addr_reg = '1' THEN
									state_next <= s_addr;
								ELSE

									state_next <= get_flags; --nao houve erros
									TVALID_next <= '0';
									start_next <= '0';
									f_finish_next <= '1'; -- terminou a checagem
								END IF;
							END IF;
						END IF;
					END IF;
				WHEN s_pktlen =>
					state_next <= state_reg;
					-- local <= "00010"; -- debug signal
					TVALID_next <= '1';
					IF TREADY_s = '1' THEN
						count_next <= count_reg + 1;
						IF count_reg = X"00" THEN
							TDATA_next <= v_pktlen_reg(2 * byte - 1 DOWNTO byte);

						ELSIF count_reg = X"01" THEN
							TDATA_next <= v_pktlen_reg(byte - 1 DOWNTO 0);

						ELSIF count_reg = X"02" THEN
							TDATA_next <= h_pktlen_reg(2 * byte - 1 DOWNTO byte);

						ELSE
							TDATA_next <= h_pktlen_reg(byte - 1 DOWNTO 0);
							TLAST_next <= '1';
							TVALID_next <= '0';
							state_next <= get_flags;
							start_next <= '0';
							count_next <= (OTHERS => '0');
							f_finish_next <= '1';
						END IF;--if count_reg
					ELSE
						state_next <= s_addr;
					END IF; -- if tready
				WHEN s_cksum =>
					state_next <= state_reg;
					-- local <= "00100";-- debug signal
					TVALID_next <= '1';
					IF TREADY_s = '1' THEN
						count_next <= count_reg + 1;
						IF count_reg = X"00" THEN
							TDATA_next <= v_cksum_reg(2 * byte - 1 DOWNTO byte);

						ELSIF count_reg = X"01" THEN
							TDATA_next <= v_cksum_reg(byte - 1 DOWNTO 0);

						ELSIF count_reg = X"02" THEN
							TDATA_next <= h_cksum_reg(2 * byte - 1 DOWNTO byte);

						ELSE
							TDATA_next <= h_cksum_reg(byte - 1 DOWNTO 0);
							TLAST_next <= '1';
							TVALID_next <= '0';
							state_next <= get_flags;
							start_next <= '0';
							count_next <= (OTHERS => '0');
							f_finish_next <= '1';-- debug signal
						END IF;--if count_reg
					ELSE
						state_next <= s_addr;
					END IF; -- if tready

				WHEN s_seqnum =>
					state_next <= state_reg;
					-- local <= "01000";-- debug signal
					TVALID_next <= '1';
					IF TREADY_s = '1' THEN
						count_next <= count_reg + 1;
						IF count_reg = X"00" THEN
							TDATA_next <= v_seqnum_reg(4 * byte - 1 DOWNTO 3 * byte);

						ELSIF count_reg = X"01" THEN
							TDATA_next <= v_seqnum_reg(3 * byte - 1 DOWNTO 2 * byte);

						ELSIF count_reg = X"02" THEN
							TDATA_next <= v_seqnum_reg(2 * byte - 1 DOWNTO byte);

						ELSIF count_reg = X"03" THEN
							TDATA_next <= v_seqnum_reg(byte - 1 DOWNTO 0);

						ELSIF count_reg = X"04" THEN
							TDATA_next <= h_seqnum_reg(4 * byte - 1 DOWNTO 3 * byte);

						ELSIF count_reg = X"05" THEN
							TDATA_next <= h_seqnum_reg(3 * byte - 1 DOWNTO 2 * byte);

						ELSIF count_reg = X"06" THEN
							TDATA_next <= h_seqnum_reg(2 * byte - 1 DOWNTO byte);
						ELSE
							TDATA_next <= h_seqnum_reg(byte - 1 DOWNTO 0);
							TLAST_next <= '1';
							TVALID_next <= '0';
							state_next <= get_flags;
							start_next <= '0';
							count_next <= (OTHERS => '0');
							f_finish_next <= '1';
						END IF;--if count_reg
					ELSE
						state_next <= s_addr;
					END IF; -- if tready

				WHEN s_addr =>
					state_next <= state_reg;
					-- local <= "10000";
					TVALID_next <= '1';
					IF TREADY_s = '1' THEN
						count_next <= count_reg + 1;
						IF count_reg = X"00" THEN
							TDATA_next <= h_dest_addr_reg(2 * byte - 1 DOWNTO byte);
						ELSE
							TDATA_next <= h_dest_addr_reg(byte - 1 DOWNTO 0);
							TLAST_next <= '1';
							TVALID_next <= '0';
							state_next <= get_flags;
							start_next <= '0';
							count_next <= (OTHERS => '0');
							f_finish_next <= '1';
						END IF;--if count_reg
					ELSE
						state_next <= s_addr;
					END IF; -- if tready

			END CASE;
		ELSE
			TLAST_next <= '0';
		END IF; -- if START

		f_header_next <= f_header_reg;

	END PROCESS flag_read;

	M_AXIS_TDATA <= TDATA_reg;
	M_AXIS_TLAST <= TLAST_reg;
	M_AXIS_TVALID <= TVALID_reg;
	TREADY_s <= M_AXIS_TREADY;

	--		f_error_data <= f_finish_reg; 

	---- debug signals		
	--	db_finish <= f_finish_reg;
	--	db_valid  <= TVALID_reg;
	--	db_count  <= std_logic_vector(count_reg);
	--	db_local <= std_logic_vector(local);
	--	start <= start_reg;

END ARCHITECTURE logica;

--00001111000001110000001100000001
--10000000110000001110000011110000