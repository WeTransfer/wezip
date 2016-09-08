defmodule WeZip.ZipWriter do
  use Bitwise

  @four_byte_max_uint 0xFFFFFFFF
  @two_byte_max_uint 0xFFFF

  @version_needed_to_extract 20
  @version_needed_to_extract_zip64 45

  @version_made_by 52
  @made_by_signature "4\x03" # OS type is UNIX
  @default_external_attributes 2175008768 # TODO: add comment here

  @zip_tricks_comment "Written using ZipTricks 0.0.1"


  def write_local_file_header(%{
    io: io, filename: filename, storage_mode: storage_mode, compressed_size: compressed_size,
    uncompressed_size: uncompressed_size, crc32: crc32, gp_flags: gp_flags, mtime: mtime
  }) when compressed_size > @two_byte_max_uint or uncompressed_size > @four_byte_max_uint do

    metadata = [
      io,
      pack_4b(0x04034b50),                                        # local file header signature 4 bytes  (0x04034b50)
      pack_2b(@version_needed_to_extract_zip64),                  # version needed to extract   2 bytes
      pack_2b(gp_flags),                                          # general purpose bit flag    2 bytes
      pack_2b(storage_mode),                                      # compression method          2 bytes
      pack_2b(to_binary_dos_time(mtime)),                # last mod file time          2 bytes
      pack_2b(to_binary_dos_date(mtime)),                # last mod file date          2 bytes
      pack_4b(crc32),                                             # crc-32                      4 bytes
      pack_4b(@four_byte_max_uint),                               # compressed size             4 bytes
      pack_4b(@four_byte_max_uint),                               # uncompressed size           4 bytes
      pack_2b(byte_size(filename)),                               # file name length            2 bytes
      pack_2b(%{io: "", compressed_size: 0, uncompressed_size: 0} # extra field length          2 bytes
      |> write_zip_64_extra_for_local_file_header |> byte_size),
      filename,                                                   # file name (variable size)
      write_zip_64_extra_for_local_file_header(%{
        io: io, compressed_size: compressed_size, uncompressed_size: uncompressed_size
      })
    ] |> Enum.join

    {:ok, pid} = StringIO.open(metadata)

    pid
  end

  def write_local_file_header(%{
    io: io, filename: filename, storage_mode: storage_mode, compressed_size: compressed_size,
    uncompressed_size: uncompressed_size, crc32: crc32, gp_flags: gp_flags, mtime: mtime
  }) do

    metadata = [
      io,
      pack_4b(0x04034b50),                         # local file header signature 4 bytes  (0x04034b50)
      pack_2b(@version_needed_to_extract),         # version needed to extract   2 bytes
      pack_2b(gp_flags),                           # general purpose bit flag    2 bytes
      pack_2b(storage_mode),                       # compression method          2 bytes
      pack_2b(to_binary_dos_time(mtime)), # last mod file time          2 bytes
      pack_2b(to_binary_dos_date(mtime)), # last mod file date          2 bytes
      pack_4b(crc32),                              # crc-32                      4 bytes
      pack_4b(compressed_size),                    # compressed size             4 bytes
      pack_4b(uncompressed_size),                  # uncompressed size           4 bytes
      pack_2b(byte_size(filename)),                # file name length            2 bytes
      pack_2b(0),                                  # extra field length          2 bytes
      filename                                     # file name (variable size)
    ] |> Enum.join

    {:ok, pid} = StringIO.open(metadata)

    pid
  end

  def write_data_descriptor(%{
    io: io, crc32: crc32, compressed_size: compressed_size, uncompressed_size: uncompressed_size
  }) when compressed_size > @four_byte_max_uint or uncompressed_size > @four_byte_max_uint do
    metadata = [
      io,
      pack_4b(0x08074b50),       # Although not originally assigned a signature, the value 0x08074b50 has commonly been adopted as a signature value
      pack_4b(crc32),            # crc-32                          4 bytes
      pack_8b(compressed_size),  # compressed size                 8 bytes for ZIP64
      pack_8b(uncompressed_size) # uncompressed size               8 bytes for ZIP64
    ] |> Enum.join

    {:ok, pid} = StringIO.open(metadata)

    pid
  end

  def write_data_descriptor(%{
    io: io, crc32: crc32, compressed_size: compressed_size, uncompressed_size: uncompressed_size
  }) do
    metadata = [
      io,
      pack_4b(0x08074b50),       # Although not originally assigned a signature, the value 0x08074b50 has commonly been adopted as a signature value
      pack_4b(crc32),            # crc-32                          4 bytes
      pack_4b(compressed_size),  # compressed size                 4 bytes
      pack_4b(uncompressed_size) # uncompressed size               4 bytes
    ] |> Enum.join

    {:ok, pid} = StringIO.open(metadata)

    pid
  end

  def write_central_directory_file_header(%{
    io: io, local_file_header_location: local_file_header_location, gp_flags: gp_flags,
    storage_mode: storage_mode, mtime: mtime, compressed_size: compressed_size, crc32: crc32,
    uncompressed_size: uncompressed_size, filename: filename
  }) when local_file_header_location > @four_byte_max_uint or compressed_size > @four_byte_max_uint or
  uncompressed_size > @four_byte_max_uint do
    metadata = [
      io,
      pack_4b(0x02014b50),
      @made_by_signature,
      pack_2b(@version_needed_to_extract_zip64),
      pack_2b(gp_flags),
      pack_2b(storage_mode),
      pack_2b(to_binary_dos_time(mtime)),
      pack_2b(to_binary_dos_date(mtime)),
      pack_4b(crc32),
      pack_4b(@four_byte_max_uint),
      pack_4b(@four_byte_max_uint),
      pack_2b(byte_size(filename)),
      pack_2b(%{io: "", compressed_size: 0, uncompressed_size: 0, local_file_header_location: 0}
      |> write_zip_64_extra_for_central_directory_file_header |> byte_size),
      pack_2b(0),
      pack_2b(@two_byte_max_uint),
      pack_2b(0),
      pack_4b(@default_external_attributes),
      pack_4b(@four_byte_max_uint),
      filename,
      write_zip_64_extra_for_central_directory_file_header(%{
        io: io, local_file_header_location: local_file_header_location,
        compressed_size: compressed_size, uncompressed_size: uncompressed_size
      })
    ] |> Enum.join

    {:ok, pid} = StringIO.open(metadata)

    pid
  end

  def write_central_directory_file_header(%{
    io: io, local_file_header_location: local_file_header_location, gp_flags: gp_flags,
    storage_mode: storage_mode, mtime: mtime, compressed_size: compressed_size, crc32: crc32,
    uncompressed_size: uncompressed_size, filename: filename
  }) do
    metadata = [
      io,
      pack_4b(0x02014b50),
      @made_by_signature,
      pack_2b(@version_needed_to_extract),
      pack_2b(gp_flags),
      pack_2b(storage_mode),
      pack_2b(to_binary_dos_time(mtime)),
      pack_2b(to_binary_dos_date(mtime)),
      pack_4b(crc32),
      pack_4b(compressed_size),
      pack_4b(uncompressed_size),
      pack_2b(byte_size(filename)),
      pack_2b(0),
      pack_2b(0),
      pack_2b(0),
      pack_2b(0),
      pack_4b(@default_external_attributes),
      pack_4b(local_file_header_location),
      filename
    ] |> Enum.join

    {:ok, pid} = StringIO.open(metadata)

    pid
  end

  # def write_end_of_central_directory(params) do
  #
  # end

  defp write_zip_64_extra_for_local_file_header(%{
    io: io, compressed_size: compressed_size, uncompressed_size: uncompressed_size
  }) do
    [
      pack_2b(0x0001),            # 2 bytes    Tag for this "extra" block type
      pack_2b(16),                # 2 bytes    Size of this "extra" block. For us it will always be 16 (2x8)
      pack_8b(uncompressed_size), # 8 bytes    Original uncompressed file size
      pack_8b(compressed_size)    # 8 bytes    Size of compressed data
    ] |> Enum.join
  end

  defp write_zip_64_extra_for_central_directory_file_header(%{
    io: io, compressed_size: compressed_size, uncompressed_size: uncompressed_size,
    local_file_header_location: local_file_header_location
  }) do
    [
      io,
      pack_2b(0x0001),
      pack_2b(28),
      pack_8b(uncompressed_size),
      pack_8b(compressed_size),
      pack_8b(local_file_header_location),
      pack_4b(0)
    ] |> Enum.join
  end

  defp pack_2b(x) do
    <<x::little-integer-size(16)>>
  end

  defp pack_4b(x) do
    <<x::little-integer-size(32)>>
  end

  def pack_8b(x) do
    <<x::little-integer-size(64)>>
  end

  defp to_binary_dos_time(time) do
    round((time.second / 2) + (time.minute <<< 5) + (time.hour <<< 11))
  end

  defp to_binary_dos_date(date) do
    round(date.day + (date.month <<< 5) + ((date.year - 1980) <<< 9))
  end
end
