
class RS232

  require 'ffi'
  
  attr_accessor :report, :delimiter
  attr_reader   :count, :error
  
  # serial port object constructor
  # also sets the parameters and timeout properties through an hash argument
  #   hash arguments options:
  #     :mode
  #     :file
  #     :attr
  #     :dcblength
  #     :baudrate
  #     :bytesize
  #     :stopbits
  #     :parity
  #     :delimiter
  #     :read_interval_timeout
  #     :read_total_timeout_multiplier
  #     :read_total_timeout_constant
  #     :write_total_timeout_multiplier
  #     :write_total_timeout_constant
  def initialize address, params = {} 
    mode = param[:mode] || Win32::GENERIC_READ | Win32::GENERIC_WRITE
    type = param[:file] || Win32::OPEN_EXISTING
    attr = param[:attr] || Win32::FILE_ATTRIBUTE_NORMAL
    @serial = Win32::CreateFileA( address, mode, 0, nil, type, attr, nil) 
    @error  = Win32.error_check
    puts "RS232 >> got file handle 0x%.8x for com port %s" % [@serial, address]   
    DCB.new.tap do |p|
      p[:dcblength] = DCB::Sizeof  
      Win32::GetCommState @serial, p
      p[:baudrate] = params[:baudrate] || 9600
      p[:bytesize] = params[:bytesize] || 8
      p[:stopbits] = params[:stopbits] || DCB::ONESTOPBIT
      p[:parity]   = params[:parity]   || DCB::NOPARITY
      Win32::SetCommState @serial, p
      @error = Win32.error_check
    end        
    CommTimeouts.new.tap do |timeouts|
      timeouts[:read_interval_timeout]          = params[:read_interval_timeout]          ||  50 
      timeouts[:read_total_timeout_multiplier]  = params[:read_total_timeout_multiplier]  ||  50
      timeouts[:read_total_timeout_constant]    = params[:read_total_timeout_constant]    ||  10
      timeouts[:write_total_timeout_multiplier] = params[:write_total_timeout_multiplier] ||  50
      timeouts[:write_total_timeout_constant]   = params[:write_total_timeout_constant]   ||  10     
      Win32::SetCommTimeouts @serial, timeouts
      @error = Win32.error_check
    end    
    grow_buffer 128
    @count = FFI::MemoryPointer.new :uint, 1
    @report = false
    @delimiter = params[:delimiter] || "\r\n"
  end
  
  # writes a string to the Serial port and happens the delimiter characters stores in @delimiters
  def write string
    command = "%s%s" % [string.chomp, @delimiter]
    grow_buffer command.length
    @buffer.write_string  command
    Win32::WriteFile @serial, @buffer, command.length, @count, nil
    @error = Win32.error_check
    puts "write count %i" % @count.read_uint32 if @report
  end
  
  # read a string from the Serial port
  def read
    Win32::ReadFile @serial, @buffer, @buflen, @count, nil
    @error = Win32.error_check
    puts "read count %i" % @count.read_uint32 if @report
    @buffer.read_string.chomp
  end
  
  # write and read helper method
  def query string
    write string
    read
  end
  
  # close the Com port
  def stop
    Win32::CloseHandle @serial
    @error = Win32.error_check
  end
  
  # increase the buffer size for reading and writing
  def grow_buffer size   
    @buffer = FFI::MemoryPointer.new :char, @buflen = size if @buffer.nil? || @buflen < size
  end
  
  # wraps the native Windows API functions for file IO and COMM port found in kernel32.dll
  module Win32
    extend FFI::Library
    ffi_lib 'kernel32.dll'
    [
      [ :GetLastError,    [],  :uint32],
      [ :CreateFileA,     [:pointer, :uint32, :uint32, :pointer, :uint32, :uint32, :pointer],  :pointer],
      # CreateFile first argument is a const char*
      # Windows can decide to read it as a C string (1 char = 1 byte) or a unicode string (1 char = 2 byte)
      # the real dll functions are actually CreateFileA for the C strings and CreateFileW for unicode
      # I strongly suggest to use CreateFileA since FFI will automatically write a C string from Ruby string
      [ :CloseHandle,     [:pointer],  :int],
      [ :ReadFile,        [:pointer, :pointer, :uint32, :pointer, :pointer],    :int32],
      [ :WriteFile,       [:pointer, :pointer, :uint32, :pointer, :pointer],    :int32],
      [ :GetCommState,    [:pointer, :pointer], :int32],
      [ :SetCommState,    [:pointer, :pointer], :int32],
      [ :GetCommTimeouts, [:pointer, :pointer], :int32],
      [ :SetCommTimeouts, [:pointer, :pointer], :int32],
    ].each{ |sig| attach_function *sig }    
    def self.error_code
      err = self::GetLastError()
      "error code: %i | 0x%.8x" % [err,err]
    end
    def self.error_check
      self::GetLastError().tap{ |err| puts "error: %i | 0x%.8x" % [err,err] if err != 0 }
    end    
    GENERIC_READ  = 0x80000000              # consts from Windows seven sdk:  
    GENERIC_WRITE = 0x40000000              # extract with 
    OPEN_EXISTING = 3                       #   grep -i "generic_read" *.h 
    FILE_ATTRIBUTE_NORMAL = 0x00000080      # from the /Include directory
  end
  
  # this struct is used by windows to configure the COMM port
  class DCB < FFI::Struct
    layout  :dcblength,   :uint32,
            :baudrate,    :uint32,
            :flags,       :uint32,              # the :flag uint32 is actually a bit fields compound with structure
            :wreserved,   :uint16,              #   uint32 fBinary :1;
            :xonlim,      :uint16,              #   uint32 fParity :1;
            :xofflim,     :uint16,              #   uint32 fParity :1;
            :bytesize,    :uint8,               #   uint32 fOutxCtsFlow :1;
            :parity,      :uint8,               #   uint32 fOutxDsrFlow :1;
            :stopbits,    :uint8,               #   uint32 fDtrControl :2;
            :xonchar,     :int8,                #   uint32 fDsrSensitivity :1;
            :xoffchar,    :int8,                #   uint32 fTXContinueOnXoff :1;
            :errorchar,   :int8,                #   uint32 fOutX :1;
            :eofchar,     :int8,                #   uint32 fInX :1;
            :evtchar,     :int8,                #   uint32 fErrorChar :1;
            :wreserved1,  :uint16               #   uint32 fNull :1;
                                                #   uint32 fRtsControl :2;
                                                #   uint32 fAbortOnError :1;
                                                #   uint32 fDummy2 :17;          
    Sizeof      = 28 # this is used to tell windows the size of its own struct, not sure why it is necessary (different Windows version)
    ONESTOPBIT  = 0
    NOPARITY    = 0
  end
  
  # this structure is used to set timeout properties of the opened COM ports
  class CommTimeouts < FFI::Struct
    layout  :read_interval_timeout,           :uint32, 
            :read_total_timeout_multiplier,   :uint32, 
            :read_total_timeout_constant,     :uint32, 
            :write_total_timeout_multiplier,  :uint32, 
            :write_total_timeout_constant,    :uint32
  end 
  
end
