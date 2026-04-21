library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.mayo_pkg.all;

entity mayo_verify_accelerator is  
	generic (
        round               : positive := 2;
        w                   : positive := MAYO_W;
        nibble              : positive := MAYO_NIBBLE;
		C_S_AXI_DATA_WIDTH	: integer	:= 32;
		C_S_AXI_ADDR_WIDTH	: integer	:= 4
	);
	port (
		ACLK		    : in std_logic;
		ARESETN			: in std_logic;
		S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
		S_AXI_AWVALID	: in std_logic;
		S_AXI_AWREADY	: out std_logic;
		S_AXI_WDATA 	: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_WSTRB	    : in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		S_AXI_WVALID	: in std_logic;
		S_AXI_WREADY	: out std_logic;
		S_AXI_BRESP	    : out std_logic_vector(1 downto 0);
		S_AXI_BVALID	: out std_logic;
		S_AXI_BREADY	: in std_logic;
		S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
		S_AXI_ARVALID	: in std_logic;
		S_AXI_ARREADY	: out std_logic;
		S_AXI_RDATA	    : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_RRESP	    : out std_logic_vector(1 downto 0);
		S_AXI_RVALID	: out std_logic;
		S_AXI_RREADY	: in std_logic;

        -- ── AXI Stream slave (sig / sk in from DMA) ─────────────────────────
        S_AXIS_TDATA  : in  std_logic_vector(16*nibble-1 downto 0);
        S_AXIS_TVALID : in  std_logic;
        S_AXIS_TLAST  : in  std_logic;
        S_AXIS_TREADY : out std_logic;

        -- ── AXI Stream master (y out to DMA) ────────────────────────────────
        M_AXIS_TDATA  : out std_logic_vector(16*nibble-1 downto 0);
        M_AXIS_TVALID : out std_logic;
        M_AXIS_TLAST  : out std_logic;
        M_AXIS_TREADY : in  std_logic
    );
end entity mayo_verify_accelerator;

architecture behavioral of mayo_verify_accelerator is

    constant strobe_count : positive := C_S_AXI_DATA_WIDTH/8;

	signal axi_awaddr	: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_awready	: std_logic;
	signal axi_wready	: std_logic;
	signal axi_bresp	: std_logic_vector(1 downto 0);
	signal axi_bvalid	: std_logic;
	signal axi_araddr	: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_arready	: std_logic;
	signal axi_rdata	: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal axi_rresp	: std_logic_vector(1 downto 0);
	signal axi_rvalid	: std_logic;

    type regarray is array (0 to 2**(C_S_AXI_ADDR_WIDTH-2)-1) of std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

    constant ZEROES : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0):=(others => '0');
	
	signal reg : regarray;
	signal slv_reg_rden	: std_logic;
	signal slv_reg_wren	: std_logic;
	signal reg_data_out	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal aw_en	: std_logic;
    signal reset   : std_logic;
    signal calc      : std_logic;
    signal done      : std_logic;

