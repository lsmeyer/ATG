-- Title: Bloco com tabela que representa o endereço conectado em cada porta

-- Authors: Lucas Silva Meyer e Pedro Azevedo da Conceição

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity d_table is
    generic(
        byte        : positive := 8;
        ports_len   : positive := 5
    );
    port(
        rst : in std_logic;
        clk : in std_logic;

        header_f : in std_logic;
        seqnum_h : in std_logic_vector(4*byte-1 downto 0);
        -- se 1, escrever endereço na tabela
        SYN : in std_logic;
        -- se 1, apagar endereço na tabela
        CLO : in std_logic;

        -- endereço que deve ser escrito quando SYN = 1
        source_address  : in std_logic_vector(2*byte-1 downto 0);
        -- endereço que deve ser apagado quando CLO = 1
        -- e caso SYN = 0 and CLO = 0 deve ser usado para
        -- encontrar a porta de destino do pacote
        dest_address    : in std_logic_vector(2*byte-1 downto 0);

        -- porta de origem do pacote quando há sync proveniente de input do SWITCH
        source_port : in std_logic_vector(ports_len-1 downto 0);
        -- porta de destino quando enviando um pacote, será enviado para output
        -- do SWITCH
        dest_port   : out std_logic_vector(ports_len-1 downto 0);

        -- flag destination addres not found
        dest_address_not_found : out std_logic;

        -- seqnum_f_0 : out std_logic;
        -- seqnum_f_1 : out std_logic;
        -- seqnum_f_2 : out std_logic;
        -- seqnum_f_3 : out std_logic;
        -- seqnum_f_4 : out std_logic;

        -- flag relativa ao seqnum do dispositivo conectado
        seqnum_f        : out std_logic;
        -- seqnum calculado para o dispositivo conectado
        seqnum_calc_p   : out std_logic_vector(4*byte-1 downto 0);
        -- high quando seqnum é calculado
        d_table_f       : out std_logic;

        -- DEBUG


        port_0_out : out std_logic_vector(2*byte-1 downto 0);
        port_1_out : out std_logic_vector(2*byte-1 downto 0);
        port_2_out : out std_logic_vector(2*byte-1 downto 0);
        port_3_out : out std_logic_vector(2*byte-1 downto 0);
        port_4_out : out std_logic_vector(2*byte-1 downto 0)
    );
end entity d_table;

architecture d_table_rtl of d_table is

type address_array_type is array (ports_len-1 downto 0) of std_logic_vector(2*byte-1 downto 0);

signal my_address_next, my_address_reg : address_array_type;
signal dest_address_not_found_next, dest_address_not_found_reg : std_logic;

type seqnum_array_type is array (ports_len-1 downto 0) of unsigned(4*byte-1 downto 0);

signal my_seqnum_next, my_seqnum_reg : seqnum_array_type;

type flag_array_type is array (ports_len-1 downto 0) of std_logic;

signal my_flag_next, my_flag_reg : flag_array_type;
signal seqnum_f_next, seqnum_f_reg : std_logic;
signal d_table_f_reg, d_table_f_next : std_logic;

