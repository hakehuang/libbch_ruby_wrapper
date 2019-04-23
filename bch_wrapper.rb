require 'ffi'
require 'ffi/libc'


module Libbch
  extend FFI::Library
  ffi_lib './lib/libbch.so'

  class Gf_poly < FFI::Struct
    layout :deg, :uint
  # struct hack ignore it
  #         :c,   :uint
  end

  class Bch_control < FFI::Struct
      layout :m, :uint,
             :n, :uint,
             :t, :uint,
             :ecc_bits, :uint,
             :ecc_bytes, :uint,
             :a_pow_tab,  :pointer,
             :a_log_tab,  :pointer,
             :mod8_tab,   :pointer,
             :ecc_buf,    :pointer,
             :ecc_buf2,   :pointer,
             :xi_tab,     :pointer,
             :syn,        :pointer,
             :cache,      :pointer,
             :elp,        Gf_poly.ptr,
             :poly_2t,    [ Gf_poly.ptr, 4]
  end

  class Libbch < FFI::Struct
      layout :data_len,    :uint,
             :ecc_len,     :uint,
             :ecc_cap,     :uint,
             :error_count, :uint,
             :bch_ctrl,    Bch_control.ptr,
             :errloc,      :pointer
  end

  attach_function :libbch_free,  [:pointer], :void
  attach_function :libbch_init,  [:uint, :uint], :pointer
  attach_function :libbch_encode,  [:pointer, :pointer, :pointer], :void
  attach_function :libbch_decode,  [:pointer, :pointer, :pointer], :int
  attach_function :libbch_correct_all,  [:pointer, :pointer, :pointer], :void
  attach_function :libbch_dump,  [:pointer], :void
  attach_function :libbch_dump_errloc,  [:pointer], :void
end

def parse_bch_decode_err(err_code)
  if (err_code == -74)
    puts("libbch decode failed: ", err_code)
  elsif (err_code == -22)
    puts("bhclib decode invalid parameters: ", err_code)
  else
    puts("bhclib decode unknown error: ", err_code)
  end
end

def test_bch()

  libbch_obj = Libbch::libbch_init(512, 8)
  libbch = Libbch::Libbch.new(libbch_obj)
  
  Libbch::libbch_dump(libbch)
  
  data = FFI::LibC::malloc(libbch[:data_len]);
  FFI::LibC::memset(data, 0xFF, libbch[:data_len]);
  
  ecc = FFI::LibC::malloc(libbch[:ecc_len]);
  FFI::LibC::memset(ecc, 0x0, libbch[:ecc_len]);
  
  Libbch::libbch_encode(libbch, data, ecc);

  data.write_array_of_uint8([0xF0])
  
  ecc.write_array_of_uint8([ecc.read_array_of_int(1)[0] ^ 0xF0])
  
  errcnt = Libbch::libbch_decode(libbch, data, ecc)
  if (errcnt > 0)
    Libbch::libbch_dump_errloc(libbch)
  elsif (errcnt < 0)
    parse_bch_decode_err(errcnt)
    Libbch::libbch_free(libbch)
    return
  end

  Libbch::libbch_correct_all(libbch, data, ecc)

  errcnt = Libbch::libbch_decode(libbch, data, ecc)
  if (errcnt > 0)
    Libbch::libbch_dump_errloc(libbch)
  elsif (errcnt < 0)
    parse_bch_decode_err(errcnt)
    Libbch::libbch_free(libbch)
  end

end