begin

    reset <= not ARESETN;

	S_AXI_AWREADY	<= axi_awready;
	S_AXI_WREADY	<= axi_wready;
	S_AXI_BRESP	    <= axi_bresp;
	S_AXI_BVALID	<= axi_bvalid;
	S_AXI_ARREADY	<= axi_arready;
	S_AXI_RDATA	    <= axi_rdata;
	S_AXI_RRESP	    <= axi_rresp;
	S_AXI_RVALID	<= axi_rvalid;

    calc <= reg(0)(0);

	process (ACLK)
	begin
	  if rising_edge(ACLK) then 
	    if ARESETN = '0' then
	      axi_awready <= '0';
	      aw_en <= '1';
	    else
	      if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
	           axi_awready <= '1';
	           aw_en <= '0';
	        elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
	           aw_en <= '1';
	           axi_awready <= '0';
	      else
	        axi_awready <= '0';
	      end if;
	    end if;
	  end if;
	end process;

	process (ACLK)
	begin
	  if rising_edge(ACLK) then 
	    if ARESETN = '0' then
	      axi_awaddr <= (others => '0');
	    else
	      if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
	        axi_awaddr <= S_AXI_AWADDR;
	      end if;
	    end if;
	  end if;                   
	end process; 

	process (ACLK)
	begin
	  if rising_edge(ACLK) then 
	    if ARESETN = '0' then
	      axi_wready <= '0';
	    else
	      if (axi_wready = '0' and S_AXI_WVALID = '1' and S_AXI_AWVALID = '1' and aw_en = '1') then
	          axi_wready <= '1';
	      else
	        axi_wready <= '0';
	      end if;
	    end if;
	  end if;
	end process;

    -- ── mayo_verify core ─────────────────────────────────────────────────────
    core : entity work.mayo_verify
        generic map (
            round  => round,
            w      => w,
            nibble => nibble
        )
        port map (
            clk_i             => ACLK,
            reset_i           => reset,
            calc_i            => calc,
            tdata_i           => S_AXIS_TDATA,
            tvalid_i          => S_AXIS_TVALID,
            tlast_i           => S_AXIS_TLAST,
            tready_o          => S_AXIS_TREADY,
            done_o            => done,
            tdata_o           => M_AXIS_TDATA,
            tvalid_o          => M_AXIS_TVALID,
            tlast_o           => M_AXIS_TLAST,
            tready_i          => M_AXIS_TREADY
        );

	slv_reg_wren <= axi_wready and S_AXI_WVALID and axi_awready and S_AXI_AWVALID ;

    reg0_process: process(ACLK)
        variable reg_addr : integer;
    begin
        if rising_edge(ACLK) then
            if (ARESETN = '0') then
                for i in 0 to 2**(C_S_AXI_ADDR_WIDTH-2)-1 loop
                    reg(i) <= ZEROES;
                end loop;
            else
                if (slv_reg_wren = '1') then
                    reg_addr := to_integer(unsigned(axi_awaddr(C_S_AXI_ADDR_WIDTH-1 downto 2)));
                    case reg_addr is
                        when 0 =>
                            for i in 0 to strobe_count-1 loop
                                if S_AXI_WSTRB(i) = '1' then
                                    reg(0)((i*8)+7 downto i*8) <= S_AXI_WDATA((i*8)+7 downto i*8);
                                end if;
                            end loop;
                        when 1 =>
                            for i in 0 to strobe_count-1 loop
                                if S_AXI_WSTRB(i) = '1' then
                                    reg(1)((i*8)+7 downto i*8) <= S_AXI_WDATA((i*8)+7 downto i*8);
                                end if;
                            end loop;
                        when others =>
                            null;
                    end case;
                end if;
            end if;    
        end if;
    end process;

	process (ACLK)
	begin
	  if rising_edge(ACLK) then 
	    if ARESETN = '0' then
	      axi_bvalid  <= '0';
	      axi_bresp   <= "00"; 
	    else
	      if (axi_awready = '1' and S_AXI_AWVALID = '1' and axi_wready = '1' and S_AXI_WVALID = '1' and axi_bvalid = '0'  ) then
	        axi_bvalid <= '1';
	        axi_bresp  <= "00"; 
	      elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then  
	        axi_bvalid <= '0';                              
	      end if;
	    end if;
	  end if;                   
	end process; 

	process (ACLK)
	begin
	  if rising_edge(ACLK) then 
	    if ARESETN = '0' then
	      axi_arready <= '0';
	      axi_araddr  <= (others => '1');
	    else
	      if (axi_arready = '0' and S_AXI_ARVALID = '1') then
	        axi_arready <= '1';
	        axi_araddr  <= S_AXI_ARADDR;           
	      else
	        axi_arready <= '0';
	      end if;
	    end if;
	  end if;                   
	end process; 

	process (ACLK)
	begin
	  if rising_edge(ACLK) then
	    if ARESETN = '0' then
	      axi_rvalid <= '0';
	      axi_rresp  <= "00";
	    else
	      if (axi_arready = '1' and S_AXI_ARVALID = '1' and axi_rvalid = '0') then
	        axi_rvalid <= '1';
	        axi_rresp  <= "00"; 
	      elsif (axi_rvalid = '1' and S_AXI_RREADY = '1') then
	        axi_rvalid <= '0';
	      end if;            
	    end if;
	  end if;
	end process;

	slv_reg_rden <= axi_arready and S_AXI_ARVALID and (not axi_rvalid) ;

    process(axi_araddr, done)
        variable reg_addr : integer;
    begin
        reg_addr := to_integer(unsigned(axi_araddr(C_S_AXI_ADDR_WIDTH-1 downto 2)));
        case reg_addr is
            when 0 =>
                reg_data_out <= (31 downto 1 => '0') & done;
            when others =>
                reg_data_out <= (others => '0');
        end case;
    end process;
    
	process( ACLK ) is
	begin
	  if (rising_edge (ACLK)) then
	    if ( ARESETN = '0' ) then
	      axi_rdata  <= (others => '0');
	    else
	      if (slv_reg_rden = '1') then
	        axi_rdata <= reg_data_out;    
	      end if;   
	    end if;
	  end if;
	end process;


end behavioral;