begin

    TICK : process (clk, rst)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                my_address_reg <= (others => X"0000");
                my_seqnum_reg <= (others => (others => '0'));
                my_flag_reg <= (others => '0');
                dest_address_not_found_reg <= '0';
                seqnum_f_reg <= '0';
				d_table_f_reg <='0';
            else
                my_address_reg <= my_address_next;
                my_seqnum_reg <= my_seqnum_next;
                dest_address_not_found_reg <= dest_address_not_found_next;
                my_flag_reg <= my_flag_next;
                seqnum_f_reg <= seqnum_f_next;
				d_table_f_reg <= d_table_f_next;
            end if;
        end if;
    end process TICK;

    COMBINATIONAL : process (header_f, SYN, CLO, source_address, dest_address, source_port, my_address_reg, dest_address_not_found_reg, seqnum_h, my_seqnum_reg, seqnum_f_reg, d_table_f_reg, my_flag_reg)
    begin
        my_address_next <= my_address_reg;
        my_seqnum_next <= my_seqnum_reg;
        dest_address_not_found_next <= dest_address_not_found_reg;
        seqnum_f_next <= seqnum_f_reg;
        my_flag_next <= my_flag_reg;
        dest_port <= (others => '0');
        d_table_f_next <= '0';
        if header_f = '1' then
            d_table_f_next <= '1';
            if SYN = '1' then
                seqnum_f_next <= '0';
                if source_port(0) = '1' then
                    my_address_next(0) <= source_address;
                    my_seqnum_next(0) <= unsigned(seqnum_h);
                elsif source_port(1) = '1' then
                    my_address_next(1) <= source_address;
                    my_seqnum_next(1) <= unsigned(seqnum_h);
                elsif source_port(2) = '1' then
                    my_address_next(2) <= source_address;
                    my_seqnum_next(2) <= unsigned(seqnum_h);
                elsif source_port(3) = '1' then
                    my_address_next(3) <= source_address;
                    my_seqnum_next(3) <= unsigned(seqnum_h);
                elsif source_port(4) = '1' then
                    my_address_next(4) <= source_address;
                    my_seqnum_next(4) <= unsigned(seqnum_h);
                end if;
            else
                if CLO = '1' then
                    if my_address_reg(0) = source_address then
                        my_address_next(0) <= (others => '0');
                    elsif my_address_reg(1) = source_address then
                        my_address_next(1) <= (others => '0');
                    elsif my_address_reg(2) = source_address then
                        my_address_next(2) <= (others => '0');
                    elsif my_address_reg(3) = source_address then
                        my_address_next(3) <= (others => '0');
                    elsif my_address_reg(4) = source_address then
                        my_address_next(4) <= (others => '0');
                    end if;
                end if;
                if source_port = "00001" then
                    my_seqnum_next(0) <= unsigned(seqnum_h);
                    if (seqnum_h = std_logic_vector(my_seqnum_reg(0) + 1)) then
                        my_flag_next(0) <= '0';
                    else
                        my_flag_next(0) <= '1';
                    end if;
                elsif source_port = "00010" then
                    my_seqnum_next(1) <= unsigned(seqnum_h);
                    if (seqnum_h = std_logic_vector(my_seqnum_reg(1) + 1)) then
                        my_flag_next(1) <= '0';
                    else
                        my_flag_next(1) <= '1';
                    end if;
                elsif source_port = "00100" then
                    my_seqnum_next(2) <= unsigned(seqnum_h);
                    if (seqnum_h = std_logic_vector(my_seqnum_reg(2) + 1)) then
                        my_flag_next(2) <= '0';
                    else
                        my_flag_next(2) <= '1';
                    end if;
                elsif source_port = "01000" then
                    my_seqnum_next(3) <= unsigned(seqnum_h);
                    if (seqnum_h = std_logic_vector(my_seqnum_reg(3) + 1)) then
                        my_flag_next(3) <= '0';
                    else
                        my_flag_next(3) <= '1';
                    end if;
                elsif source_port = "10000" then
                    my_seqnum_next(4) <= unsigned(seqnum_h);
                    if (seqnum_h = std_logic_vector(my_seqnum_reg(4) + 1)) then
                        my_flag_next(4) <= '0';
                    else
                        my_flag_next(4) <= '1';
                    end if;
                end if;
            end if;
            if my_address_reg(0) = dest_address then
                dest_port(0) <= '1';
                dest_address_not_found_next <= '0';
            elsif my_address_reg(1) = dest_address then
                dest_port(1) <= '1';
                dest_address_not_found_next <= '0';
            elsif my_address_reg(2) = dest_address then
                dest_port(2) <= '1';
                dest_address_not_found_next <= '0';
            elsif my_address_reg(3) = dest_address then
                dest_port(3) <= '1';
                dest_address_not_found_next <= '0';
            elsif my_address_reg(4) = dest_address then
                dest_port(4) <= '1';
                dest_address_not_found_next <= '0';
            else
                dest_address_not_found_next <= '1';
            end if;
        end if;
    end process COMBINATIONAL;
    
    with source_port select
        seqnum_f <= my_flag_reg(0) when "00001",
                    my_flag_next(1) when "00010",
                    my_flag_next(2) when "00100",
                    my_flag_next(3) when "01000",
                    my_flag_next(4) when "10000",
                    '0' when others;
    with source_port select
        seqnum_calc_p <=    std_logic_vector(my_seqnum_reg(0) + 1) when "00001",
                            std_logic_vector(my_seqnum_reg(1) + 1) when "00010",
                            std_logic_vector(my_seqnum_reg(2) + 1) when "00100",
                            std_logic_vector(my_seqnum_reg(3) + 1) when "01000",
                            std_logic_vector(my_seqnum_reg(4) + 1) when "10000",
                            (others => '0') when others;

    port_0_out <= my_address_reg(0);
    port_1_out <= my_address_reg(1);
    port_2_out <= my_address_reg(2);
    port_3_out <= my_address_reg(3);
    port_4_out <= my_address_reg(4);
    dest_address_not_found <= dest_address_not_found_reg;
	d_table_f <= d_table_f_reg;	
    

end architecture d_table_rtl;